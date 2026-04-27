# ============================================================
# SPGit-Sync.ps1
# Version:     1.0.0
# Date:        2026-04-26
# Description: Runs a pull then a push against SharePoint and logs the combined sync result.
# ============================================================

#region Functions *#
function Sync-SPGitRepo {
    <#
    .SYNOPSIS
        Performs a full bidirectional sync by running Pull then Push, then reports any remaining conflicts.
    #>
    param(
        [string][Parameter(Mandatory = $true)] $LocalRoot
    )

    #region Initialization *#
    . "$PSScriptRoot\SPGit-Pull.ps1"
    . "$PSScriptRoot\SPGit-Push.ps1"

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    #endregion Initialization *#

    #region Main Logic *#
    Write-Host "=== SPGit Sync: Pull ===" -ForegroundColor Cyan
    $pullError = $null
    try {
        Pull-SPGitRepo -LocalRoot $LocalRoot
    }
    catch {
        $pullError = $_.ToString()
        Write-Host "ERROR during pull -- $_" -ForegroundColor Red
    }

    Write-Host "=== SPGit Sync: Push ===" -ForegroundColor Cyan
    $pushError = $null
    try {
        Push-SPGitRepo -LocalRoot $LocalRoot
    }
    catch {
        $pushError = $_.ToString()
        Write-Host "ERROR during push -- $_" -ForegroundColor Red
    }

    Write-Host "=== SPGit Sync: Checking remaining conflicts ===" -ForegroundColor Cyan

    if (-not (Get-Command Get-SPGitStatus -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot\SPGit-Status.ps1"
    }

    $remainingConflicts = @()
    try {
        $statusItems = Get-SPGitStatus -LocalRoot $LocalRoot
        $remainingConflicts = @($statusItems | Where-Object { $_.Status -eq "Conflict" })
    }
    catch {
        Write-Host "WARN: Could not check post-sync status -- $_" -ForegroundColor Yellow
    }
    #endregion Main Logic *#

    #region Logging *#
    $logDir = Join-Path $LocalRoot "metadata\sync-logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $logPath = Join-Path $logDir "sync-$timestamp.json"
    $logObj  = [PSCustomObject]@{
        timestamp          = (Get-Date -Format "o")
        pullError          = $pullError
        pushError          = $pushError
        remainingConflicts = ($remainingConflicts | Select-Object -ExpandProperty RelativePath)
        errors             = @($pullError, $pushError | Where-Object { $_ })
    }

    try {
        $logObj | ConvertTo-Json -Depth 5 | Set-Content -Path $logPath -Encoding UTF8
        Write-Host "Sync log written to '$logPath'." -ForegroundColor Cyan
    }
    catch {
        Write-Host "WARN: Could not write sync log -- $_" -ForegroundColor Yellow
    }
    #endregion Logging *#

    #region Summary *#
    Write-Host ""
    Write-Host "=== Sync Summary ===" -ForegroundColor Green
    if ($pullError)  { Write-Host "  Pull error:  $pullError"  -ForegroundColor Red }
    if ($pushError)  { Write-Host "  Push error:  $pushError"  -ForegroundColor Red }
    if ($remainingConflicts.Count -gt 0) {
        Write-Host "  Remaining conflicts: $($remainingConflicts.Count)" -ForegroundColor Yellow
        foreach ($c in $remainingConflicts) {
            Write-Host "    - $($c.RelativePath)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  No remaining conflicts." -ForegroundColor Green
    }
    Write-Host "Sync-SPGitRepo complete." -ForegroundColor Green
    #endregion Summary *#
}
#endregion Functions *#
