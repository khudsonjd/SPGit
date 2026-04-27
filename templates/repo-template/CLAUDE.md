# CLAUDE.md

This is an SPGit-managed repository. Read this file first, then follow the instructions below.

## Session open

Read these files in order:
1. `AGENT.md` — repo-specific behavior instructions
2. `SESSION.md` — active work and last session decisions
3. `memory/status.md` — current priorities

Then respond with:
"**[RepoName] loaded.** Here's where we stand:
[2-3 sentence summary of current priorities and active work]
What would you like to work on?"

## Session close

Execute in order:
1. Update `memory/status.md` — capture current priorities and any in-progress items
2. Update `SESSION.md` — replace last-session decisions with this session's key decisions; update the date and `last_updated` frontmatter
3. Remind the user to sync: `Sync-SPGitRepo -ConfigPath ".\repo.config.json"`
4. If `repo.config.json` has a non-empty `githubRemote` and `githubWriteEnabled` is true, remind the user to also run `git commit && git push`
5. Confirm: "Session closed for [RepoName]."

## Scripts

Scripts live in the SPGit toolkit clone (separate from this repo). Dot-source before using:
```powershell
. [path-to-toolkit]\scripts\SPGit-Connect.ps1
. [path-to-toolkit]\scripts\SPGit-Sync.ps1
. [path-to-toolkit]\scripts\SPGit-Manifest.ps1
```

The scripts path is stored in `repo.config.json` under `spgitScriptsRoot` (add this field if missing).

## Key rules

- PowerShell 5.1 only — never generate PS7 syntax
- ASCII strings only in scripts — no em dashes, curly quotes, or Unicode
- Bump the version comment on every script edit
- Never silently overwrite files — SPGit stops at conflicts
