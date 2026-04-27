# ============================================================
# SPGit-Push.ps1
# Version:     1.0.1
# Date:        2026-04-26
# Description: Uploads locally modified and new files from the local repo to SharePoint.
# ============================================================

#region Functions *#
function Push-SPGitRepo {
    <#
    .SYNOPSIS
        Pushes locally modified and new files from the local SPGit repo to SharePoint, skipping conflicts.
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

    $uploaded  = @()
    $conflicts = @()
    $errors    = @()

    foreach ($item in $statusItems) {
        if ($item.Status -eq "LocalModified" -or $item.Status -eq "LocalOnly") {
            $localFile = Join-Path $LocalRoot ($item.RelativePath.Replace('/', '\'))

            if (-not (Test-Path $localFile)) {
                Write-Host "  WARN: Local file not found '$localFile' -- skipping." -ForegroundColor Yellow
                continue
            }

            $relDir  = [System.IO.Path]::GetDirectoryName($item.RelativePath).Replace('\','/')
            $spFolder = "$($config.libraryName)/$($config.repoName)"
            if ($relDir -and $relDir -ne ".") {
                $spFolder = "$spFolder/$relDir"
            }

            try {
                Add-PnPFile -Path $localFile -Folder $spFolder | Out-Null
                Write-Host "  Pushed: $($item.RelativePath)" -ForegroundColor Green
                $uploaded += $item.RelativePath
            }
            catch {
                Write-Host "  ERROR pushing '$($item.RelativePath)' -- $_" -ForegroundColor Red
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
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logDir    = Join-Path $LocalRoot "metadata\sync-logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $logPath = Join-Path $logDir "push-$timestamp.json"
    $logObj  = [PSCustomObject]@{
        timestamp     = (Get-Date -Format "o")
        filesUploaded = $uploaded
        conflicts     = $conflicts
        errors        = $errors
    }

    try {
        $logObj | ConvertTo-Json -Depth 5 | Set-Content -Path $logPath -Encoding UTF8
        Write-Host "Push log written to '$logPath'." -ForegroundColor Cyan
    }
    catch {
        Write-Host "WARN: Could not write push log -- $_" -ForegroundColor Yellow
    }

    Write-Host "Push-SPGitRepo complete. Uploaded: $($uploaded.Count), Conflicts: $($conflicts.Count), Errors: $($errors.Count)." -ForegroundColor Green
    #endregion Logging *#
}
#endregion Functions *#
