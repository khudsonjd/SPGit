# ============================================================
# SPGit-Restore.ps1
# Version:     1.0.0
# Date:        2026-04-26
# Description: Restores local files from a SharePoint commit version, release snapshot, or current remote file.
# ============================================================

#region Functions *#
function Restore-SPGitVersion {
    <#
    .SYNOPSIS
        Restores local files from a commit version history, a named release folder, or a single remote file path on SharePoint.
    #>
    param(
        [string][Parameter(Mandatory = $true)] $LocalRoot,
        [string]$CommitId    = "",
        [string]$ReleaseName = "",
        [string]$RelativePath = "",
        [switch]$Force
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

    $provided = @($CommitId, $ReleaseName, $RelativePath) | Where-Object { $_ -ne "" }
    if ($provided.Count -eq 0) {
        Write-Host "ERROR: Provide exactly one of -CommitId, -ReleaseName, or -RelativePath." -ForegroundColor Red
        return
    }
    if ($provided.Count -gt 1) {
        Write-Host "WARN: Multiple restore targets provided -- provide exactly one of -CommitId, -ReleaseName, or -RelativePath." -ForegroundColor Yellow
        return
    }

    $manifestLookup = @{}
    $manifestPath   = Join-Path $LocalRoot "metadata\manifests\current-manifest.json"
    if (Test-Path $manifestPath) {
        try {
            $manifest = Get-Content -Path $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($entry in $manifest) {
                $manifestLookup[$entry.relativePath] = $entry
            }
        }
        catch {}
    }
    #endregion Initialization *#

    #region Helper Functions *#
    function Test-LocallyModified {
        <#
        .SYNOPSIS
            Returns $true if the local file differs from its manifest hash, indicating unsaved changes.
        #>
        param([string]$RelPath)
        $localFile = Join-Path $LocalRoot ($RelPath.Replace('/', '\'))
        if (-not (Test-Path $localFile)) { return $false }
        if (-not $manifestLookup.ContainsKey($RelPath)) { return $false }
        $currentHash = ""
        try { $currentHash = (Get-FileHash -Path $localFile -Algorithm SHA256).Hash } catch {}
        return ($currentHash -ne $manifestLookup[$RelPath].localHash)
    }

    function Download-ToLocal {
        <#
        .SYNOPSIS
            Downloads a file from SharePoint to its corresponding local path, respecting the -Force flag.
        #>
        param([string]$ServerRelUrl, [string]$LocalRelPath)
        $localFile = Join-Path $LocalRoot ($LocalRelPath.Replace('/', '\'))
        $localDir  = [System.IO.Path]::GetDirectoryName($localFile)
        $fileName  = [System.IO.Path]::GetFileName($localFile)

        if (-not $Force -and (Test-LocallyModified -RelPath $LocalRelPath)) {
            Write-Host "  SKIP (locally modified, use -Force to overwrite): $LocalRelPath" -ForegroundColor Yellow
            return
        }

        if (-not (Test-Path $localDir)) {
            New-Item -ItemType Directory -Path $localDir -Force | Out-Null
        }

        try {
            Get-PnPFile -Url $ServerRelUrl -Path $localDir -FileName $fileName -AsFile -Force | Out-Null
            Write-Host "  Restored: $LocalRelPath" -ForegroundColor Green
        }
        catch {
            Write-Host "  ERROR restoring '$LocalRelPath' -- $_" -ForegroundColor Red
        }
    }
    #endregion Helper Functions *#

    #region Main Logic *#
    if ($CommitId -ne "") {
        Write-Host "Restoring from commit '$CommitId'..." -ForegroundColor Cyan
        $commitFile = Join-Path $LocalRoot "metadata\commits\commit-$CommitId.json"

        if (-not (Test-Path $commitFile)) {
            $spCommitUrl = "$($config.repoServerRelativeUrl)/metadata/commits/commit-$CommitId.json"
            $commitDir   = Join-Path $LocalRoot "metadata\commits"
            if (-not (Test-Path $commitDir)) { New-Item -ItemType Directory -Path $commitDir -Force | Out-Null }
            try {
                Get-PnPFile -Url $spCommitUrl -Path $commitDir -FileName "commit-$CommitId.json" -AsFile -Force | Out-Null
            }
            catch {
                Write-Host "ERROR: Commit '$CommitId' not found locally or on SharePoint." -ForegroundColor Red
                return
            }
        }

        try {
            $commitRecord = Get-Content -Path $commitFile -Raw -Encoding UTF8 | ConvertFrom-Json
        }
        catch {
            Write-Host "ERROR: Failed to parse commit file -- $_" -ForegroundColor Red
            return
        }

        foreach ($filePath in $commitRecord.files) {
            $serverRelUrl = "$($config.repoServerRelativeUrl)/$filePath"

            try {
                $versions = Get-PnPFileVersion -Url $serverRelUrl -ErrorAction Stop | Sort-Object Created -Descending

                $commitTime    = [DateTime]::Parse($commitRecord.createdUtc)
                $targetVersion = $versions | Where-Object { $_.Created -le $commitTime } | Select-Object -First 1

                if ($null -eq $targetVersion) {
                    $targetVersion = $versions | Select-Object -Last 1
                }

                if ($null -ne $targetVersion) {
                    if (-not $Force -and (Test-LocallyModified -RelPath $filePath)) {
                        Write-Host "  SKIP (locally modified, use -Force to overwrite): $filePath" -ForegroundColor Yellow
                        continue
                    }

                    $localFile = Join-Path $LocalRoot ($filePath.Replace('/', '\'))
                    $localDir  = [System.IO.Path]::GetDirectoryName($localFile)
                    $fileName  = [System.IO.Path]::GetFileName($localFile)

                    if (-not (Test-Path $localDir)) {
                        New-Item -ItemType Directory -Path $localDir -Force | Out-Null
                    }

                    $versionStream = $targetVersion.OpenBinaryStream().Value
                    $fileStream    = [System.IO.File]::Create($localFile)
                    try {
                        $versionStream.CopyTo($fileStream)
                    }
                    finally {
                        $fileStream.Close()
                        $versionStream.Close()
                    }
                    Write-Host "  Restored (v$($targetVersion.VersionLabel)): $filePath" -ForegroundColor Green
                }
                else {
                    Write-Host "  WARN: No suitable version found for '$filePath'" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "  ERROR restoring '$filePath' from commit -- $_" -ForegroundColor Red
            }
        }
    }
    elseif ($ReleaseName -ne "") {
        Write-Host "Restoring from release '$ReleaseName'..." -ForegroundColor Cyan
        $releaseSPFolder = "$($config.libraryName)/$($config.repoName)/releases/$ReleaseName"

        try {
            $releaseFiles = Get-PnPFolderItem -FolderSiteRelativeUrl $releaseSPFolder -ItemType File -Recursive -ErrorAction Stop
        }
        catch {
            Write-Host "ERROR: Could not find release '$ReleaseName' on SharePoint -- $_" -ForegroundColor Red
            return
        }

        foreach ($file in $releaseFiles) {
            $serverRelUrl = $file.ServerRelativeUrl
            $prefix       = "/$($config.libraryName)/$($config.repoName)/releases/$ReleaseName/"
            $relPath      = $serverRelUrl
            if ($serverRelUrl -like "*$prefix*") {
                $idx     = $serverRelUrl.IndexOf($prefix)
                $relPath = $serverRelUrl.Substring($idx + $prefix.Length)
            }
            Download-ToLocal -ServerRelUrl $serverRelUrl -LocalRelPath $relPath
        }
    }
    elseif ($RelativePath -ne "") {
        Write-Host "Restoring single file '$RelativePath'..." -ForegroundColor Cyan
        $serverRelUrl = "$($config.repoServerRelativeUrl)/$RelativePath"
        Download-ToLocal -ServerRelUrl $serverRelUrl -LocalRelPath $RelativePath
    }

    Write-Host "Restore-SPGitVersion complete." -ForegroundColor Green
    #endregion Main Logic *#
}
#endregion Functions *#
