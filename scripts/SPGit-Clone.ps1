# ============================================================
# SPGit-Clone.ps1
# Version:     1.0.0
# Date:        2026-04-26
# Description: Downloads a remote SPGit repository from SharePoint to a local directory.
# ============================================================

#region Functions *#
function Clone-SPGitRepo {
    <#
    .SYNOPSIS
        Clones a remote SPGit repository from SharePoint into a local directory and builds the initial manifest.
    #>
    param(
        [string][Parameter(Mandatory = $true)] $SiteUrl,
        [string]$LibraryName = "SPGit",
        [string][Parameter(Mandatory = $true)] $RepoName,
        [string][Parameter(Mandatory = $true)] $LocalRoot
    )

    #region Initialization *#
    . "$PSScriptRoot\SPGit-Connect.ps1"
    . "$PSScriptRoot\SPGit-Manifest.ps1"

    Connect-SPGitSite -SiteUrl $SiteUrl

    $localRepoRoot = Join-Path $LocalRoot $RepoName

    if (-not (Test-Path $localRepoRoot)) {
        Write-Host "Creating local directory '$localRepoRoot'..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $localRepoRoot -Force | Out-Null
    }
    else {
        Write-Host "Local directory '$localRepoRoot' already exists." -ForegroundColor Yellow
    }
    #endregion Initialization *#

    #region Main Logic *#
    Write-Host "Enumerating remote files under '$LibraryName/$RepoName'..." -ForegroundColor Cyan

    $remoteItems = $null
    try {
        $remoteItems = Get-PnPFolderItem -FolderSiteRelativeUrl "$LibraryName/$RepoName" -ItemType File -Recursive -ErrorAction Stop
    }
    catch {
        Write-Host "ERROR: Failed to enumerate remote folder -- $_" -ForegroundColor Red
        throw
    }

    $downloadCount = 0
    $errorCount    = 0

    foreach ($item in $remoteItems) {
        $serverRelUrl = $item.ServerRelativeUrl
        $fileName     = $item.Name

        $prefix = "/$LibraryName/$RepoName/"
        $relPath = $serverRelUrl
        if ($serverRelUrl -like "*$prefix*") {
            $idx     = $serverRelUrl.IndexOf($prefix)
            $relPath = $serverRelUrl.Substring($idx + $prefix.Length)
        }

        $relDir    = [System.IO.Path]::GetDirectoryName($relPath)
        $localDir  = Join-Path $localRepoRoot $relDir

        if (-not (Test-Path $localDir)) {
            New-Item -ItemType Directory -Path $localDir -Force | Out-Null
        }

        try {
            Get-PnPFile -Url $serverRelUrl -Path $localDir -FileName $fileName -AsFile -Force | Out-Null
            Write-Host "  Downloaded: $relPath" -ForegroundColor Green
            $downloadCount++
        }
        catch {
            Write-Host "  ERROR downloading '$relPath' -- $_" -ForegroundColor Red
            $errorCount++
        }
    }

    Write-Host "Downloaded $downloadCount file(s), $errorCount error(s)." -ForegroundColor Cyan
    #endregion Main Logic *#

    #region Post-Clone *#
    $configPath = Join-Path $localRepoRoot "repo.config.json"
    if (Test-Path $configPath) {
        try {
            $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $config.localRoot = $localRepoRoot
            $config | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8
            Write-Host "Updated repo.config.json localRoot to '$localRepoRoot'." -ForegroundColor Green
        }
        catch {
            Write-Host "WARN: Could not update repo.config.json -- $_" -ForegroundColor Yellow
        }
    }

    Write-Host "Building manifest..." -ForegroundColor Cyan
    Update-SPGitManifest -LocalRoot $localRepoRoot

    Write-Host "Clone-SPGitRepo '$RepoName' complete." -ForegroundColor Green
    #endregion Post-Clone *#
}
#endregion Functions *#
