# NMS UA Wiki mirror

[The Ukrainian No Man’s Sky wiki on Fandom](https://no-mans-sky.fandom.com/uk/wiki/) is the source of truth. This repository mirrors the current source of each publicly listed page in its MediaWiki namespaces, including redirects, templates, and file description pages.

`mirror/manifest.json` maps each page’s exact title, page ID, and Fandom revision ID to its source file. It also links to the saved revision and the page history for attribution. `mirror/pages/` contains the original source as UTF-8, using `.wiki` for wikitext and the appropriate extension for other content models. The manifest records the license advertised by the wiki. Check the linked page history and any source notices when reusing content.

`mirror/images/` contains the current uploaded images under the filenames returned by Fandom, including underscores, case, and extensions. The manifest links each image to its Fandom file description and records the download URL, the saved file’s SHA-256, and the upload’s reported SHA-1 and byte count. Fandom can process images even when asked to serve the original format. `matchesFandomUpload` records whether the downloaded bytes match the upload’s reported hash and size.

To refresh the mirror from the repository root, run this in PowerShell 7.2 or later:

```powershell
pwsh -NoProfile -File .\Sync-WikiMirror.ps1
```

The script reads Fandom’s public API and replaces the generated mirror after it has fetched all current page sources and images. It verifies and reuses unchanged local images. It requires a clean `mirror/` directory. Review the result with `git status --short` and `git diff -- mirror`, then commit the snapshot. Edit pages on Fandom and refresh here after publication.

Git records the snapshots you commit. Fandom retains the earlier page and upload history.
