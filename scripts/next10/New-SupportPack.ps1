param(
  [Parameter(Mandatory=$true)][string]$TicketNumber,
  [Parameter()][string]$UserEmail = "",
  [Parameter()][string]$ClientVersion = "",
  [Parameter()][string]$LogsPath = "$env:APPDATA\USB Video Vault\logs",
  [Parameter()][string]$OutDir = ".\out\support"
)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "Collecte du support pack pour ticket $TicketNumber..." -ForegroundColor Cyan

$packName="support-pack-$TicketNumber.zip"
$tempDir="$env:TEMP\support-$TicketNumber-$((Get-Date).Ticks)"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

# Metadonnées
@{
  ticketNumber=$TicketNumber;
  userEmail=$UserEmail;
  clientVersion=$ClientVersion;
  timestamp=(Get-Date);
  hostname=$env:COMPUTERNAME;
  username=$env:USERNAME
} | ConvertTo-Json -Depth 2 | Out-File -Encoding UTF8 "$tempDir\metadata.json"

# Diagnostics système
@{
  os=(Get-WmiObject Win32_OperatingSystem).Caption;
  arch=$env:PROCESSOR_ARCHITECTURE;
  totalRAM=[math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2);
  freeSpace=[math]::Round((Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace/1GB, 2)
} | ConvertTo-Json -Depth 2 | Out-File -Encoding UTF8 "$tempDir\system-info.json"

# Logs récents (dernières 48h max, première 1000 lignes)
if(Test-Path $LogsPath){
  $cut=(Get-Date).AddHours(-48)
  $logFiles = Get-ChildItem $LogsPath -Filter "*.log" -ErrorAction SilentlyContinue
  foreach($f in $logFiles){
    $lines = Get-Content $f -ErrorAction SilentlyContinue | Where-Object { ($_ -split '\s+')[0] -as [datetime] -ge $cut }
    if($lines){ $lines | Select-Object -First 1000 | Out-File -Encoding UTF8 "$tempDir\$($f.Name)" }
  }
}

# Licence courante (structure seulement, pas les clés)
$licPath = "$env:APPDATA\USB Video Vault\license.json"
if(Test-Path $licPath){
  $lic = Get-Content $licPath | ConvertFrom-Json -ErrorAction SilentlyContinue
  if($lic){
    @{
      licenseId=$lic.licenseId;
      issueDate=$lic.issueDate;
      validUntil=$lic.validUntil;
      tier=$lic.tier;
      structure=($lic | Get-Member -MemberType NoteProperty | Select-Object Name)
    } | ConvertTo-Json -Depth 3 | Out-File -Encoding UTF8 "$tempDir\license-structure.json"
  }
}

# Package
$outPath="$OutDir\$packName"
try {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $outPath)
  Remove-Item -Recurse -Force $tempDir
  Write-Host "Support pack créé: $outPath" -ForegroundColor Green
  exit 0
} catch {
  Write-Error "Erreur de packaging: $_"
  exit 1
}