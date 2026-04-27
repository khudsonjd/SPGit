# ============================================================
# SPGit-Status.ps1
# Version:     1.0.2
# Date:        2026-04-26
# Description: Reports the sync status of each file in the local SPGit repo against SharePoint.
# ============================================================

#region Functions *#
function Get-SPGitStatus {
    <#
    .SYNOPSIS
        Compares local files against the manifest and remote SharePoint state to report per-file status.
    #>
    param(
        [string][Parameter(Mandatory = $true)] $LocalRoot
    )

    #region Initialization *#
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

    $libraryName      = $config.libraryName
    $repoName         = $config.repoName
    $repoServerRelUrl = $config.repoServerRelativeUrl

    $manifest = Get-SPGitManifest -LocalRoot $LocalRoot
    if ($null -eq $manifest) {
        Write-Host "No manifest found -- run Update-SPGitManifest first." -ForegroundColor Yellow
        return @()
    }
    #endregion Initialization *#

    #region Main Logic *#
    $results = @()

    $manifestLookup = @{}
    foreach ($entry in $manifest) {
        $manifestLookup[$entry.relativePath] = $entry
    }

    foreach ($entry in $manifest) {
        $localFile = Join-Path $LocalRoot ($entry.relativePath.Replace('/', '\'))
        $status    = "Synced"

        if (-not (Test-Path $localFile)) {
            $status = "LocalDeleted"
        }
        else {
            $currentHash = ""
            try {
                $currentHash = (Get-FileHash -Path $localFile -Algorithm SHA256).Hash
            }
            catch {
                Write-Host "  WARN: Could not hash '$localFile' -- $_" -ForegroundColor Yellow
            }

            $localChanged = ($currentHash -ne $entry.localHash)

            $remoteChanged = $false
            $freshRemoteHash = $entry.remoteHash
            try {
                $remoteFile = Get-PnPFile -Url $entry.serverRelativeUrl -AsListItem -ErrorAction Stop
                if ($null -ne $remoteFile) {
                    $remoteMod = $remoteFile["Modified"]
                    if ($remoteMod -and $entry.lastModifiedRemote -and $remoteMod.ToString() -ne $entry.lastModifiedRemote) {
                        $remoteChanged = $true
                    }
                }
            }
            catch {
                $remoteChanged = $false
            }

            if ($localChanged -and $remoteChanged) {
                $status = "Conflict"
            }
            elseif ($localChanged) {
                $status = "LocalModified"
            }
            elseif ($remoteChanged) {
                $status = "RemoteModified"
            }
            else {
                $status = "Synced"
            }
        }

        $results += [PSCustomObject]@{
            RelativePath = $entry.relativePath
            Status       = $status
            LocalHash    = $entry.localHash
            RemoteHash   = $entry.remoteHash
        }
    }

    # Bug 2 fix: load .spgitignore patterns for remote scan filtering
    $ignorePatterns = @()
    $ignorePath = Join-Path $LocalRoot ".spgitignore"
    if (Test-Path $ignorePath) {
        $ignorePatterns = Get-Content -Path $ignorePath -Encoding UTF8 |
            Where-Object { $_ -and $_ -notmatch '^\s*#' } |
            ForEach-Object { $_.Trim() }
    }

    $allLocal = Get-ChildItem -Path $LocalRoot -Recurse -File
    foreach ($file in $allLocal) {
        $relPath = $file.FullName.Substring($LocalRoot.Length).TrimStart('\').Replace('\','/')
        if ($relPath -eq 'metadata/manifests/current-manifest.json') { continue }
        $ignoredLocal = $false
        foreach ($p in $ignorePatterns) {
            $pt = $p.TrimEnd('/')
            if ($relPath -like "$pt*" -or $relPath -like "*$pt") { $ignoredLocal = $true; break }
        }
        if ($ignoredLocal) { continue }
        if (-not $manifestLookup.ContainsKey($relPath)) {
            $localHash = ""
            try { $localHash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash } catch {}
            $results += [PSCustomObject]@{
                RelativePath = $relPath
                Status       = "LocalOnly"
                LocalHash    = $localHash
                RemoteHash   = ""
            }
        }
    }

    try {
        $remoteItems = Get-PnPFolderItem -FolderSiteRelativeUrl "$libraryName/$repoName" -ItemType File -Recursive -ErrorAction Stop
        foreach ($item in $remoteItems) {
            $serverRelUrl = $item.ServerRelativeUrl
            $prefix       = "/$libraryName/$repoName/"
            $relPath      = $serverRelUrl
            if ($serverRelUrl -like "*$prefix*") {
                $idx     = $serverRelUrl.IndexOf($prefix)
                $relPath = $serverRelUrl.Substring($idx + $prefix.Length)
            }
            # Bug 3 fix: skip the manifest bootstrap file in remote-only scan
            if ($relPath -eq 'metadata/manifests/current-manifest.json') { continue }
            # Bug 2 fix: skip files that match .spgitignore patterns
            $ignored = $false
            foreach ($p in $ignorePatterns) {
                $pt = $p.TrimEnd('/')
                if ($relPath -like "$pt*" -or $relPath -like "*$pt") {
                    $ignored = $true
                    break
                }
            }
            if ($ignored) { continue }
            if (-not $manifestLookup.ContainsKey($relPath)) {
                $results += [PSCustomObject]@{
                    RelativePath = $relPath
                    Status       = "RemoteOnly"
                    LocalHash    = ""
                    RemoteHash   = ""
                }
            }
        }
    }
    catch {
        Write-Host "WARN: Could not enumerate remote for RemoteOnly check -- $_" -ForegroundColor Yellow
    }

    return $results
    #endregion Main Logic *#
}
#endregion Functions *#
