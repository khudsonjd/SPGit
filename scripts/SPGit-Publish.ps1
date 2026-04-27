# ============================================================
# SPGit-Publish.ps1
# Version:     1.0.0
# Date:        2026-04-26
# Description: Packages the main branch as a versioned release and uploads it to SharePoint.
# ============================================================

#region Functions *#
function Publish-SPGitRelease {
    <#
    .SYNOPSIS
        Copies the main folder, builds a manifest and release notes, zips the package, and uploads all files to the SharePoint releases folder.
    #>
    param(
        [string][Parameter(Mandatory = $true)] $LocalRoot,
        [string]$ReleaseNotes = "",
        [string]$Version      = ""
    )

    #region Initialization *#
    . "$PSScriptRoot\SPGit-Connect.ps1"

    Add-Type -AssemblyName System.IO.Compression.FileSystem

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

    $libraryName = $config.libraryName
    $repoName    = $config.repoName
    #endregion Initialization *#

    #region Main Logic *#
    if (-not $Version) {
        $baseVersion = "v$(Get-Date -Format 'yyyy.MM.dd')"
        $Version     = "$baseVersion.1"
        $n           = 1

        $existingFolders = @()
        try {
            $existingFolders = Get-PnPFolderItem -FolderSiteRelativeUrl "$libraryName/$repoName/releases" -ItemType Folder -ErrorAction SilentlyContinue |
                               Select-Object -ExpandProperty Name
        }
        catch {}

        while ($existingFolders -contains $Version) {
            $n++
            $Version = "$baseVersion.$n"
        }
    }

    Write-Host "Publishing release '$Version'..." -ForegroundColor Cyan

    $mainSource = Join-Path $LocalRoot "main"
    if (-not (Test-Path $mainSource)) {
        Write-Host "ERROR: main\ folder not found at '$LocalRoot'" -ForegroundColor Red
        throw "Missing main folder"
    }

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "spgit-release-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        Write-Host "Copying main\ to staging folder..." -ForegroundColor Cyan
        Copy-Item -Path "$mainSource\*" -Destination $tempDir -Recurse -Force

        $manifestEntries = @()
        $allFiles = Get-ChildItem -Path $tempDir -Recurse -File
        foreach ($file in $allFiles) {
            $relPath = $file.FullName.Substring($tempDir.Length).TrimStart('\').Replace('\','/')
            $hash    = ""
            try { $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash } catch {}
            $manifestEntries += [PSCustomObject]@{
                relativePath = $relPath
                sha256       = $hash
                sizeBytes    = $file.Length
            }
        }

        $manifestJson = $manifestEntries | ConvertTo-Json -Depth 5
        Set-Content -Path (Join-Path $tempDir "manifest.json") -Value $manifestJson -Encoding UTF8

        $notesContent = if ($ReleaseNotes) { $ReleaseNotes } else { "No release notes provided." }
        Set-Content -Path (Join-Path $tempDir "release-notes.md") -Value $notesContent -Encoding UTF8

        $zipPath = Join-Path ([System.IO.Path]::GetTempPath()) "spgit-release-$Version.zip"
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

        Write-Host "Creating package.zip..." -ForegroundColor Cyan
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)

        Copy-Item -Path $zipPath -Destination (Join-Path $tempDir "package.zip") -Force

        $spFolder     = "$libraryName/$repoName/releases/$Version"
        $uploadFiles  = Get-ChildItem -Path $tempDir -File
        $fileCount    = 0

        Write-Host "Uploading release files to '$spFolder'..." -ForegroundColor Cyan
        foreach ($file in $uploadFiles) {
            try {
                Add-PnPFile -Path $file.FullName -Folder $spFolder | Out-Null
                Write-Host "  Uploaded: $($file.Name)" -ForegroundColor Green
                $fileCount++
            }
            catch {
                Write-Host "  ERROR uploading '$($file.Name)' -- $_" -ForegroundColor Red
            }
        }

        $allUploadFiles = Get-ChildItem -Path $tempDir -Recurse -File | Where-Object { $_.DirectoryName -ne $tempDir }
        foreach ($file in $allUploadFiles) {
            $relDir   = $file.DirectoryName.Substring($tempDir.Length).TrimStart('\').Replace('\','/')
            $spSubDir = "$spFolder/$relDir"
            try {
                Add-PnPFile -Path $file.FullName -Folder $spSubDir | Out-Null
                Write-Host "  Uploaded: $relDir/$($file.Name)" -ForegroundColor Green
                $fileCount++
            }
            catch {
                Write-Host "  ERROR uploading '$relDir/$($file.Name)' -- $_" -ForegroundColor Red
            }
        }

        Write-Host "Publish-SPGitRelease complete. Version: $Version, Files uploaded: $fileCount." -ForegroundColor Green
    }
    finally {
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
    }

    return $Version
    #endregion Main Logic *#
}
#endregion Functions *#
