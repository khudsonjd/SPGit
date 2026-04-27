# ============================================================
# SPGit-Pull.ps1
# Version:     1.0.1
# Date:        2026-04-26
# Description: Downloads remote-modified and remote-only files from SharePoint to the local repo.
# ============================================================

#region Functions *#
function Pull-SPGitRepo {
    <#
    .SYNOPSIS
        Pulls remote changes from SharePoint into the local SPGit repo, skipping conflicts.
    #>
    param(
        [string][Parameter(Mandatory = $true)] $LocalRoot
    )

    #region Initialization *#
    . "$PSScriptRoot\SPGit-Connect.ps1"
    . "$PSScriptRoot\SPGit-Status.ps1"
    . "$PSScriptRoot\SPGit-Manifest.ps1"

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

    $null = Connect-SPGitSite -SiteUrl $config.siteUrl
    #endregion Initialization *#

    #region Main Logic *#
    Write-Host "Getting status..." -ForegroundColor Cyan
    $statusItems = Get-SPGitStatus -LocalRoot $LocalRoot

    $downloaded = @()
    $conflicts  = @()
    $errors     = @()

    foreach ($item in $statusItems) {
        if ($item.Status -eq "RemoteModified" -or $item.Status -eq "RemoteOnly") {
            $serverRelUrl = "$($config.repoServerRelativeUrl)/$($item.RelativePath)"
            $localFile    = Join-Path $LocalRoot ($item.RelativePath.Replace('/', '\'))
            $localDir     = [System.IO.Path]::GetDirectoryName($localFile)
            $fileName     = [System.IO.Path]::GetFileName($localFile)

            if (-not (Test-Path $localDir)) {
                New-Item -ItemType Directory -Path $localDir -Force | Out-Null
            }

            try {
                Get-PnPFile -Url $serverRelUrl -Path $localDir -FileName $fileName -AsFile -Force | Out-Null
                Write-Host "  Pulled: $($item.RelativePath)" -ForegroundColor Green
                $downloaded += $item.RelativePath
            }
            catch {
                Write-Host "  ERROR pulling '$($item.RelativePath)' -- $_" -ForegroundColor Red
                $errors += $item.RelativePath
            }
        }
        elseif ($item.Status -eq "Conflict") {
            Write-Host "  CONFLICT (skipped): $($item.RelativePath)" -ForegroundColor Yellow
            $conflicts += $item.RelativePath
        }
    }

    Write-Host "Updating manifest..." -ForegroundColor Cyan
    Update-SPGitManifest -LocalRoot $LocalRoot | Out-Null
    #endregion Main Logic *#

    #region Logging *#
    $timestamp  = Get-Date -Format "yyyyMMdd-HHmmss"
    $logDir     = Join-Path $LocalRoot "metadata\sync-logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $logPath = Join-Path $logDir "pull-$timestamp.json"
    $logObj  = [PSCustomObject]@{
        timestamp       = (Get-Date -Format "o")
        filesDownloaded = $downloaded
        conflicts       = $conflicts
        errors          = $errors
    }

    try {
        $logObj | ConvertTo-Json -Depth 5 | Set-Content -Path $logPath -Encoding UTF8
        Write-Host "Pull log written to '$logPath'." -ForegroundColor Cyan
    }
    catch {
        Write-Host "WARN: Could not write pull log -- $_" -ForegroundColor Yellow
    }

    Write-Host "Pull-SPGitRepo complete. Downloaded: $($downloaded.Count), Conflicts: $($conflicts.Count), Errors: $($errors.Count)." -ForegroundColor Green
    #endregion Logging *#
}
#endregion Functions *#
