# SPGit

SharePoint as a lightweight version control system — for teams that store work in SharePoint but don't have GitHub commit access.

SPGit gives you clone, push, pull, sync, commit, and publish verbs against a SharePoint document library using PowerShell 5.1 and PnP.PowerShell. No Git, no Node.js, no admin rights beyond standard SharePoint contributor access.

---

## What it does

- **Clone** a SharePoint folder to your local machine
- **Push / Pull / Sync** changes between local and SharePoint
- **Commit** snapshots with messages and author metadata
- **Publish** versioned releases to a `releases/` folder
- **Track** file state via SHA-256 manifest — no silent overwrites
- **Lock** files to prevent concurrent edits

---

## Prerequisites

| Requirement | Version |
|---|---|
| Windows PowerShell | 5.1 |
| PnP.PowerShell | 1.12.0 |
| SharePoint permissions | Contributor or higher on target site |

Install PnP.PowerShell if needed:
```powershell
Install-Module -Name PnP.PowerShell -RequiredVersion 1.12.0 -Scope CurrentUser
```

---

## Quick start

**Step 1 — Initialize the SPGit library on your SharePoint site (once per site):**
```powershell
.\scripts\Invoke-SPGitInit.ps1 -SiteUrl "https://yourtenant.sharepoint.com/sites/yoursite"
```
This creates the `SPGit` document library with 14 metadata columns and a default view. Safe to re-run — skips anything that already exists.

**Step 2 — Create a repo:**
```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-NewRepo.ps1
Connect-SPGitSite -SiteUrl "https://yourtenant.sharepoint.com/sites/yoursite"
New-SPGitRepo -RepoName "My-Repo" -SiteUrl "https://yourtenant.sharepoint.com/sites/yoursite"
```

**Step 3 — Clone it locally:**
```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Clone.ps1
Clone-SPGitRepo -SiteUrl "https://yourtenant.sharepoint.com/sites/yoursite" -RepoName "My-Repo" -LocalRoot "C:\Users\you\Documents\SPGit"
```

**Step 4 — Make changes locally, then sync:**
```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Sync.ps1
. .\scripts\SPGit-Manifest.ps1
Sync-SPGitRepo -ConfigPath "C:\Users\you\Documents\SPGit\My-Repo\repo.config.json"
```

See [SETUP.md](SETUP.md) for the full walkthrough.

---

## Scripts

| Script | Function | Description |
|---|---|---|
| `Invoke-SPGitInit.ps1` | — | One-time library setup (run first) |
| `SPGit-Connect.ps1` | `Connect-SPGitSite` | Authenticate to SharePoint |
| `SPGit-InitLibrary.ps1` | `Initialize-SPGitLibrary` | Create library, columns, and view |
| `SPGit-NewRepo.ps1` | `New-SPGitRepo` | Stamp the folder skeleton for a new repo |
| `SPGit-Clone.ps1` | `Clone-SPGitRepo` | Download a repo from SharePoint to local |
| `SPGit-Status.ps1` | `Get-SPGitStatus` | Compare local vs remote; show Synced/Modified/Conflict |
| `SPGit-Pull.ps1` | `Pull-SPGitRepo` | Download changed remote files |
| `SPGit-Push.ps1` | `Push-SPGitRepo` | Upload changed local files |
| `SPGit-Sync.ps1` | `Sync-SPGitRepo` | Pull then push; stops at conflicts |
| `SPGit-Commit.ps1` | `New-SPGitCommit` | Record a commit snapshot with message and author |
| `SPGit-Publish.ps1` | `Publish-SPGitRelease` | Package main/ into a versioned release folder |
| `SPGit-History.ps1` | `Get-SPGitHistory` | Read commit records and SharePoint version history |
| `SPGit-Diff.ps1` | `Compare-SPGitFile` | Hash check + line diff for text files |
| `SPGit-Restore.ps1` | `Restore-SPGitVersion` | Restore from a manifest snapshot or release |
| `SPGit-Lock.ps1` | `Lock-SPGitFile`, `Unlock-SPGitFile` | Write/clear lock records to prevent concurrent edits |
| `SPGit-Manifest.ps1` | `Get-SPGitManifest`, `Update-SPGitManifest` | Maintain the SHA-256 file state manifest |

Scripts are standalone dot-sourceable `.ps1` files — no module installation required. Dot-source only what you need.

---

## Repo folder structure

Each repo gets this folder skeleton (created by `New-SPGitRepo`):

```
[RepoName]/
  AGENT.md            -- AI assistant behavior instructions (optional)
  SESSION.md          -- Active work and last decisions (optional)
  CONTEXT.md          -- Static background (optional)
  README.md
  CHANGELOG.md
  repo.config.json    -- Local config (site URL, library name, paths)
  .spgitignore        -- Files to exclude from sync
  main/
    src/
    docs/
    scripts/
    tests/
  dev/
  releases/
  memory/
    project_plan.md
    status.md
    decisions.md
    improvements.md
  metadata/
    commits/
    manifests/
    locks/
    sync-logs/
```

Templates for all these files are in the [`templates/`](templates/) folder.

---

## Design principles

1. **Never silently overwrite** — Push and Pull both refuse to stomp newer changes without explicit confirmation.
2. **Manifest is the source of truth** — SHA-256 hashes in `metadata/manifests/current-manifest.json` determine file state, not SharePoint timestamps.
3. **SharePoint is not Git** — SPGit wraps SharePoint's native versioning; it does not replicate Git's branching model.
4. **No module required** — Dot-source the scripts you need; nothing to install beyond PnP.PowerShell.

---

## AI assistant integration

SPGit repos include `AGENT.md`, `SESSION.md`, and `memory/` files so an AI assistant (Claude, etc.) can maintain context across sessions. See [docs/for-ai-users.md](docs/for-ai-users.md) for the full integration guide.

For script-only usage without AI, see [docs/for-everyone-else.md](docs/for-everyone-else.md).

---

## License

MIT
