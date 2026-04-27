# ============================================================
# SPGit-Diff.ps1
# Version:     1.0.0
# Date:        2026-04-26
# Description: Compares a local file against its remote SharePoint version and shows line-level differences.
# ============================================================

#region Functions *#
function Compare-SPGitFile {
    <#
    .SYNOPSIS
        Downloads the remote copy of a file from SharePoint, compares it to the local copy by hash, and prints a text diff for supported file types.
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
    $localFile    = Join-Path $LocalRoot ($RelativePath.Replace('/', '\'))
    $serverRelUrl = "$($config.repoServerRelativeUrl)/$RelativePath"

    if (-not (Test-Path $localFile)) {
        Write-Host "ERROR: Local file not found: '$localFile'" -ForegroundColor Red
        return
    }

    $localHash = ""
    try {
        $localHash = (Get-FileHash -Path $localFile -Algorithm SHA256).Hash
    }
    catch {
        Write-Host "ERROR: Could not hash local file -- $_" -ForegroundColor Red
        return
    }

    $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "spgit-diff-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))-$([System.IO.Path]::GetFileName($localFile))")
    $tempDir  = [System.IO.Path]::GetDirectoryName($tempFile)
    $tempName = [System.IO.Path]::GetFileName($tempFile)

    $remoteHash = ""
    try {
        Get-PnPFile -Url $serverRelUrl -Path $tempDir -FileName $tempName -AsFile -Force | Out-Null
        $remoteHash = (Get-FileHash -Path $tempFile -Algorithm SHA256).Hash
    }
    catch {
        Write-Host "ERROR: Could not download remote file '$serverRelUrl' -- $_" -ForegroundColor Red
        return
    }

    try {
        if ($localHash -eq $remoteHash) {
            Write-Host "Files are identical. (SHA256: $localHash)" -ForegroundColor Green
            return
        }

        Write-Host "Files differ." -ForegroundColor Yellow
        Write-Host "  Local  hash: $localHash" -ForegroundColor Cyan
        Write-Host "  Remote hash: $remoteHash" -ForegroundColor Cyan

        $textExtensions = @(".ps1", ".md", ".json", ".txt", ".csv", ".xml", ".html", ".htm", ".js", ".ts", ".yaml", ".yml")
        $ext = [System.IO.Path]::GetExtension($localFile).ToLower()

        if ($textExtensions -contains $ext) {
            Write-Host ""
            Write-Host "--- Remote" -ForegroundColor DarkGray
            Write-Host "+++ Local" -ForegroundColor DarkGray

            $localLines  = Get-Content -Path $localFile  -Encoding UTF8
            $remoteLines = Get-Content -Path $tempFile   -Encoding UTF8

            $diff = Compare-Object -ReferenceObject $remoteLines -DifferenceObject $localLines

            foreach ($line in $diff) {
                if ($line.SideIndicator -eq "=>") {
                    Write-Host "+ $($line.InputObject)" -ForegroundColor Green
                }
                else {
                    Write-Host "- $($line.InputObject)" -ForegroundColor Red
                }
            }
        }
        else {
            Write-Host "Files differ (binary -- hash comparison only). Local: $localHash  Remote: $remoteHash" -ForegroundColor Yellow
        }
    }
    finally {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
    #endregion Main Logic *#
}
#endregion Functions *#
