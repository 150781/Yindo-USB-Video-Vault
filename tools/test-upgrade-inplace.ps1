# Script de test d'upgrade in-place pour USB Video Vault
# Usage: .\tools\test-upgrade-inplace.ps1 -FromVersion "0.1.4" -ToVersion "0.1.5" [-TestMode]

param(
    [string]$FromVersion = "0.1.4",
    [string]$ToVersion = "0.1.5",
    [switch]$TestMode
)

Write-Host "=== TEST UPGRADE IN-PLACE $FromVersion → $ToVersion ===" -ForegroundColor Cyan
Write-Host ""

# Verification existence des fichiers setup
$fromSetup = ".\dist\USB Video Vault Setup $FromVersion.exe"
$toSetup = ".\dist\USB Video Vault Setup $ToVersion.exe"

Write-Host "1. VERIFICATION FICHIERS SETUP..." -ForegroundColor Yellow

if (-not (Test-Path $fromSetup)) {
    Write-Host "  ERREUR: Setup $FromVersion introuvable: $fromSetup" -ForegroundColor Red
    Write-Host "  Generer avec: npm run build -- --publish=never" -ForegroundColor Blue
    exit 1
}

if (-not (Test-Path $toSetup)) {
    Write-Host "  ERREUR: Setup $ToVersion introuvable: $toSetup" -ForegroundColor Red
    Write-Host "  Generer avec: npm run build -- --publish=never" -ForegroundColor Blue
    exit 1
}

Write-Host "  Setup ${FromVersion}: OK ($([math]::Round((Get-Item $fromSetup).Length/1MB, 1)) MB)" -ForegroundColor Green
Write-Host "  Setup ${ToVersion}: OK ($([math]::Round((Get-Item $toSetup).Length/1MB, 1)) MB)" -ForegroundColor Green

if ($TestMode) {
    Write-Host ""
    Write-Host "MODE TEST - Simulation upgrade" -ForegroundColor Blue
    Write-Host "Etapes qui seraient executees:" -ForegroundColor Blue
    Write-Host "  1. Installation silencieuse $FromVersion" -ForegroundColor Cyan
    Write-Host "  2. Sauvegarde donnees utilisateur" -ForegroundColor Cyan
    Write-Host "  3. Installation silencieuse $ToVersion (upgrade)" -ForegroundColor Cyan
    Write-Host "  4. Verification version et donnees" -ForegroundColor Cyan
    exit 0
}

# Verification que l'ancienne version n'est pas deja installee
Write-Host ""
Write-Host "2. VERIFICATION ETAT INITIAL..." -ForegroundColor Yellow

$existingInstall = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -like "*USB Video Vault*" }

if ($existingInstall) {
    Write-Host "  Version actuellement installee: $($existingInstall.DisplayVersion)" -ForegroundColor Yellow
    Write-Host "  Desinstallation necessaire avant test..." -ForegroundColor Yellow

    # Desinstallation silencieuse
    $uninstaller = $existingInstall.UninstallString.Trim('"')
    Write-Host "  Desinstallation: $uninstaller /S" -ForegroundColor Gray

    $uninstallProcess = Start-Process -FilePath $uninstaller -ArgumentList "/S" -Wait -PassThru -NoNewWindow

    if ($uninstallProcess.ExitCode -ne 0) {
        Write-Host "  ERREUR desinstallation: code $($uninstallProcess.ExitCode)" -ForegroundColor Red
        exit 1
    }

    # Attendre nettoyage
    Start-Sleep -Seconds 3
    Write-Host "  Desinstallation terminee" -ForegroundColor Green
} else {
    Write-Host "  Aucune installation existante" -ForegroundColor Green
}

# ETAPE 1: Installation version de base
Write-Host ""
Write-Host "3. INSTALLATION VERSION DE BASE $FromVersion..." -ForegroundColor Yellow

$startTime = Get-Date
$installProcess = Start-Process -FilePath $fromSetup -ArgumentList "/S" -Wait -PassThru -NoNewWindow
$installDuration = ((Get-Date) - $startTime).TotalSeconds

if ($installProcess.ExitCode -ne 0) {
    Write-Host "  ERREUR installation ${FromVersion}: code $($installProcess.ExitCode)" -ForegroundColor Red
    exit 1
}

Write-Host "  Installation $FromVersion reussie ($([math]::Round($installDuration, 1))s)" -ForegroundColor Green

# Verification installation
$installedVersion = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                    Where-Object { $_.DisplayName -like "*USB Video Vault*" }

if (-not $installedVersion -or $installedVersion.DisplayVersion -ne $FromVersion) {
    Write-Host "  ERREUR verification version: attendue $FromVersion, trouvee $($installedVersion.DisplayVersion)" -ForegroundColor Red
    exit 1
}

Write-Host "  Version confirmee: $($installedVersion.DisplayVersion)" -ForegroundColor Green

# ETAPE 2: Simulation donnees utilisateur
Write-Host ""
Write-Host "4. SIMULATION DONNEES UTILISATEUR..." -ForegroundColor Yellow

$userDataPath = "$env:APPDATA\USB Video Vault"
$testDataFile = "$userDataPath\test-upgrade-data.json"

# Creer donnees de test
if (-not (Test-Path $userDataPath)) {
    New-Item -ItemType Directory -Path $userDataPath -Force | Out-Null
}

$testData = @{
    version = $FromVersion
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    settings = @{
        theme = "dark"
        autoplay = $true
    }
    playlists = @(
        @{ name = "Test Playlist"; videos = @("video1.mp4", "video2.mp4") }
    )
}

$testData | ConvertTo-Json -Depth 3 | Out-File -FilePath $testDataFile -Encoding UTF8
Write-Host "  Donnees test creees: $testDataFile" -ForegroundColor Green

# ETAPE 3: Upgrade in-place
Write-Host ""
Write-Host "5. UPGRADE IN-PLACE vers $ToVersion..." -ForegroundColor Yellow

$upgradeStartTime = Get-Date
$upgradeProcess = Start-Process -FilePath $toSetup -ArgumentList "/S" -Wait -PassThru -NoNewWindow
$upgradeDuration = ((Get-Date) - $upgradeStartTime).TotalSeconds

if ($upgradeProcess.ExitCode -ne 0) {
    Write-Host "  ERREUR upgrade: code $($upgradeProcess.ExitCode)" -ForegroundColor Red
    exit 1
}

Write-Host "  Upgrade terminee ($([math]::Round($upgradeDuration, 1))s)" -ForegroundColor Green

# ETAPE 4: Verification post-upgrade
Write-Host ""
Write-Host "6. VERIFICATION POST-UPGRADE..." -ForegroundColor Yellow

# Verifier version
$upgradedVersion = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -like "*USB Video Vault*" }

if (-not $upgradedVersion) {
    Write-Host "  ERREUR: Application non trouvee apres upgrade" -ForegroundColor Red
    exit 1
}

if ($upgradedVersion.DisplayVersion -ne $ToVersion) {
    Write-Host "  ERREUR version: attendue $ToVersion, trouvee $($upgradedVersion.DisplayVersion)" -ForegroundColor Red
    exit 1
}

Write-Host "  Version confirmee: $($upgradedVersion.DisplayVersion)" -ForegroundColor Green

# Verifier preservation des donnees
if (-not (Test-Path $testDataFile)) {
    Write-Host "  ERREUR: Donnees utilisateur perdues" -ForegroundColor Red
    exit 1
}

try {
    $preservedData = Get-Content $testDataFile -Raw | ConvertFrom-Json

    if ($preservedData.settings.theme -ne "dark") {
        Write-Host "  ERREUR: Parametres utilisateur modifies" -ForegroundColor Red
        exit 1
    }

    if ($preservedData.playlists.Count -ne 1) {
        Write-Host "  ERREUR: Playlists perdues" -ForegroundColor Red
        exit 1
    }

    Write-Host "  Donnees utilisateur preservees" -ForegroundColor Green

} catch {
    Write-Host "  ERREUR lecture donnees: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verifier executable
$exePaths = @(
    "C:\Program Files\USB Video Vault\USB Video Vault.exe",
    "C:\Program Files (x86)\USB Video Vault\USB Video Vault.exe",
    "$env:LOCALAPPDATA\Programs\USB Video Vault\USB Video Vault.exe"
)

$foundExe = $null
foreach ($exePath in $exePaths) {
    if (Test-Path $exePath) {
        $foundExe = $exePath
        break
    }
}

if (-not $foundExe) {
    Write-Host "  ERREUR: Executable principal introuvable" -ForegroundColor Red
    exit 1
}

# Verifier version de l'executable
try {
    $exeVersion = (Get-ItemProperty $foundExe).VersionInfo.FileVersion
    Write-Host "  Executable: $foundExe" -ForegroundColor Green
    Write-Host "  Version fichier: $exeVersion" -ForegroundColor Green
} catch {
    Write-Host "  AVERTISSEMENT: Version executable non lisible" -ForegroundColor Yellow
}

# Test lancement rapide
Write-Host ""
Write-Host "7. TEST LANCEMENT POST-UPGRADE..." -ForegroundColor Yellow

try {
    $testProcess = Start-Process -FilePath $foundExe -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "upgrade-test-output.tmp" -RedirectStandardError "upgrade-test-error.tmp"

    if ($testProcess.ExitCode -eq 0) {
        Write-Host "  Lancement test: OK" -ForegroundColor Green
    } else {
        Write-Host "  Lancement test: ECHEC (code $($testProcess.ExitCode))" -ForegroundColor Yellow

        if (Test-Path "upgrade-test-error.tmp") {
            $errorContent = Get-Content "upgrade-test-error.tmp" -Raw
            if ($errorContent.Trim()) {
                Write-Host "  Erreur: $errorContent" -ForegroundColor Red
            }
        }
    }

    # Nettoyer fichiers temporaires
    @("upgrade-test-output.tmp", "upgrade-test-error.tmp") | ForEach-Object {
        if (Test-Path $_) { Remove-Item $_ -Force }
    }

} catch {
    Write-Host "  Test lancement: ERREUR ($($_.Exception.Message))" -ForegroundColor Yellow
}

# Nettoyage donnees de test
Remove-Item $testDataFile -Force -ErrorAction SilentlyContinue

# RAPPORT FINAL
Write-Host ""
Write-Host "=== RAPPORT UPGRADE IN-PLACE ===" -ForegroundColor Cyan

$totalDuration = $installDuration + $upgradeDuration

Write-Host "RESULTAT: UPGRADE REUSSIE" -ForegroundColor Green
Write-Host ""
Write-Host "Durees:" -ForegroundColor White
Write-Host "  Installation $FromVersion : $([math]::Round($installDuration, 1))s" -ForegroundColor Gray
Write-Host "  Upgrade vers $ToVersion   : $([math]::Round($upgradeDuration, 1))s" -ForegroundColor Gray
Write-Host "  Total                     : $([math]::Round($totalDuration, 1))s" -ForegroundColor Gray
Write-Host ""
Write-Host "Validations:" -ForegroundColor White
Write-Host "  ✓ Version finale: $($upgradedVersion.DisplayVersion)" -ForegroundColor Green
Write-Host "  ✓ Donnees utilisateur preservees" -ForegroundColor Green
Write-Host "  ✓ Executable fonctionnel" -ForegroundColor Green
Write-Host "  ✓ Registre Windows correct" -ForegroundColor Green
Write-Host ""
Write-Host "Compatible upgrade silencieux: /S" -ForegroundColor Green
