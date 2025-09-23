param(
  [Parameter()][string]$OutDir = ".\out\diag"
)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$diag = [pscustomobject]@{
  collectedAt = Get-Date
  computer = $env:COMPUTERNAME
  user = $env:USERNAME
  os = (Get-CimInstance Win32_OperatingSystem).Caption
  version = (Get-Item "C:\Program Files\USB Video Vault\USB Video Vault.exe" -ErrorAction SilentlyContinue).VersionInfo.FileVersion
  vaultPath = $env:VAULT_PATH
}
$base = Join-Path $OutDir ("diag-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$work = New-Item -ItemType Directory -Force -Path $base
$diag | ConvertTo-Json -Depth 3 | Out-File "$work\system.json" -Encoding UTF8

# Licence présente ?
$lic = Join-Path $env:USERPROFILE "Documents\Yindo-USB-Video-Vault\vault-real\.vault\license.bin"
if(Test-Path $lic){ Copy-Item $lic "$work\license.bin" -Force }

# Logs
$logDir = "$env:APPDATA\USB Video Vault\logs"
if(Test-Path $logDir){
  Get-ChildItem $logDir -Filter "main*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 3 | ForEach-Object {
    Copy-Item $_.FullName "$work\$($_.Name)" -Force
  }
}

# Zip
$zip = "$base.zip"
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($work.FullName, $zip)
Remove-Item $work -Recurse -Force
Write-Host "Diagnostic créé → $zip" -ForegroundColor Green
exit 0