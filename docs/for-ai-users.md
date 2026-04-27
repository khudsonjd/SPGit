# SPGit with an AI Assistant (Claude / koi)

This guide is for users who run an AI assistant (Claude Code, a koi-style session system, etc.) and want the assistant to maintain context across SPGit sessions.

SPGit repos are pre-wired for this: every repo includes `AGENT.md`, `SESSION.md`, and a `memory/` folder. The AI reads these on session open and writes to them on session close — mirroring the pattern used in the koi workspace orchestrator.

---

## How it works

| File | Purpose |
|---|---|
| `AGENT.md` | Tells the AI how to behave in this repo — what it is, how scripts are used, what to watch for |
| `SESSION.md` | Active work, last session decisions, immediate focus — updated every close |
| `CONTEXT.md` | Static background that rarely changes — author, site URL, team context |
| `memory/project_plan.md` | Stable goals and reference info |
| `memory/status.md` | Current state — active items, priorities, open questions |
| `memory/decisions.md` | Design decisions with rationale |
| `memory/improvements.md` | Lessons learned |

---

## Session open convention

At the start of each session, have your AI assistant run:

```
Read AGENT.md, SESSION.md, and memory/status.md.
Summarize the last session decisions and ask what to work on.
```

Or add a `/open` command to your Claude Code setup that automates this for the repo.

---

## Session close convention

At the end of each session:

1. Update `memory/status.md` — current priorities, active items
2. Update `SESSION.md` — replace last-session decisions with this session's key decisions, update date
3. Push to SharePoint: `Sync-SPGitRepo`
4. Optionally push to GitHub if you have write access

---

## Setting up the dual-target commit model

If you want changes committed to both GitHub and SharePoint:

In `repo.config.json`, add:
```json
{
  "githubRemote": "https://github.com/you/your-repo",
  "githubWriteEnabled": true,
  "spgitPrimary": true
}
```

At session close the AI can then:
1. `git commit && git push` to GitHub
2. `Sync-SPGitRepo` to SharePoint

If you don't have GitHub write access, leave `githubRemote` empty — SharePoint is the sole persistence layer.

---

## Bootstrapping a new SPGit workstream

To add SPGit to an existing koi-style workspace:

1. Clone this GitHub repo locally:
   ```
   git clone https://github.com/khudsonjd/SPGit C:\Users\you\Documents\SPGit-Scripts
   ```

2. Copy `templates/repo-template/` to your koi workspace under a new workstream folder (e.g., `sharepoint-as-github/`).

3. Fill in `AGENT.md`, `SESSION.md`, and `memory/project_plan.md` with your specifics.

4. Run `Invoke-SPGitInit.ps1` against your SharePoint site.

5. Run `New-SPGitRepo` and `Clone-SPGitRepo` to set up your first repo.

6. Add an `/openSPGit` command to your Claude Code setup that reads `status.md` and `project_plan.md`.

---

## Template files

Pre-filled templates are in [`../templates/repo-template/`](../templates/repo-template/). Copy the whole folder as your starting point for any new repo.
