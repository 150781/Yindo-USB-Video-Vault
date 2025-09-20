# 🚀 Post-Install Client - Déploiement et Vérification Licence
# 
# Usage:
#   .\post-install-client.ps1 
#   .\post-install-client.ps1 -VaultPath "C:\Custom\Vault" -LicenseSource ".\license.bin"
#   .\post-install-client.ps1 -Exe "C:\Program Files\USB Video Vault\USB Video Vault.exe"

param(
    [string]$VaultPath = $env:VAULT_PATH,
    [string]$LicenseSource = ".\out\license.bin", 
    [string]$Exe = "C:\Program Files\USB Video Vault\USB Video Vault.exe",
    [switch]$Verbose = $false,
    [switch]$WaitForExit = $false,
    [int]$TimeoutSeconds = 10
)

# Configuration par défaut si pas spécifiée
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

function Test-Prerequisites {
    Write-Status "Vérification des prérequis..." "Info"
    
    # Vérifier fichier licence source
    if (-not (Test-Path $LicenseSource)) {
        Write-Status "Fichier licence manquant: $LicenseSource" "Error"
        return $false
    }
    
    # Verifier taille licence (doit etre > 100 chars pour license.bin)
    $licenseSize = (Get-Item $LicenseSource).Length
    if ($licenseSize -lt 100) {
        Write-Status "Fichier licence trop petit ($licenseSize octets) - corruption possible" "Warning"
    }
    
    # Vérifier exécutable (optionnel)
    if ($Exe -and -not (Test-Path $Exe)) {
        Write-Status "Exécutable non trouvé: $Exe (installation manuelle requise)" "Warning"
    }
    
    Write-Status "Prérequis OK" "Success"
    return $true
}

function Install-License {
    Write-Status "Installation de la licence..." "Info"
    
    # Créer dossier .vault
    $dotVault = Join-Path $VaultPath ".vault"
    New-Item -ItemType Directory -Force -Path $dotVault | Out-Null
    Write-Status "Dossier vault: $dotVault" "Info"
    
    # Copier licence
    $licenseTarget = Join-Path $dotVault "license.bin"
    Copy-Item $LicenseSource $licenseTarget -Force
    
    # Vérifier copie
    if (Test-Path $licenseTarget) {
        $sourceSize = (Get-Item $LicenseSource).Length
        $targetSize = (Get-Item $licenseTarget).Length
        
        if ($sourceSize -eq $targetSize) {
            Write-Status "Licence installee: $licenseTarget ($targetSize octets)" "Success"
            return $true
        } else {
            Write-Status "Erreur copie: tailles differentes (source: $sourceSize, target: $targetSize)" "Error"
            return $false
        }
    } else {
        Write-Status "Échec installation licence" "Error"
        return $false
    }
}

function Start-Application {
    Write-Status "Démarrage de l'application..." "Info"
    
    if (-not $Exe -or -not (Test-Path $Exe)) {
        Write-Status "Application non trouvée - démarrage manuel requis" "Warning"
        return $null
    }
    
    try {
        $proc = Start-Process $Exe -PassThru -WindowStyle Minimized
        Write-Status "Application démarrée (PID: $($proc.Id))" "Success"
        return $proc
    } catch {
        Write-Status "Erreur démarrage: $($_.Exception.Message)" "Error"
        return $null
    }
}

function Wait-ForLogs {
    param([int]$WaitSeconds = 5)
    
    Write-Status "Attente logs ($WaitSeconds secondes)..." "Info"
    Start-Sleep $WaitSeconds
}

function Test-LicenseValidation {
    Write-Status "Vérification validation licence..." "Info"
    
    # Chemins logs possibles
    $logPaths = @(
        (Join-Path $env:APPDATA "USB Video Vault\logs\main.log"),
        (Join-Path $env:LOCALAPPDATA "USB Video Vault\logs\main.log"),
        (Join-Path $VaultPath "logs\main.log"),
        ".\logs\main.log"
    )
    
    $logFound = $false
    foreach ($logPath in $logPaths) {
        if (Test-Path $logPath) {
            Write-Status "Log trouvé: $logPath" "Info"
            $logFound = $true
            
            # Rechercher validation réussie
            $validationOK = Select-String -Path $logPath -Pattern "Licence validée" -SimpleMatch -Quiet
            $licenseLoaded = Select-String -Path $logPath -Pattern "LICENSE.*✅" -SimpleMatch -Quiet
            
            if ($validationOK -or $licenseLoaded) {
                Write-Status "✅ LICENCE VALIDÉE AVEC SUCCÈS" "Success"
                
                if ($Verbose) {
                    Write-Status "Dernières lignes du log:" "Info"
                    Get-Content $logPath -Tail 10 | ForEach-Object { Write-Host "   $_" }
                }
                return $true
            } else {
                # Rechercher erreurs spécifiques
                $errorPatterns = @(
                    @{Pattern = "Invalid signature"; Message = "Signature invalide - licence corrompue ou falsifiée"},
                    @{Pattern = "Machine binding failed"; Message = "Machine différente - nouvelle empreinte requise"},
                    @{Pattern = "License expired"; Message = "Licence expirée - renouvellement requis"},
                    @{Pattern = "License file not found"; Message = "Fichier licence non trouvé"},
                    @{Pattern = "Rollback attempt"; Message = "Tentative de rollback détectée"}
                )
                
                foreach ($errorItem in $errorPatterns) {
                    if (Select-String -Path $logPath -Pattern $errorItem.Pattern -SimpleMatch -Quiet) {
                        Write-Status $errorItem.Message "Error"
                        return $false
                    }
                }
                
                Write-Status "Licence non validée - vérifier logs détaillés" "Warning"
                if ($Verbose) {
                    Write-Status "Dernières lignes du log:" "Info"
                    Get-Content $logPath -Tail 20 | ForEach-Object { Write-Host "   $_" }
                }
                return $false
            }
        }
    }
    
    if (-not $logFound) {
        Write-Status "Aucun fichier log trouvé - application peut-être pas démarrée" "Warning"
        return $false
    }
}

function Show-Summary {
    param([bool]$Success, [object]$Process)
    
    Write-Status "===========================================" "Info"
    Write-Status "RÉSUMÉ INSTALLATION LICENCE" "Info"
    Write-Status "===========================================" "Info"
    Write-Status "Vault: $VaultPath" "Info"
    Write-Status "Source: $LicenseSource" "Info"
    if ($Process) {
        Write-Status "Application: Démarrée (PID: $($Process.Id))" "Info"
    }
    
    if ($Success) {
        Write-Status "✅ INSTALLATION RÉUSSIE" "Success"
        Write-Status "La licence est validée et opérationnelle" "Success"
    } else {
        Write-Status "❌ PROBLÈME DÉTECTÉ" "Error"
        Write-Status "Actions recommandées:" "Info"
        Write-Status "1. Vérifier empreinte machine avec scripts/print-bindings.mjs" "Info"
        Write-Status "2. Regénérer licence si machine différente" "Info"
        Write-Status "3. Contacter support avec logs détaillés" "Info"
    }
    Write-Status "===========================================" "Info"
}

# Exécution principale
try {
    Write-Status "🚀 POST-INSTALL CLIENT - USB Video Vault" "Info"
    Write-Status "===========================================" "Info"
    
    # Vérifications préalables
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    # Installation licence
    if (-not (Install-License)) {
        Write-Status "Échec installation licence" "Error"
        exit 1
    }
    
    # Démarrage application
    $process = Start-Application
    
    # Attendre logs
    Wait-ForLogs -WaitSeconds $TimeoutSeconds
    
    # Vérification validation
    $validationSuccess = Test-LicenseValidation
    
    # Attendre fermeture si demandé
    if ($WaitForExit -and $process) {
        Write-Status "Attente fermeture application..." "Info"
        $process.WaitForExit()
    }
    
    # Résumé
    Show-Summary -Success $validationSuccess -Process $process
    
    # Code de sortie
    if ($validationSuccess) {
        exit 0
    } else {
        exit 2
    }
    
} catch {
    Write-Status "Erreur fatale: $($_.Exception.Message)" "Error"
    exit 1
}