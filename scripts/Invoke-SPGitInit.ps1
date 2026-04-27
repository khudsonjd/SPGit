# ============================================================
# Invoke-SPGitInit.ps1
# Version:     1.1.0
# Date:        2026-04-27
# Description: Entry-point script that initializes the SPGit document library on SharePoint.
#              Run this once per site to create the library, columns, and default view.
# Usage:       .\Invoke-SPGitInit.ps1 -SiteUrl "https://yourtenant.sharepoint.com/sites/yoursite"
# ============================================================
param(
    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,

    [string]$LibraryName = "SPGit"
)

#region Initialization *#
. "$PSScriptRoot\SPGit-Connect.ps1"
. "$PSScriptRoot\SPGit-InitLibrary.ps1"
#endregion Initialization *#

#region Main Logic *#
Initialize-SPGitLibrary -SiteUrl $SiteUrl -LibraryName $LibraryName
#endregion Main Logic *#
