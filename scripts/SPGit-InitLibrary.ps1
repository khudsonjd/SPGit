function Initialize-SPGitLibrary {
    param(
        [Parameter(Mandatory = $true)][string]$SiteUrl,
        [string]$LibraryName = "SPGit"
    )

    . "$PSScriptRoot\SPGit-Connect.ps1"
    Connect-SPGitSite -SiteUrl $SiteUrl

    # --- Create library ---
    try {
        $existing = Get-PnPList -Identity $LibraryName -ErrorAction SilentlyContinue
        if ($null -eq $existing) {
            Write-Host "Creating document library '$LibraryName'..." -ForegroundColor Cyan
            New-PnPList -Title $LibraryName -Template DocumentLibrary | Out-Null
            Write-Host "Library '$LibraryName' created." -ForegroundColor Green
        }
        else {
            Write-Host "Library '$LibraryName' already exists -- skipping creation." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "ERROR: Failed to create library '$LibraryName' -- $_" -ForegroundColor Red
        throw
    }

    # --- Enable versioning ---
    try {
        Write-Host "Enabling versioning on '$LibraryName'..." -ForegroundColor Cyan
        Set-PnPList -Identity $LibraryName -EnableVersioning $true -MajorVersions 50
        Write-Host "Versioning enabled (50 major versions)." -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to set versioning -- $_" -ForegroundColor Red
        throw
    }

    # --- Column definitions ---
    $columns = @(
        @{ Name = "RepoName";         Type = "Text";     Choices = $null }
        @{ Name = "RepoRole";         Type = "Choice";   Choices = @("Root","Main","Dev","Release","Memory","Metadata") }
        @{ Name = "ArtifactType";     Type = "Choice";   Choices = @("MCPServer","Subagent","Script","Documentation","Config","Prompt","Template","ReleasePackage") }
        @{ Name = "VersionLabel";     Type = "Text";     Choices = $null }
        @{ Name = "CommitId";         Type = "Text";     Choices = $null }
        @{ Name = "CommitMessage";    Type = "Note";     Choices = $null }
        @{ Name = "CommitAuthor";     Type = "Text";     Choices = $null }
        @{ Name = "CommitDate";       Type = "DateTime"; Choices = $null }
        @{ Name = "LocalHash";        Type = "Text";     Choices = $null }
        @{ Name = "RemoteHash";       Type = "Text";     Choices = $null }
        @{ Name = "LockOwner";        Type = "Text";     Choices = $null }
        @{ Name = "LockExpires";      Type = "DateTime"; Choices = $null }
        @{ Name = "ApprovalState";    Type = "Choice";   Choices = @("Draft","Proposed","Approved","Deprecated","Archived") }
        @{ Name = "PublishedRelease"; Type = "Boolean";  Choices = $null }
    )

    foreach ($col in $columns) {
        $colName = $col.Name
        try {
            $existing = Get-PnPField -List $LibraryName -Identity $colName -ErrorAction SilentlyContinue
            if ($null -ne $existing) {
                Write-Host "Column '$colName' already exists -- skipping." -ForegroundColor Yellow
                continue
            }

            Write-Host "Adding column '$colName' ($($col.Type))..." -ForegroundColor Cyan

            switch ($col.Type) {
                "Text"     { Add-PnPField -List $LibraryName -DisplayName $colName -InternalName $colName -Type Text     -AddToDefaultView:$false | Out-Null }
                "Note"     { Add-PnPField -List $LibraryName -DisplayName $colName -InternalName $colName -Type Note     -AddToDefaultView:$false | Out-Null }
                "DateTime" { Add-PnPField -List $LibraryName -DisplayName $colName -InternalName $colName -Type DateTime -AddToDefaultView:$false | Out-Null }
                "Boolean"  { Add-PnPField -List $LibraryName -DisplayName $colName -InternalName $colName -Type Boolean  -AddToDefaultView:$false | Out-Null }
                "Choice"   { Add-PnPField -List $LibraryName -DisplayName $colName -InternalName $colName -Type Choice -Choices $col.Choices -AddToDefaultView:$false | Out-Null }
            }

            Write-Host "Column '$colName' added." -ForegroundColor Green
        }
        catch {
            Write-Host "ERROR: Failed to add column '$colName' -- $_" -ForegroundColor Red
        }
    }

    # --- Create default view ---
    try {
        $viewName = "SPGit Default"
        $existingView = Get-PnPView -List $LibraryName -Identity $viewName -ErrorAction SilentlyContinue
        if ($null -ne $existingView) {
            Write-Host "View '$viewName' already exists -- skipping." -ForegroundColor Yellow
        }
        else {
            Write-Host "Creating view '$viewName'..." -ForegroundColor Cyan
            $viewFields = @("FileLeafRef","RepoName","ArtifactType","VersionLabel","ApprovalState","CommitDate")
            Add-PnPView -List $LibraryName -Title $viewName -Fields $viewFields -SetAsDefault:$false | Out-Null
            Write-Host "View '$viewName' created." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "ERROR: Failed to create view -- $_" -ForegroundColor Red
    }

    Write-Host "Initialize-SPGitLibrary complete." -ForegroundColor Green
}
