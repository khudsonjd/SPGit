# SPGit — Script-only usage (no AI required)

You don't need an AI assistant to use SPGit. The scripts work standalone in any PowerShell 5.1 session.

The `AGENT.md`, `SESSION.md`, and `memory/` files in each repo are optional — they're there if you want an AI to help, but they don't affect how the scripts run.

---

## Daily workflow (no AI)

### Check what's changed

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Status.ps1
. .\scripts\SPGit-Manifest.ps1

Get-SPGitStatus -ConfigPath "C:\SPGit\My-Repo\repo.config.json"
```

### Push your local changes up

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Push.ps1
. .\scripts\SPGit-Manifest.ps1

Push-SPGitRepo -ConfigPath "C:\SPGit\My-Repo\repo.config.json"
```

### Pull changes from SharePoint

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Pull.ps1
. .\scripts\SPGit-Manifest.ps1

Pull-SPGitRepo -ConfigPath "C:\SPGit\My-Repo\repo.config.json"
```

### Sync both directions at once

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Sync.ps1
. .\scripts\SPGit-Manifest.ps1

Sync-SPGitRepo -ConfigPath "C:\SPGit\My-Repo\repo.config.json"
```

---

## Ignoring files you don't want synced

Edit `.spgitignore` in the repo root. Add folder paths (ending with `/`) or file names:

```
metadata/locks/
metadata/sync-logs/
*.tmp
```

---

## Committing a snapshot

Think of this as a named save point:

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Commit.ps1

New-SPGitCommit `
  -ConfigPath "C:\SPGit\My-Repo\repo.config.json" `
  -Message "What changed and why"
```

---

## Restoring a previous version

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Restore.ps1

Restore-SPGitVersion -ConfigPath "C:\SPGit\My-Repo\repo.config.json" -CommitId "abc123"
```

---

## Tips

- Always use PowerShell 5.1, not PowerShell 7. Check: `$PSVersionTable.PSVersion`
- Dot-source only the scripts you need — no need to load the whole set.
- `Sync-SPGitRepo` stops at conflicts. Check the sync log in `metadata/sync-logs/` to see what was flagged.
- The `repo.config.json` file in each repo root holds the site URL and library name — edit it if you move the repo or change sites.
