# ============================================================
# SPGit-Lock.ps1
# Version:     1.0.0
# Date:        2026-04-26
# Description: Acquires and releases advisory file locks stored in SharePoint to coordinate edits.
# ============================================================

#region Functions *#
function Lock-SPGitFile {
    <#
    .SYNOPSIS
        Creates an advisory lock record for a file in SharePoint so other users can see it is in use.
    #>
    param(
        [string][Parameter(Mandatory = $true)] $LocalRoot,
        [string][Parameter(Mandatory = $true)] $RelativePath,
        [int]$DurationHours = 4
    )

    #region Initialization *#
    . "$PSScriptRoot\SPGit-Connect.ps1"

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
    $sanitized   = $RelativePath -replace '[/\\]', '-'
    $lockFileName = "lock-$sanitized.json"
    $lockDir      = Join-Path $LocalRoot "metadata\locks"
    $lockFile     = Join-Path $lockDir $lockFileName
    $spLockFolder = "$($config.libraryName)/$($config.repoName)/metadata/locks"
    $spLockUrl    = "$($config.repoServerRelativeUrl)/metadata/locks/$lockFileName"

    try {
        $existingLockFile = Get-PnPFile -Url $spLockUrl -AsString -ErrorAction Stop
        if ($existingLockFile) {
            try {
                $existingLock = $existingLockFile | ConvertFrom-Json
                $expiresAt    = [DateTime]::Parse($existingLock.expiresAt)

                if ($expiresAt -gt (Get-Date).ToUniversalTime()) {
                    Write-Host "WARN: File '$RelativePath' is already locked by '$($existingLock.lockedBy)' until $($existingLock.expiresAt)." -ForegroundColor Yellow
                    return
                }
                else {
                    Write-Host "Existing lock is expired -- replacing." -ForegroundColor Cyan
                }
            }
            catch {
                Write-Host "WARN: Could not parse existing lock file -- will overwrite." -ForegroundColor Yellow
            }
        }
    }
    catch {
        # No existing lock -- that is fine
    }

    $now       = (Get-Date).ToUniversalTime()
    $expiresAt = $now.AddHours($DurationHours)

    $lockObj = [PSCustomObject]@{
        path      = $RelativePath
        lockedBy  = $env:USERNAME
        lockedAt  = $now.ToString("o")
        expiresAt = $expiresAt.ToString("o")
    }

    if (-not (Test-Path $lockDir)) {
        New-Item -ItemType Directory -Path $lockDir -Force | Out-Null
    }

    try {
        $lockObj | ConvertTo-Json -Depth 3 | Set-Content -Path $lockFile -Encoding UTF8
        Write-Host "Lock file written locally: '$lockFile'" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Could not write lock file locally -- $_" -ForegroundColor Red
        throw
    }

    try {
        Add-PnPFile -Path $lockFile -Folder $spLockFolder | Out-Null
        Write-Host "Lock uploaded to SharePoint for '$RelativePath' (expires: $($expiresAt.ToString('o')))." -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Could not upload lock to SharePoint -- $_" -ForegroundColor Red
    }
    #endregion Main Logic *#
}

function Unlock-SPGitFile {
    <#
    .SYNOPSIS
        Removes an advisory lock from SharePoint for a file, verifying ownership or expiry before deletion.
    #>
    param(
        [string][Parameter(Mandatory = $true)] $LocalRoot,
        [string][Parameter(Mandatory = $true)] $RelativePath
    )

    #region Initialization *#
    . "$PSScriptRoot\SPGit-Connect.ps1"

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
    $sanitized    = $RelativePath -replace '[/\\]', '-'
    $lockFileName = "lock-$sanitized.json"
    $lockDir      = Join-Path $LocalRoot "metadata\locks"
    $lockFile     = Join-Path $lockDir $lockFileName
    $spLockFolder = "$($config.libraryName)/$($config.repoName)/metadata/locks"
    $spLockUrl    = "$($config.repoServerRelativeUrl)/metadata/locks/$lockFileName"

    $lockObj = $null

    if (Test-Path $lockFile) {
        try {
            $lockObj = Get-Content -Path $lockFile -Raw -Encoding UTF8 | ConvertFrom-Json
        }
        catch {
            Write-Host "WARN: Could not parse local lock file." -ForegroundColor Yellow
        }
    }
    else {
        try {
            $raw     = Get-PnPFile -Url $spLockUrl -AsString -ErrorAction Stop
            $lockObj = $raw | ConvertFrom-Json
        }
        catch {
            Write-Host "ERROR: Lock file not found locally or on SharePoint for '$RelativePath'." -ForegroundColor Red
            return
        }
    }

    $isOwner  = ($lockObj.lockedBy -eq $env:USERNAME)
    $expiresAt = [DateTime]::Parse($lockObj.expiresAt)
    $isExpired = ($expiresAt -le (Get-Date).ToUniversalTime())

    if (-not $isOwner -and -not $isExpired) {
        Write-Host "ERROR: Cannot unlock '$RelativePath' -- owned by '$($lockObj.lockedBy)' and not yet expired (expires: $($lockObj.expiresAt))." -ForegroundColor Red
        return
    }

    if (Test-Path $lockFile) {
        try {
            Remove-Item $lockFile -Force
            Write-Host "Local lock file removed." -ForegroundColor Green
        }
        catch {
            Write-Host "WARN: Could not remove local lock file -- $_" -ForegroundColor Yellow
        }
    }

    try {
        Remove-PnPFile -ServerRelativeUrl $spLockUrl -Force -ErrorAction Stop
        Write-Host "Lock removed from SharePoint for '$RelativePath'." -ForegroundColor Green
    }
    catch {
        Write-Host "WARN: Could not remove SharePoint lock file -- $_" -ForegroundColor Yellow
    }
    #endregion Main Logic *#
}
#endregion Functions *#
