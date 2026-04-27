# ============================================================
# SPGit-Commit.ps1
# Version:     1.0.0
# Date:        2026-04-26
# Description: Records a commit snapshot of local changes, updates CHANGELOG.md, and pushes to SharePoint.
# ============================================================

#region Functions *#
function New-SPGitCommit {
    <#
    .SYNOPSIS
        Captures changed local files into a commit record, appends to CHANGELOG.md, and pushes everything to SharePoint.
    #>
    param(
        [string][Parameter(Mandatory = $true)] $LocalRoot,
        [string][Parameter(Mandatory = $true)] $Message,
        [string]$Author = $env:USERNAME
    )

    #region Initialization *#
    . "$PSScriptRoot\SPGit-Connect.ps1"
    . "$PSScriptRoot\SPGit-Manifest.ps1"
    . "$PSScriptRoot\SPGit-Push.ps1"

    $configPath = Join-Path $LocalRoot "repo.config.json"
    if (-not (Test-Path $configPath)) {
        Write-Host "ERROR: repo.config.json not found at '$LocalRoot'" -ForegroundColor Red
        throw "Missing repo.config.json"
    }

    try {
        $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Write-Host "ERROR: Failed to parse repo.config.json -- $_" -ForegroundColor Red
        throw
    }

    Connect-SPGitSite -SiteUrl $config.siteUrl
    #endregion Initialization *#

    #region Main Logic *#
    $datePart   = Get-Date -Format "yyyyMMdd-HHmmss"
    $randPart   = [System.Guid]::NewGuid().ToString("N").Substring(0, 6)
    $commitId   = "$datePart-$randPart"
    $createdUtc = (Get-Date).ToUniversalTime().ToString("o")

    Write-Host "Creating commit '$commitId'..." -ForegroundColor Cyan

    $manifest     = Get-SPGitManifest -LocalRoot $LocalRoot
    $manifestLookup = @{}
    if ($null -ne $manifest) {
        foreach ($entry in $manifest) {
            $manifestLookup[$entry.relativePath] = $entry
        }
    }

    $allLocal = Get-ChildItem -Path $LocalRoot -Recurse -File
    $commitFiles = @()

    foreach ($file in $allLocal) {
        $relPath = $file.FullName.Substring($LocalRoot.Length).TrimStart('\').Replace('\','/')

        $currentHash = ""
        try { $currentHash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash } catch {}

        if ($manifestLookup.ContainsKey($relPath)) {
            if ($currentHash -ne $manifestLookup[$relPath].localHash) {
                $commitFiles += $relPath
            }
        }
        else {
            $commitFiles += $relPath
        }
    }

    Write-Host "Files in this commit: $($commitFiles.Count)" -ForegroundColor Cyan

    $commitRecord = [PSCustomObject]@{
        commitId   = $commitId
        message    = $Message
        author     = $Author
        createdUtc = $createdUtc
        files      = $commitFiles
    }

    $commitDir = Join-Path $LocalRoot "metadata\commits"
    if (-not (Test-Path $commitDir)) {
        New-Item -ItemType Directory -Path $commitDir -Force | Out-Null
    }

    $commitPath = Join-Path $commitDir "commit-$commitId.json"
    try {
        $commitRecord | ConvertTo-Json -Depth 5 | Set-Content -Path $commitPath -Encoding UTF8
        Write-Host "Commit record written to '$commitPath'." -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to write commit record -- $_" -ForegroundColor Red
        throw
    }
    #endregion Main Logic *#

    #region Changelog *#
    $changelogPath = Join-Path $LocalRoot "CHANGELOG.md"
    $changelogEntry = "`n## $commitId -- $(Get-Date -Format 'yyyy-MM-dd HH:mm') -- $Author`n$Message`n"

    try {
        if (Test-Path $changelogPath) {
            Add-Content -Path $changelogPath -Value $changelogEntry -Encoding UTF8
        }
        else {
            Set-Content -Path $changelogPath -Value "# CHANGELOG$changelogEntry" -Encoding UTF8
        }
        Write-Host "CHANGELOG.md updated." -ForegroundColor Green
    }
    catch {
        Write-Host "WARN: Could not update CHANGELOG.md -- $_" -ForegroundColor Yellow
    }
    #endregion Changelog *#

    #region Push *#
    Write-Host "Pushing changes to SharePoint..." -ForegroundColor Cyan
    Push-SPGitRepo -LocalRoot $LocalRoot

    Write-Host "Commit '$commitId' complete." -ForegroundColor Green
    return $commitId
    #endregion Push *#
}
#endregion Functions *#
