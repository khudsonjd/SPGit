# SPGit Setup Guide

Complete step-by-step instructions for setting up SPGit on a new SharePoint site.

---

## Prerequisites

1. **Windows PowerShell 5.1** — built into Windows 10/11
2. **PnP.PowerShell 1.12.0** — install with:
   ```powershell
   Install-Module -Name PnP.PowerShell -RequiredVersion 1.12.0 -Scope CurrentUser
   ```
3. **SharePoint permissions** — Contributor or higher on the target site
4. **Clone this repo** to your local machine:
   ```
   C:\Users\you\Documents\SPGit-Scripts\   <-- recommended location
   ```

---

## Step 1 — Initialize the SPGit library (once per site)

Open PowerShell 5.1 (not PowerShell 7) and run:

```powershell
cd C:\Users\you\Documents\SPGit-Scripts
.\scripts\Invoke-SPGitInit.ps1 -SiteUrl "https://yourtenant.sharepoint.com/sites/yoursite"
```

A browser window will open for SharePoint authentication. Sign in with your work account.

This creates:
- A document library named `SPGit`
- 14 metadata columns (RepoName, ApprovalState, CommitDate, etc.)
- A default view called "SPGit Default"

The script is idempotent — safe to re-run. Anything that already exists is skipped.

---

## Step 2 — Create your first repo

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-NewRepo.ps1

$site = "https://yourtenant.sharepoint.com/sites/yoursite"
Connect-SPGitSite -SiteUrl $site
New-SPGitRepo -RepoName "My-Repo" -SiteUrl $site
```

This stamps the full folder skeleton (`main/`, `dev/`, `releases/`, `memory/`, `metadata/`) into `SPGit/My-Repo/` in SharePoint.

---

## Step 3 — Clone the repo locally

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Clone.ps1

Clone-SPGitRepo `
  -SiteUrl "https://yourtenant.sharepoint.com/sites/yoursite" `
  -RepoName "My-Repo" `
  -LocalRoot "C:\Users\you\Documents\SPGit"
```

This downloads all files to `C:\Users\you\Documents\SPGit\My-Repo\` and generates the initial manifest at `metadata/manifests/current-manifest.json`.

---

## Step 4 — Configure repo.config.json

Open `C:\Users\you\Documents\SPGit\My-Repo\repo.config.json` and verify:

```json
{
  "repoName": "My-Repo",
  "siteUrl": "https://yourtenant.sharepoint.com/sites/yoursite",
  "libraryName": "SPGit",
  "localRoot": "C:\\Users\\you\\Documents\\SPGit\\My-Repo"
}
```

`localRoot` is auto-populated by `Clone-SPGitRepo`. Review the rest and adjust if needed.

---

## Step 5 — Check status

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Status.ps1
. .\scripts\SPGit-Manifest.ps1

Get-SPGitStatus -ConfigPath "C:\Users\you\Documents\SPGit\My-Repo\repo.config.json"
```

Each file is classified as: `Synced` / `Modified` / `LocalOnly` / `RemoteOnly` / `Conflict`.

---

## Step 6 — Push local changes to SharePoint

After editing files locally:

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Push.ps1
. .\scripts\SPGit-Manifest.ps1

Push-SPGitRepo -ConfigPath "C:\Users\you\Documents\SPGit\My-Repo\repo.config.json"
```

Push will not overwrite files that are newer in SharePoint. Conflicts are surfaced, not silently resolved.

---

## Step 7 — Pull remote changes

When someone else (or you from another machine) has changed files in SharePoint:

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Pull.ps1
. .\scripts\SPGit-Manifest.ps1

Pull-SPGitRepo -ConfigPath "C:\Users\you\Documents\SPGit\My-Repo\repo.config.json"
```

---

## Step 8 — Sync (pull then push in one step)

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Sync.ps1
. .\scripts\SPGit-Manifest.ps1

Sync-SPGitRepo -ConfigPath "C:\Users\you\Documents\SPGit\My-Repo\repo.config.json"
```

Sync runs Pull first, then Push. Stops at conflicts without proceeding.

---

## Committing a snapshot

After significant work, record a commit:

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Commit.ps1

New-SPGitCommit `
  -ConfigPath "C:\Users\you\Documents\SPGit\My-Repo\repo.config.json" `
  -Message "Describe what changed"
```

Commit records are written to `metadata/commits/` and `CHANGELOG.md` is updated.

---

## Publishing a release

When a version is ready to share:

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Publish.ps1

Publish-SPGitRelease -ConfigPath "C:\Users\you\Documents\SPGit\My-Repo\repo.config.json"
```

This packages `main/` into `releases/vYYYY.MM.DD.N/` with a manifest and release notes.

---

## Ignoring files

Edit `.spgitignore` in your repo root. Default entries:

```
metadata/locks/
metadata/sync-logs/
```

Paths are relative to the repo root. Folder paths must end with `/`.

---

## Multiple repos

Repeat Steps 2–4 for each additional repo. Each lives in its own folder under `SPGit/` in SharePoint and its own folder under your `LocalRoot` directory.

---

## Troubleshooting

**`Import-Module` error on PnP.PowerShell:**
If you see a `TypeLoadException`, you likely have the legacy `SharePointPnPPowerShellOnline` module loaded. Start a fresh PowerShell 5.1 ISE or terminal session and try again.

**Auth prompt doesn't appear:**
Make sure you are running PowerShell 5.1, not PowerShell 7. Check with `$PSVersionTable.PSVersion`.

**Files not appearing after push:**
Run `Get-SPGitStatus` to confirm the manifest reflects the changes. If files show as `Synced` locally but are missing in SharePoint, check your `.spgitignore`.
