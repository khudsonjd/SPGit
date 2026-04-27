function Connect-SPGitSite {
    param(
        [Parameter(Mandatory = $true)][string]$SiteUrl
    )

    try {
        $prev = $WarningPreference
        $WarningPreference = 'SilentlyContinue'
        Connect-PnPOnline -Url $SiteUrl -UseWebLogin
        $WarningPreference = $prev
    }
    catch {
        $WarningPreference = $prev
        Write-Host "ERROR: Failed to connect to $SiteUrl -- $_" -ForegroundColor Red
        throw
    }

    try {
        $web = Get-PnPWeb
        Write-Host "Connected to site: $($web.Title)" -ForegroundColor Green
        return $web
    }
    catch {
        Write-Host "ERROR: Connection succeeded but Get-PnPWeb failed -- $_" -ForegroundColor Red
        throw
    }
}
