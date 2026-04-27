# AGENT.md

Repo-specific AI behavior instructions. Supplements `CLAUDE.md`.

## What this repo is

[Describe the repo purpose in 1-2 sentences. What does it store? Who uses it?]

## Key files

| File | Purpose |
|---|---|
| `CLAUDE.md` | Claude Code entrypoint — session open/close conventions |
| `SESSION.md` | Active work, last decisions, immediate focus |
| `memory/status.md` | Current priorities and in-progress items |
| `memory/project_plan.md` | Stable goals and reference info |
| `repo.config.json` | SharePoint site URL, library name, local paths, scripts path |
| `.spgitignore` | Files excluded from sync |

## Behavioral rules

- **State intent before acting** — for any file-level change, say what you are about to do first
- **Update `memory/status.md`** whenever priorities or active items change — do not wait until session close
- **Flag conflicts** — if Sync-SPGitRepo surfaces a conflict, surface it to the user before proceeding
- **Concise responses** — this is a working session, not a briefing

## What the AI should NOT do

- Generate PowerShell 7 syntax (PS5.1 only)
- Use em dashes, curly quotes, or non-ASCII characters in script files
- Silently resolve sync conflicts
- Edit `metadata/` files directly — these are managed by SPGit scripts

## Repo-specific notes

[Add any conventions, constraints, or context specific to this repo here.]
