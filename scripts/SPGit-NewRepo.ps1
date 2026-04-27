# ============================================================
# SPGit-NewRepo.ps1
# Version:     1.0.0
# Date:        2026-04-26
# Description: Creates a new SPGit repository folder structure and seed files on SharePoint.
# ============================================================

#region Initialization *#
. "$PSScriptRoot\SPGit-Connect.ps1"
#endregion Initialization *#

#region Functions *#
function New-SPGitRepo {
    <#
    .SYNOPSIS
        Creates a new SPGit repository with standard folder structure and seed files on SharePoint.
    #>
    param(
        [string][Parameter(Mandatory = $true)] $SiteUrl,
        [string]$LibraryName = "SPGit",
        [string][Parameter(Mandatory = $true)] $RepoName
    )

    Connect-SPGitSite -SiteUrl $SiteUrl

    $gitkeepBytes = [byte[]]@()

    function Upload-TextFile {
        <#
        .SYNOPSIS
            Uploads a file with text content to a SharePoint folder.
        #>
        param([string]$Folder, [string]$FileName, [string]$Content)
        try {
            $tempFile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllText($tempFile, $Content, [System.Text.Encoding]::UTF8)
            Add-PnPFile -Path $tempFile -Folder $Folder -NewFileName $FileName | Out-Null
            Remove-Item $tempFile -Force
            Write-Host "  Uploaded: $Folder/$FileName" -ForegroundColor Green
        }
        catch {
            Write-Host "  ERROR uploading $Folder/$FileName -- $_" -ForegroundColor Red
        }
    }

    function Upload-Gitkeep {
        <#
        .SYNOPSIS
            Uploads an empty .gitkeep file to a SharePoint folder to ensure the folder exists.
        #>
        param([string]$Folder)
        try {
            $tempFile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllBytes($tempFile, $gitkeepBytes)
            Add-PnPFile -Path $tempFile -Folder $Folder -NewFileName ".gitkeep" | Out-Null
            Remove-Item $tempFile -Force
            Write-Host "  Created folder (gitkeep): $Folder" -ForegroundColor Green
        }
        catch {
            Write-Host "  ERROR creating $Folder -- $_" -ForegroundColor Red
        }
    }

    $base = "$LibraryName/$RepoName"

    #region Main Logic *#
    Write-Host "Creating folder structure under '$base'..." -ForegroundColor Cyan
    $leafFolders = @(
        "$base/main/src"
        "$base/main/docs"
        "$base/main/tests"
        "$base/main/scripts"
        "$base/dev"
        "$base/releases"
        "$base/memory"
        "$base/metadata/commits"
        "$base/metadata/manifests"
        "$base/metadata/locks"
        "$base/metadata/sync-logs"
    )

    foreach ($folder in $leafFolders) {
        Upload-Gitkeep -Folder $folder
    }

    $repoConfig = @"
{
  "repoName": "$RepoName",
  "siteUrl": "https://groovepoint.sharepoint.com/sites/ET4SP/",
  "libraryName": "SPGit",
  "repoServerRelativeUrl": "/sites/ET4SP/SPGit/$RepoName",
  "localRoot": "",
  "defaultBranchModel": "controlled-sharepoint",
  "mainFolder": "main",
  "devFolder": "dev",
  "releaseFolder": "releases",
  "memoryFolder": "memory",
  "metadataFolder": "metadata",
  "ignoreFile": ".spgitignore",
  "requiresCheckout": true,
  "hashAlgorithm": "SHA256",
  "githubRemote": "",
  "githubWriteEnabled": false,
  "spgitPrimary": true
}
"@

    Write-Host "Uploading root files to '$base'..." -ForegroundColor Cyan

    Upload-TextFile -Folder $base -FileName "AGENT.md"     -Content "# AGENT.md`n`nAI behavior instructions for this repo."
    Upload-TextFile -Folder $base -FileName "SESSION.md"   -Content "# SESSION.md`n`nActive work and last session decisions."
    Upload-TextFile -Folder $base -FileName "CONTEXT.md"   -Content "# CONTEXT.md`n`nStable background and conventions for this repo."
    Upload-TextFile -Folder $base -FileName "README.md"    -Content "# $RepoName`n`nRepo description."
    Upload-TextFile -Folder $base -FileName "CHANGELOG.md" -Content "# CHANGELOG`n"
    Upload-TextFile -Folder $base -FileName ".spgitignore" -Content "metadata/locks/`nmetadata/sync-logs/"
    Upload-TextFile -Folder $base -FileName "repo.config.json" -Content $repoConfig

    Write-Host "Uploading memory files to '$base/memory'..." -ForegroundColor Cyan
    Upload-TextFile -Folder "$base/memory" -FileName "project_plan.md"  -Content "# Project Plan`n"
    Upload-TextFile -Folder "$base/memory" -FileName "status.md"        -Content "# Status`n"
    Upload-TextFile -Folder "$base/memory" -FileName "decisions.md"     -Content "# Decisions`n"
    Upload-TextFile -Folder "$base/memory" -FileName "improvements.md"  -Content "# Improvements`n"

    Write-Host "New-SPGitRepo '$RepoName' complete." -ForegroundColor Green
    #endregion Main Logic *#
}
#endregion Functions *#
