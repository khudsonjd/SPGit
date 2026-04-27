# AGENT.md

AI behavior instructions for this repo.

## What this repo is

[Describe the repo purpose in 1-2 sentences.]

## Key files

- `SESSION.md` — active work and last decisions; read on open, update on close
- `memory/status.md` — current priorities and active items
- `memory/project_plan.md` — stable goals and reference info
- `repo.config.json` — SharePoint site URL, library name, local paths

## Session open

Read `SESSION.md` and `memory/status.md`. Summarize last decisions and ask what to work on.

## Session close

1. Update `memory/status.md` with current priorities and in-progress items.
2. Update `SESSION.md` — replace last-session decisions with this session's key decisions. Update the date.
3. Run `Sync-SPGitRepo` to push changes to SharePoint.

## Scripts

All scripts are in `../../scripts/` (relative to this repo root). Dot-source only what you need:

```powershell
. .\scripts\SPGit-Connect.ps1
. .\scripts\SPGit-Sync.ps1
. .\scripts\SPGit-Manifest.ps1
Sync-SPGitRepo -ConfigPath ".\repo.config.json"
```

## Constraints

- PowerShell 5.1 only. Never generate PS7 syntax.
- ASCII strings only — no em dashes, curly quotes, or Unicode characters in scripts.
- Bump the version comment on every script edit.
