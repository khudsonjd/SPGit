# ============================================================
# SPGit-Manifest.ps1
# Version:     1.0.1
# Date:        2026-04-26
# Description: Reads and updates the local SPGit manifest file that tracks file state.
# ============================================================

#region Functions *#
function Get-SPGitManifest {
    <#
    .SYNOPSIS
        Reads and returns the current SPGit manifest from the local repo root.
    #>
    param(
        [string][Parameter(Mandatory = $true)] $LocalRoot
    )

    $manifestPath = Join-Path $LocalRoot "metadata\manifests\current-manifest.json"

    if (-not (Test-Path $manifestPath)) {
        Write-Host "No manifest found at: $manifestPath" -ForegroundColor Yellow
        return $null
    }

    try {
        $raw = Get-Content -Path $manifestPath -Raw -Encoding UTF8
        return ($raw | ConvertFrom-Json)
    }
    catch {
        Write-Host "ERROR: Failed to read manifest -- $_" -ForegroundColor Red
        throw
    }
}

function Update-SPGitManifest {
    <#
    .SYNOPSIS
        Scans local files, builds a fresh manifest, writes it locally, and uploads it to SharePoint.
    #>
    param(
        [string][Parameter(Mandatory = $true)] $LocalRoot
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

    $siteUrl             = $config.siteUrl
    $libraryName         = $config.libraryName
    $repoName            = $config.repoName
    $repoServerRelUrl    = $config.repoServerRelativeUrl

    $ignorePatterns = @()
    $ignoreFile = Join-Path $LocalRoot ".spgitignore"
    if (Test-Path $ignoreFile) {
        $ignorePatterns = Get-Content -Path $ignoreFile | Where-Object { $_.Trim() -ne "" }
    }
    #endregion Initialization *#

    #region Functions *#
    function Test-Ignored {
        <#
        .SYNOPSIS
            Returns $true if the given relative path matches any .spgitignore pattern.
        #>
        param([string]$RelPath)
        foreach ($pattern in $ignorePatterns) {
            $p = $pattern.TrimEnd('/')
            if ($RelPath -like "$p*") { return $true }
            if ($RelPath -like "*$p") { return $true }
        }
        return $false
    }
    #endregion Functions *#

    #region Main Logic *#
    Write-Host "Scanning local files under '$LocalRoot'..." -ForegroundColor Cyan
    $allLocal = Get-ChildItem -Path $LocalRoot -Recurse -File

    $entries = @()

    foreach ($file in $allLocal) {
        $relativePath = $file.FullName.Substring($LocalRoot.Length).TrimStart('\').Replace('\','/')

        if (Test-Ignored -RelPath $relativePath) {
            continue
        }

        if ($relativePath -eq 'metadata/manifests/current-manifest.json') {
            continue
        }

        $localHash = ""
        try {
            $localHash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
        }
        catch {
            Write-Host "  WARN: Could not hash '$($file.FullName)' -- $_" -ForegroundColor Yellow
        }

        $serverRelUrl = "$repoServerRelUrl/$relativePath"
        $remoteLastMod = ""

        try {
            $remoteFile = Get-PnPFile -Url $serverRelUrl -AsListItem -ErrorAction Stop
            if ($null -ne $remoteFile) {
                $remoteLastMod = $remoteFile["Modified"]
            }
        }
        catch {
            # File not on remote yet -- that is fine
        }

        $entry = [PSCustomObject]@{
            relativePath        = $relativePath
            serverRelativeUrl   = $serverRelUrl
            localHash           = $localHash
            remoteHash          = ""
            lastSyncUtc         = ""
            lastModifiedLocal   = $file.LastWriteTimeUtc.ToString("o")
            lastModifiedRemote  = if ($remoteLastMod) { $remoteLastMod.ToString() } else { "" }
            sizeBytes           = $file.Length
            status              = "LocalOnly"
        }

        $entries += $entry
    }

    $manifestDir = Join-Path $LocalRoot "metadata\manifests"
    if (-not (Test-Path $manifestDir)) {
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
    }

    $manifestPath = Join-Path $manifestDir "current-manifest.json"

    try {
        $entries | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8
        Write-Host "Manifest written to '$manifestPath' ($($entries.Count) entries)." -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to write manifest -- $_" -ForegroundColor Red
        throw
    }

    try {
        $spFolder = "$libraryName/$repoName/metadata/manifests"
        Add-PnPFile -Path $manifestPath -Folder $spFolder | Out-Null
        Write-Host "Manifest uploaded to SharePoint." -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to upload manifest to SharePoint -- $_" -ForegroundColor Red
    }

    return $entries
    #endregion Main Logic *#
}
#endregion Functions *#
