# ============================================================
# SPGit-History.ps1
# Version:     1.0.0
# Date:        2026-04-26
# Description: Retrieves and displays the commit history for the local SPGit repository.
# ============================================================

#region Functions *#
function Get-SPGitHistory {
    <#
    .SYNOPSIS
        Reads commit JSON files locally (downloading any missing ones from SharePoint) and displays a sorted history table.
    #>
    param(
        [string][Parameter(Mandatory = $true)] $LocalRoot,
        [int]$Count = 10
    )

    #region Initialization *#
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

    if (-not (Get-Command Connect-SPGitSite -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\SPGit-Connect.ps1"
    }

    try {
        Connect-SPGitSite -SiteUrl $config.siteUrl
    }
    catch {
        Write-Host "WARN: Could not connect to SharePoint -- will use local commits only. $_" -ForegroundColor Yellow
    }
    #endregion Initialization *#

    #region Main Logic *#
    $commitDir = Join-Path $LocalRoot "metadata\commits"
    if (-not (Test-Path $commitDir)) {
        New-Item -ItemType Directory -Path $commitDir -Force | Out-Null
    }

    $spCommitFolder = "$($config.libraryName)/$($config.repoName)/metadata/commits"
    try {
        $remoteCommits = Get-PnPFolderItem -FolderSiteRelativeUrl $spCommitFolder -ItemType File -ErrorAction Stop
        foreach ($remoteFile in $remoteCommits) {
            $fileName  = $remoteFile.Name
            $localPath = Join-Path $commitDir $fileName
            if (-not (Test-Path $localPath)) {
                Write-Host "  Downloading missing commit: $fileName" -ForegroundColor Cyan
                try {
                    Get-PnPFile -Url $remoteFile.ServerRelativeUrl -Path $commitDir -FileName $fileName -AsFile -Force | Out-Null
                }
                catch {
                    Write-Host "  WARN: Could not download '$fileName' -- $_" -ForegroundColor Yellow
                }
            }
        }
    }
    catch {
        Write-Host "WARN: Could not enumerate remote commits -- $_" -ForegroundColor Yellow
    }

    $commits = @()

    if (Test-Path $commitDir) {
        $commitFiles = Get-ChildItem -Path $commitDir -Filter "commit-*.json" -File

        foreach ($file in $commitFiles) {
            try {
                $raw    = Get-Content -Path $file.FullName -Raw -Encoding UTF8
                $commit = $raw | ConvertFrom-Json
                $commits += $commit
            }
            catch {
                Write-Host "WARN: Could not parse '$($file.Name)' -- $_" -ForegroundColor Yellow
            }
        }
    }

    if ($commits.Count -eq 0) {
        Write-Host "No commits found." -ForegroundColor Yellow
        return @()
    }

    $sorted = $commits | Sort-Object { $_.createdUtc } -Descending | Select-Object -First $Count

    $sorted | Select-Object commitId, author, createdUtc, message | Format-Table -AutoSize

    return $sorted
    #endregion Main Logic *#
}
#endregion Functions *#
