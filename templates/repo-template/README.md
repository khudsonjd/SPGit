# [YOUR-REPO-NAME]

[One sentence describing what this repo contains.]

## Contents

[Brief description of what is in main/, dev/, releases/.]

## How to use

Clone this repo:
```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Clone.ps1
Clone-SPGitRepo -SiteUrl "https://yourtenant.sharepoint.com/sites/yoursite" -RepoName "YOUR-REPO-NAME" -LocalRoot "C:\Users\you\Documents\SPGit"
```

Sync changes:
```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Sync.ps1
. .\scripts\SPGit-Manifest.ps1
Sync-SPGitRepo -ConfigPath ".\repo.config.json"
```
