param(
  [string]$OutFile = "C:\ProgramData\USBVideoVault\exec-dashboard.html",
  [int]   $LookbackHours = 48,
  [int]   $EveryMinutes = 15,
  [switch]$RunNow
)

$ErrorActionPreference = "Stop"

$ScriptPath = "C:\Users\patok\Documents\Yindo-USB-Video-Vault\scripts\next10\New-ExecDashboard.ps1"
$TaskName   = "USBVault-ExecDashboard"

Write-Host "USBVault Exec Dashboard scheduler" -ForegroundColor Cyan
Write-Host "Script   : $ScriptPath" -ForegroundColor Yellow
Write-Host "OutFile  : $OutFile" -ForegroundColor Yellow
Write-Host "Période  : $EveryMinutes min | Lookback: $LookbackHours h" -ForegroundColor Yellow

# Crée le dossier de sortie si besoin
$null = New-Item -ItemType Directory -Path (Split-Path $OutFile) -Force -ErrorAction SilentlyContinue

# Prépare les arguments pour la tâche
$argument = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -OutFile `"$OutFile`" -LookbackHours $LookbackHours"

# Déclare la tâche planifiée (SYSTEM, élevé) - approche XML directe
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>$(Get-Date -Format "yyyy-MM-ddTHH:mm:ss")</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay>
      <Repetition>
        <Interval>PT${EveryMinutes}M</Interval>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Enabled>true</Enabled>
    <ExecutionTimeLimit>PT30M</ExecutionTimeLimit>
  </Settings>
  <Actions>
    <Exec>
      <Command>pwsh.exe</Command>
      <Arguments>$argument</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# Création via XML
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$tempXml = "$env:TEMP\$TaskName.xml"
$taskXml | Out-File -Encoding Unicode $tempXml
schtasks /create /tn $TaskName /xml $tempXml /f | Out-Null
Remove-Item $tempXml -ErrorAction SilentlyContinue

Write-Host "Tache planifiee creee: $TaskName" -ForegroundColor Green

if ($RunNow) {
  Start-ScheduledTask -TaskName $TaskName
  Write-Host "Execution immediate declenchee" -ForegroundColor Green
}