# Post-Install Client - USB Video Vault
# Deploiement automatise de licence avec verification logs

param(
    [string]$VaultPath = $env:VAULT_PATH,
    [string]$LicenseSource = ".\out\license.bin", 
    [string]$Exe = "C:\Program Files\USB Video Vault\USB Video Vault.exe",
    [switch]$Verbose = $false,
    [int]$TimeoutSeconds = 5
)

# Configuration par defaut
if (-not $VaultPath) { 
    $VaultPath = Join-Path $env:USERPROFILE "Documents\Yindo-USB-Video-Vault\vault-real" 
}

function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    $timestamp = Get-Date -Format "HH:mm:ss"
    switch ($Type) {
        "Success" { Write-Host "[$timestamp] OK $Message" -ForegroundColor Green }
        "Error"   { Write-Host "[$timestamp] ERROR $Message" -ForegroundColor Red }
        "Warning" { Write-Host "[$timestamp] WARN $Message" -ForegroundColor Yellow }
        "Info"    { Write-Host "[$timestamp] INFO $Message" -ForegroundColor Cyan }
        default   { Write-Host "[$timestamp] $Message" }
    }
}

Write-Status "POST-INSTALL CLIENT - USB Video Vault" "Info"
Write-Status "==========================================" "Info"

# 1. Verifications prealables
Write-Status "Verification des prerequis..." "Info"

if (-not (Test-Path $LicenseSource)) {
    Write-Status "Fichier licence manquant: $LicenseSource" "Error"
    exit 1
}

$licenseSize = (Get-Item $LicenseSource).Length
if ($licenseSize -lt 100) {
    Write-Status "Fichier licence trop petit ($licenseSize octets) - corruption possible" "Warning"
}

if ($Exe -and -not (Test-Path $Exe)) {
    Write-Status "Executable non trouve: $Exe (installation manuelle requise)" "Warning"
}

Write-Status "Prerequis OK" "Success"

# 2. Installation licence
Write-Status "Installation de la licence..." "Info"
$dotVault = Join-Path $VaultPath ".vault"
New-Item -ItemType Directory -Force -Path $dotVault | Out-Null
Write-Status "Dossier vault: $dotVault" "Info"

$licenseTarget = Join-Path $dotVault "license.bin"
Copy-Item $LicenseSource $licenseTarget -Force

if (Test-Path $licenseTarget) {
    $targetSize = (Get-Item $licenseTarget).Length
    Write-Status "Licence installee: $licenseTarget ($targetSize octets)" "Success"
} else {
    Write-Status "Echec installation licence" "Error"
    exit 1
}

# 3. Demarrage application
Write-Status "Demarrage de l'application..." "Info"
$process = $null

if ($Exe -and (Test-Path $Exe)) {
    try {
        $process = Start-Process $Exe -PassThru -WindowStyle Minimized
        Write-Status "Application demarree (PID: $($process.Id))" "Success"
    } catch {
        Write-Status "Erreur demarrage: $($_.Exception.Message)" "Error"
    }
} else {
    Write-Status "Application non trouvee - demarrage manuel requis" "Warning"
}

# 4. Attendre logs
Write-Status "Attente logs ($TimeoutSeconds secondes)..." "Info"
Start-Sleep $TimeoutSeconds

# 5. Verification validation
Write-Status "Verification validation licence..." "Info"

$logPaths = @(
    (Join-Path $env:APPDATA "USB Video Vault\logs\main.log"),
    (Join-Path $env:LOCALAPPDATA "USB Video Vault\logs\main.log")
)

$validationSuccess = $false
$logFound = $false

foreach ($logPath in $logPaths) {
    if (Test-Path $logPath) {
        $logFound = $true
        Write-Status "Log trouve: $logPath" "Info"
        
        # Rechercher validation reussie
        $validationOK = Select-String -Path $logPath -Pattern "Licence validee" -SimpleMatch -Quiet
        $licenseOK = Select-String -Path $logPath -Pattern "LICENSE.*OK" -SimpleMatch -Quiet
        
        if ($validationOK -or $licenseOK) {
            Write-Status "LICENCE VALIDEE AVEC SUCCES" "Success"
            $validationSuccess = $true
            break
        } else {
            # Rechercher erreurs specifiques
            $errorPatterns = @(
                @{Pattern = "Invalid signature"; Message = "Signature invalide - licence corrompue"},
                @{Pattern = "Machine binding failed"; Message = "Machine differente - regenerer licence"},
                @{Pattern = "License expired"; Message = "Licence expiree - renouvellement requis"},
                @{Pattern = "License file not found"; Message = "Fichier licence non trouve"},
                @{Pattern = "Rollback attempt"; Message = "Tentative de rollback detectee"}
            )
            
            foreach ($errorItem in $errorPatterns) {
                if (Select-String -Path $logPath -Pattern $errorItem.Pattern -SimpleMatch -Quiet) {
                    Write-Status $errorItem.Message "Error"
                    break
                }
            }
        }
        break
    }
}

if (-not $logFound) {
    Write-Status "Aucun log trouve - application pas demarree?" "Warning"
}

# 6. Resume final
Write-Status "==========================================" "Info"
Write-Status "RESUME INSTALLATION LICENCE" "Info"
Write-Status "==========================================" "Info"
Write-Status "Vault: $VaultPath" "Info"
Write-Status "Source: $LicenseSource" "Info"

if ($validationSuccess) {
    Write-Status "INSTALLATION REUSSIE" "Success"
    Write-Status "La licence est validee et operationnelle" "Success"
    exit 0
} else {
    Write-Status "PROBLEME DETECTE" "Error"
    Write-Status "Actions recommandees:" "Info"
    Write-Status "1. Verifier empreinte machine avec scripts/print-bindings.mjs" "Info"
    Write-Status "2. Regenerer licence si machine differente" "Info"
    Write-Status "3. Contacter support avec logs detailles" "Info"
    exit 2
}