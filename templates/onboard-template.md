# SPGit Personal Workspace — Setup for {{UserFolderName}}

(If you are a SharePoint expert, you may take the following step yourself instead of waiting for an administrator to do it for you.)

Your SharePoint workspace has been created for you at:
**{{SharePointSiteUrl}}/SPGit/{{UserFolderName}}**

This file has two parts:
- **Part 1** — four quick steps you do yourself
- **Part 2** — a prompt you paste into GitHub Copilot to automate the rest

---

## Part 1 — Before You Start

**1. Confirm you have the following:**
- [ ] VS Code installed on this machine
- [ ] GitHub Copilot extension installed in VS Code and you are signed in
- [ ] You can open **{{SharePointSiteUrl}}** in your browser and log in successfully

If any of the above are missing, stop here and contact your administrator before continuing.

**2. Open VS Code**

**3. Open GitHub Copilot Chat**
Press **Ctrl + Shift + I**, or click the Copilot icon in the VS Code left sidebar.

**4. Switch to Agent mode**
At the top of the Copilot chat panel, click the mode selector and choose **Agent**.
If you only see Ask and Edit, update your GitHub Copilot extension and try again.

You are now ready for Part 2.

---

## Part 2 — GitHub Copilot Bootstrap Prompt

Copy everything between the two marker lines below — from `=== BEGIN PROMPT ===`
through `=== END PROMPT ===` — and paste it into the GitHub Copilot Agent chat.
Press Enter and follow Copilot's instructions.

**Important:** During Step 4, a browser window will open asking you to sign in to
SharePoint. Complete the sign-in, return to VS Code, and type **"login complete"**
so Copilot knows it can continue.

---

=== BEGIN PROMPT ===

You are helping me set up my SPGit personal workspace. SPGit is a SharePoint-based
version control and AI assistant memory system. My workspace folder has already been
created in SharePoint. Walk me through the local setup below, one step at a time.
Run each command in the VS Code terminal, confirm it succeeded, and tell me before
moving to the next step. If any step fails, stop and explain the error — do not skip ahead.

My workspace details:
- Workspace name: {{UserFolderName}}
- SharePoint site URL: {{SharePointSiteUrl}}
- SPGit library name: SPGit

---

Step 1 — Confirm PowerShell 5.1

Open a new terminal in VS Code (Terminal > New Terminal). Run:

$PSVersionTable.PSVersion

The Major version must be 5. If it shows 6 or 7, stop — tell me we are in the wrong
shell and instruct me to open a Windows PowerShell 5.1 terminal before we continue.
(In VS Code: click the dropdown arrow next to the + in the terminal panel and choose
"Windows PowerShell".)

---

Step 2 — Check for PnP.PowerShell 1.12.0

Run:

Get-Module -ListAvailable -Name PnP.PowerShell | Select-Object Name, Version

If version 1.12.0 appears, tell me and move to Step 3.

If it does not appear, run:

Install-Module -Name PnP.PowerShell -RequiredVersion 1.12.0 -Scope CurrentUser -Force

Wait for it to complete. Confirm no errors appeared, then move to Step 3.

---

Step 3 — Download the SPGit scripts

Run this block exactly as written. It downloads the SPGit scripts from GitHub without
requiring git to be installed:

$dest = "$env:USERPROFILE\Documents\SPGit-Scripts"
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
Invoke-WebRequest -Uri "https://github.com/khudsonjd/SPGit/archive/refs/heads/main.zip" -OutFile "$dest\spgit.zip" -UseBasicParsing
Expand-Archive -Path "$dest\spgit.zip" -DestinationPath $dest -Force
Write-Host "Scripts ready." -ForegroundColor Green

Confirm the green "Scripts ready." message appears, then move to Step 4.

---

Step 4 — Clone my workspace from SharePoint

Run:

. "$env:USERPROFILE\Documents\SPGit-Scripts\SPGit-main\scripts\SPGit-Clone.ps1"
Clone-SPGitRepo -SiteUrl "{{SharePointSiteUrl}}" -RepoName "{{UserFolderName}}" -LocalRoot "$env:USERPROFILE\Documents\SPGit"

A browser window will open. I need to sign in to SharePoint with my work account.
Tell me: "Sign in to SharePoint in the browser window that just opened, then return
here and type 'login complete'."

Wait for me to say "login complete", then confirm whether the clone completed
successfully.

---

Step 5 — Confirm setup

Run:

Get-ChildItem "$env:USERPROFILE\Documents\SPGit\{{UserFolderName}}"

If you see folders named main, memory, dev, releases, and metadata, tell me:

"Setup is complete. Your SPGit workspace is at:
C:\Users\[your Windows username]\Documents\SPGit\{{UserFolderName}}

Open SESSION.md in that folder to begin working with your AI assistant."

If any expected folders are missing, list them and wait for my instructions.

=== END PROMPT ===

---

If Copilot runs into an error not covered above, note the error message and contact
your administrator for help.
