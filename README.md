# NMS UA Wiki mirror

[The Ukrainian No Man’s Sky wiki on Fandom](https://no-mans-sky.fandom.com/uk/wiki/) is the source of truth. This repository mirrors the current source of each publicly listed page in its MediaWiki namespaces, including redirects, templates, and file description pages.

`mirror/manifest.json` maps each page’s exact title, page ID, and Fandom revision ID to its source file. It also links to the saved revision and the page history for attribution. `mirror/pages/` contains the original source as UTF-8, using `.wiki` for wikitext and the appropriate extension for other content models. The manifest records the license advertised by the wiki. Check the linked page history and any source notices when reusing content.

To refresh the mirror from the repository root, run this in PowerShell 7.2 or later:

```powershell
pwsh -NoProfile -File .\Sync-WikiMirror.ps1
```

The script reads Fandom’s public API and replaces the generated mirror only after it has fetched the complete page list and all current sources. It requires a clean `mirror/` directory. Review the result with `git status --short` and `git diff -- mirror`, then commit the snapshot. Edit pages on Fandom and refresh here after publication.

Git records the snapshots you commit. Fandom retains the earlier edit history and uploaded media binaries.
