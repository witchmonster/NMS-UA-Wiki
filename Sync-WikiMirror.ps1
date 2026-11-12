#Requires -Version 7.2

$ErrorActionPreference = 'Stop'
$api = 'https://no-mans-sky.fandom.com/uk/api.php'
$root = (Resolve-Path -LiteralPath $PSScriptRoot).ProviderPath
$mirror = Join-Path $root 'mirror'
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Get-WikiResponse([System.Collections.IDictionary] $parameters) {
    $query = ($parameters.GetEnumerator() | ForEach-Object {
        '{0}={1}' -f [uri]::EscapeDataString($_.Key), [uri]::EscapeDataString([string]$_.Value)
    }) -join '&'
    $response = Invoke-WebRequest -Uri "${api}?action=query&format=json&formatversion=2&$query" `
        -UserAgent 'NMSUAWikiMirror/1.0 (https://no-mans-sky.fandom.com/uk/)' `
        -TimeoutSec 30 -MaximumRetryCount 2 -RetryIntervalSec 2
    $data = $response.Content | ConvertFrom-Json -AsHashtable
    if ($data.error -or $data.warnings) {
        $problem = @{ error = $data.error; warnings = $data.warnings } | ConvertTo-Json -Depth 6 -Compress
        throw "Fandom API reported a problem: $problem"
    }
    if (-not $data.Contains('query') -and -not $data.batchcomplete) {
        throw 'Fandom API returned no query result.'
    }
    return $data
}

function Get-FileLabel([string] $value) {
    $label = ($value -replace '[^\p{L}\p{M}\p{N}_.()-]+', '_').Trim([char[]]'._')
    return $label.Substring(0, [Math]::Min(72, $label.Length))
}

function Get-SourceExtension($slot) {
    if ($slot.contentmodel -eq 'Scribunto') { return '.lua' }
    switch ($slot.contentformat) {
        'text/x-wiki' { '.wiki' }
        'text/css' { '.css' }
        'text/javascript' { '.js' }
        'application/json' { '.json' }
        default { '.txt' }
    }
}

function Assert-MirrorDirectory([string] $path) {
    $item = Get-Item -LiteralPath $path -Force
    if (-not $item.PSIsContainer -or $item.Parent.FullName -ne $root -or
        ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Expected a regular directory directly inside $root`: $path"
    }
    if (Get-ChildItem -LiteralPath $path -Recurse -Force -Attributes ReparsePoint | Select-Object -First 1) {
        throw "Refusing to move or remove a directory containing a link: $path"
    }
}

$gitRoot = git -C $root rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($gitRoot) -ne $root) {
    throw 'Initialize Git in this project folder before running the mirror import.'
}
$gitDir = git -C $root rev-parse --absolute-git-dir
if ($LASTEXITCODE -ne 0) { throw 'Could not locate the Git directory.' }
$lock = [IO.File]::Open((Join-Path $gitDir 'wiki-mirror.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
$runId = [guid]::NewGuid().ToString('N')
$stage = Join-Path $root ".wiki-mirror-stage-$runId"
$backup = Join-Path $root ".wiki-mirror-backup-$runId"

try {
    $status = git -C $root status --porcelain=v1 --untracked-files=all --ignored -- mirror
    if ($LASTEXITCODE -ne 0 -or $status) { throw 'Review and commit the existing mirror changes first.' }
    if (Test-Path -LiteralPath $mirror) { Assert-MirrorDirectory $mirror }

    $site = (Get-WikiResponse @{ meta = 'siteinfo'; siprop = 'general|namespaces|rightsinfo' }).query
    if ($site.general.lang -ne 'uk' -or $site.general.server -ne 'https://no-mans-sky.fandom.com' -or
        $site.general.articlepath -ne '/uk/wiki/$1') {
        throw 'Fandom returned site information for a different wiki.'
    }
    $pages = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[long]]::new()
    foreach ($namespace in ($site.namespaces.Values | Where-Object { $_.id -ge 0 } | Sort-Object id)) {
        $name = if ($namespace.id -eq 0) { 'main' } else { Get-FileLabel $namespace.canonical }
        $folder = "pages/$($namespace.id)-$($name.ToLowerInvariant())"
        $parameters = @{
            generator = 'allpages'; gapnamespace = $namespace.id; gaplimit = 25
            prop = 'info|revisions'; inprop = 'url'; rvslots = '*'
            rvprop = 'ids|timestamp|contentmodel|content'
        }
        $continuation = @{}
        do {
            $response = Get-WikiResponse ($parameters + $continuation)
            foreach ($page in $response.query.pages) {
                $revision = $page.revisions | Select-Object -First 1
                if ($page.ns -ne $namespace.id -or $page.pageid -le 0 -or
                    -not $seen.Add($page.pageid) -or -not $revision.revid -or
                    $page.lastrevid -ne $revision.revid -or -not $revision.slots.main) {
                    throw "Fandom returned inconsistent revision data for $($page.title)."
                }
                $title = if ($namespace.id -eq 0) { $page.title } else { ($page.title -split ':', 2)[-1] }
                $fileStem = "$($page.pageid)-$(Get-FileLabel $title)"
                $slots = [ordered]@{}
                foreach ($role in ($revision.slots.Keys | Sort-Object)) {
                    $slot = $revision.slots[$role]
                    if ($slot.content -isnot [string] -or $role -notmatch '^[a-z0-9_-]+$') {
                        throw "Fandom did not provide usable $role source for $($page.title)."
                    }
                    $suffix = if ($role -eq 'main') { '' } else { ".$role" }
                    $file = "$folder/$fileStem$suffix$(Get-SourceExtension $slot)"
                    $destination = Join-Path $stage $file
                    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
                    [IO.File]::WriteAllText($destination, $slot.content, $utf8)
                    $slots[$role] = [ordered]@{
                        file = $file
                        contentModel = $slot.contentmodel
                        contentFormat = $slot.contentformat
                        sha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes($slot.content))).ToLowerInvariant()
                    }
                }
                $pages.Add([ordered]@{
                    pageId = $page.pageid
                    namespaceId = $page.ns
                    title = $page.title
                    revisionId = $revision.revid
                    revisionTimestamp = ([datetimeoffset]$revision.timestamp).UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    redirect = [bool]$page.redirect
                    revisionUrl = "$($page.canonicalurl)?oldid=$($revision.revid)"
                    historyUrl = "$($page.canonicalurl)?action=history"
                    slots = $slots
                })
            }
            $continuation = @{}
            if ($response.continue) {
                foreach ($key in $response.continue.Keys) { $continuation[$key] = $response.continue[$key] }
            }
            Start-Sleep -Milliseconds 100
        } while ($continuation.Count)
    }
    if (-not ($pages | Where-Object namespaceId -eq 0)) { throw 'Fandom returned no article pages.' }

    $manifest = [ordered]@{
        schemaVersion = 1
        api = $api
        language = $site.general.lang
        license = $site.rightsinfo
        pages = @($pages | Sort-Object { $_.namespaceId }, { $_.pageId })
    }
    $json = $manifest | ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText((Join-Path $stage 'manifest.json'), $json.Replace("`r`n", "`n") + "`n", $utf8)

    $status = git -C $root status --porcelain=v1 --untracked-files=all --ignored -- mirror
    if ($LASTEXITCODE -ne 0 -or $status) { throw 'The existing mirror changed during the import.' }
    Assert-MirrorDirectory $stage
    if (Test-Path -LiteralPath $mirror) {
        Assert-MirrorDirectory $mirror
        [IO.Directory]::Move($mirror, $backup)
    }
    try {
        [IO.Directory]::Move($stage, $mirror)
    } catch {
        if (Test-Path -LiteralPath $backup) {
            Assert-MirrorDirectory $backup
            [IO.Directory]::Move($backup, $mirror)
        }
        throw
    }
    if (Test-Path -LiteralPath $backup) {
        Assert-MirrorDirectory $backup
        Remove-Item -LiteralPath $backup -Recurse -Force
    }
    Write-Output "Mirrored $($pages.Count) Fandom pages with their revision IDs."
} finally {
    try {
        if (Test-Path -LiteralPath $stage) {
            Assert-MirrorDirectory $stage
            Remove-Item -LiteralPath $stage -Recurse -Force
        }
    } finally {
        $lock.Dispose()
    }
}
