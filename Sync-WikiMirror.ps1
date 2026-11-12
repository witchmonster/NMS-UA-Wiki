#Requires -Version 7.2

$ErrorActionPreference = 'Stop'
$api = 'https://no-mans-sky.fandom.com/uk/api.php'
$userAgent = 'NMSUAWikiMirror/1.0 (https://no-mans-sky.fandom.com/uk/)'
$root = (Resolve-Path -LiteralPath $PSScriptRoot).ProviderPath
$mirror = Join-Path $root 'mirror'
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Get-WikiResponse([System.Collections.IDictionary] $parameters) {
    $query = ($parameters.GetEnumerator() | ForEach-Object {
        '{0}={1}' -f [uri]::EscapeDataString($_.Key), [uri]::EscapeDataString([string]$_.Value)
    }) -join '&'
    $response = Invoke-WebRequest -Uri "${api}?action=query&format=json&formatversion=2&$query" `
        -UserAgent $userAgent `
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

function Get-WikiBatches([hashtable] $parameters) {
    $continuation = @{}
    do {
        $response = Get-WikiResponse ($parameters + $continuation)
        $response
        $continuation = @{}
        if ($response.continue) {
            foreach ($key in $response.continue.Keys) { $continuation[$key] = $response.continue[$key] }
        }
        Start-Sleep -Milliseconds 100
    } while ($continuation.Count)
}

function Get-Sha256([byte[]] $bytes) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Save-WikiImages([string] $destination, [string] $existingMirror) {
    $priorImages = @{}
    $priorManifest = Join-Path $existingMirror 'manifest.json'
    if (Test-Path -LiteralPath $priorManifest) {
        $previous = Get-Content -LiteralPath $priorManifest -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
        foreach ($image in $previous.uploads) { $priorImages[$image.filename] = $image }
    }

    $seenNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $imageFolder = Join-Path $destination 'images'
    $parameters = @{ list = 'allimages'; ailimit = 'max'; aiprop = 'timestamp|url|size|sha1|mime' }
    foreach ($response in (Get-WikiBatches $parameters)) {
        foreach ($upload in $response.query.allimages) {
            if ($upload.mime -notlike 'image/*') { continue }
            $name = [string]$upload.name
            if (!$name -or $name.Length -gt 255 -or $name -match '[<>:"/\\|?*\x00-\x1F]|[. ]$' -or
                $name -match '^(CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³]) *(\.|$)' -or !$seenNames.Add($name)) {
                throw "Cannot store the Fandom filename verbatim: $name"
            }
            $uri = [uri]$upload.url
            if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'static.wikia.nocookie.net' -or
                !$uri.AbsolutePath.StartsWith('/no-mans-sky/images/') -or $upload.sha1 -notmatch '^[0-9a-f]{40}$' -or $upload.size -le 0) {
                throw "Fandom returned invalid image metadata for $name."
            }
            $original = [UriBuilder]::new($uri)
            $original.Query = if ($uri.Query) { $uri.Query.TrimStart('?') + '&format=original' } else { 'format=original' }

            $prior = $priorImages[$name]
            $existingFile = Join-Path $existingMirror 'images' $name
            $bytes = $null
            if ($prior.fandomSha1 -eq $upload.sha1 -and (Test-Path -LiteralPath $existingFile -PathType Leaf)) {
                $candidate = [IO.File]::ReadAllBytes($existingFile)
                if ((Get-Sha256 $candidate) -eq $prior.sha256) { $bytes = $candidate }
            }
            if ($null -eq $bytes) {
                $download = Invoke-WebRequest -Uri $original.Uri -UserAgent $userAgent -MaximumRedirection 0 `
                    -TimeoutSec 30 -MaximumRetryCount 2 -RetryIntervalSec 2
                $mime = ([string]($download.Headers['Content-Type'] | Select-Object -First 1)).Split(';')[0]
                if ($mime -ne $upload.mime -or $download.Content -isnot [byte[]] -or $download.Content.Length -eq 0) {
                    throw "Fandom did not serve $name in its uploaded format ($($upload.mime))."
                }
                $bytes = $download.Content
                Start-Sleep -Milliseconds 100
            }

            $servedSha1 = [Convert]::ToHexString([Security.Cryptography.SHA1]::HashData($bytes)).ToLowerInvariant()
            [void][IO.Directory]::CreateDirectory($imageFolder)
            [IO.File]::WriteAllBytes((Join-Path $imageFolder $name), $bytes)
            [ordered]@{
                filename = $name
                title = $upload.title
                file = "images/$name"
                descriptionUrl = $upload.descriptionurl
                downloadUrl = $original.Uri.AbsoluteUri
                uploadTimestamp = ([datetimeoffset]$upload.timestamp).UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
                mime = $upload.mime
                width = $upload.width
                height = $upload.height
                fandomSize = $upload.size
                fandomSha1 = $upload.sha1
                savedSize = $bytes.Length
                sha256 = Get-Sha256 $bytes
                matchesFandomUpload = $bytes.Length -eq $upload.size -and $servedSha1 -eq $upload.sha1
            }
        }
    }
    if ($seenNames.Count -eq 0) { throw 'Fandom returned no uploaded images.' }
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

function Get-MirrorFiles([string] $directory) {
    $files = [System.Collections.Generic.Dictionary[string, IO.FileInfo]]::new([StringComparer]::Ordinal)
    foreach ($file in (Get-ChildItem -LiteralPath $directory -Recurse -Force -File)) {
        $files.Add([IO.Path]::GetRelativePath($directory, $file.FullName), $file)
    }
    return $files
}

function Publish-WikiMirror([string] $incoming, [string] $current, [string] $rollback) {
    Assert-MirrorDirectory $incoming
    if (!(Test-Path -LiteralPath $current)) {
        [IO.Directory]::Move($incoming, $current)
        return
    }
    Assert-MirrorDirectory $current
    $existingFiles = Get-MirrorFiles $current
    $newFiles = Get-MirrorFiles $incoming
    $removed = @($existingFiles.Keys | Where-Object { !$newFiles.ContainsKey($_) })
    $changed = @(
        foreach ($relative in $newFiles.Keys) {
            $new = $newFiles[$relative]
            if (!$existingFiles.ContainsKey($relative) -or $existingFiles[$relative].Length -ne $new.Length -or
                (Get-FileHash -LiteralPath $existingFiles[$relative].FullName).Hash -ne (Get-FileHash -LiteralPath $new.FullName).Hash) {
                $relative
            }
        }
    )
    # Remove old names first for case-only renames on Windows. Publish the manifest last.
    $paths = @($removed) + @($changed | Where-Object { $_ -ne 'manifest.json' }) + @($changed | Where-Object { $_ -eq 'manifest.json' })
    foreach ($relative in $paths) {
        if ($existingFiles.ContainsKey($relative)) {
            $copy = Join-Path $rollback $relative
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($copy))
            [IO.File]::Copy($existingFiles[$relative].FullName, $copy)
        }
    }

    $applied = [System.Collections.Generic.List[string]]::new()
    try {
        foreach ($relative in $paths) {
            $target = Join-Path $current $relative
            if ($newFiles.ContainsKey($relative)) {
                [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
                [IO.File]::Move($newFiles[$relative].FullName, $target, $true)
            } else {
                [IO.File]::Delete($target)
            }
            $applied.Add($relative)
        }
    } catch {
        $publishError = $_
        try {
            $applied.Reverse()
            foreach ($relative in $applied) {
                $target = Join-Path $current $relative
                if ($existingFiles.ContainsKey($relative)) {
                    [IO.File]::Copy((Join-Path $rollback $relative), $target, $true)
                } else {
                    [IO.File]::Delete($target)
                }
            }
        } catch {
            throw "Could not restore the mirror. Recovery files are in $rollback. $($_.Exception.Message)"
        }
        if (Test-Path -LiteralPath $rollback) {
            Assert-MirrorDirectory $rollback
            Remove-Item -LiteralPath $rollback -Recurse -Force
        }
        throw $publishError
    }
    if (Test-Path -LiteralPath $rollback) {
        Assert-MirrorDirectory $rollback
        Remove-Item -LiteralPath $rollback -Recurse -Force
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
        foreach ($response in (Get-WikiBatches $parameters)) {
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
                        sha256 = Get-Sha256 ($utf8.GetBytes($slot.content))
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
        }
    }
    if (-not ($pages | Where-Object namespaceId -eq 0)) { throw 'Fandom returned no article pages.' }

    $uploads = @(Save-WikiImages $stage $mirror | Sort-Object { $_.filename })
    $manifest = [ordered]@{
        schemaVersion = 2
        api = $api
        language = $site.general.lang
        license = $site.rightsinfo
        pages = @($pages | Sort-Object { $_.namespaceId }, { $_.pageId })
        uploads = $uploads
    }
    $json = $manifest | ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText((Join-Path $stage 'manifest.json'), $json.Replace("`r`n", "`n") + "`n", $utf8)

    $status = git -C $root status --porcelain=v1 --untracked-files=all --ignored -- mirror
    if ($LASTEXITCODE -ne 0 -or $status) { throw 'The existing mirror changed during the import.' }
    Publish-WikiMirror $stage $mirror $backup
    Write-Output "Mirrored $($pages.Count) Fandom pages and $($uploads.Count) uploaded images."
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
