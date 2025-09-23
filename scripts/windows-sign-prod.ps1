# Script de Signature Production Windows
# USB Video Vault - Signature avec certificat production

param(
    [Parameter(Mandatory=$false)]
    [string]$PfxPath = "C:\keys\codesign-prod.pfx",
    
    [Parameter(Mandatory=$false)]
    [SecureString]$PfxPassword,
    
    [Parameter(Mandatory=$false)]
    [string]$ExecutablePath = "dist\win-unpacked\USB Video Vault.exe",
    
    [Parameter(Mandatory=$false)]
    [string]$TimestampServer = "http://timestamp.digicert.com",
    
    [Parameter(Mandatory=$false)]
    [switch]$ImportOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$SignOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$VerifyOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Vérification des prérequis..." "INFO"
    
    # Vérifier signtool
    try {
        $null = Get-Command signtool -ErrorAction Stop
        Write-Log "✓ signtool disponible" "SUCCESS"
    }
    catch {
        Write-Log "❌ signtool non trouvé. Installez Windows SDK" "ERROR"
        throw
    }
    
    # Vérifier certutil
    try {
        $null = Get-Command certutil -ErrorAction Stop
        Write-Log "✓ certutil disponible" "SUCCESS"
    }
    catch {
        Write-Log "❌ certutil non trouvé" "ERROR"
        throw
    }
    
    Write-Log "Prérequis validés" "SUCCESS"
}

function Import-ProductionCertificate {
    param([string]$PfxPath, [SecureString]$Password)
    
    Write-Log "Import du certificat production..." "INFO"
    
    if (-not (Test-Path $PfxPath)) {
        Write-Log "❌ Certificat PFX non trouvé: $PfxPath" "ERROR"
        throw "Certificat non trouvé"
    }
    
    if ($null -eq $Password) {
        $Password = Read-Host -Prompt "Mot de passe du certificat PFX" -AsSecureString
    }
    
    # Conversion SecureString pour certutil
    $passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
    
    try {
        # Import avec certutil
        $importCmd = "certutil -f -p `"$passwordPlain`" -importpfx `"$PfxPath`" NoRoot"
        
        if ($Verbose) {
            Write-Log "Commande d'import: $importCmd" "INFO"
        }
        
        $result = Invoke-Expression $importCmd 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Certificat importé avec succès" "SUCCESS"
        } else {
            Write-Log "❌ Échec import certificat: $result" "ERROR"
            throw "Import échoué"
        }
        
        # Vérifier certificats disponibles
        $certs = certutil -store my | Select-String "Nom du sujet"
        if ($Verbose -and $certs) {
            Write-Log "Certificats installés:" "INFO"
            $certs | ForEach-Object { Write-Log "  $_" "INFO" }
        }
        
    }
    catch {
        Write-Log "❌ Erreur lors de l'import: $_" "ERROR"
        throw
    }
}

function Invoke-ExecutableSigning {
    param([string]$ExecutablePath, [string]$TimestampServer)
    
    Write-Log "Signature de l'exécutable..." "INFO"
    
    if (-not (Test-Path $ExecutablePath)) {
        Write-Log "❌ Exécutable non trouvé: $ExecutablePath" "ERROR"
        throw "Exécutable non trouvé"
    }
    
    try {
        # Commande de signature
        $signCmd = "signtool sign /fd SHA256 /tr $TimestampServer /td SHA256 /a `"$ExecutablePath`""
        
        if ($Verbose) {
            Write-Log "Commande de signature: $signCmd" "INFO"
        }
        
        $result = Invoke-Expression $signCmd 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Signature réussie" "SUCCESS"
            
            # Afficher détails de signature
            if ($Verbose) {
                Write-Log "Détails de la signature:" "INFO"
                Write-Log $result "INFO"
            }
        } else {
            Write-Log "❌ Échec signature: $result" "ERROR"
            throw "Signature échouée"
        }
        
    }
    catch {
        Write-Log "❌ Erreur lors de la signature: $_" "ERROR"
        throw
    }
}

function Test-SignatureValidity {
    param([string]$ExecutablePath)
    
    Write-Log "Vérification de la signature..." "INFO"
    
    if (-not (Test-Path $ExecutablePath)) {
        Write-Log "❌ Exécutable non trouvé: $ExecutablePath" "ERROR"
        throw "Exécutable non trouvé"
    }
    
    try {
        # Vérification de la signature
        $verifyCmd = "signtool verify /pa /all `"$ExecutablePath`""
        
        if ($Verbose) {
            Write-Log "Commande de vérification: $verifyCmd" "INFO"
        }
        
        $result = Invoke-Expression $verifyCmd 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Signature valide" "SUCCESS"
            
            if ($Verbose) {
                Write-Log "Détails de vérification:" "INFO"
                Write-Log $result "INFO"
            }
            
            # Informations supplémentaires
            $signInfo = Get-AuthenticodeSignature $ExecutablePath
            Write-Log "Status: $($signInfo.Status)" "INFO"
            Write-Log "Certificat: $($signInfo.SignerCertificate.Subject)" "INFO"
            Write-Log "Timestamp: $($signInfo.TimeStamperCertificate.NotAfter)" "INFO"
            
        } else {
            Write-Log "❌ Signature invalide: $result" "ERROR"
            throw "Vérification échouée"
        }
        
    }
    catch {
        Write-Log "❌ Erreur lors de la vérification: $_" "ERROR"
        throw
    }
}

function Get-SignatureInfo {
    param([string]$ExecutablePath)
    
    Write-Log "Informations de signature:" "INFO"
    
    try {
        $signInfo = Get-AuthenticodeSignature $ExecutablePath
        
        $info = @{
            Path = $ExecutablePath
            Status = $signInfo.Status
            StatusMessage = $signInfo.StatusMessage
            SignerCertificate = $signInfo.SignerCertificate.Subject
            SignerThumbprint = $signInfo.SignerCertificate.Thumbprint
            TimestamperCertificate = $signInfo.TimeStamperCertificate.Subject
            TimestampExpiry = $signInfo.TimeStamperCertificate.NotAfter
        }
        
        return $info
    }
    catch {
        Write-Log "❌ Impossible d'obtenir les informations: $_" "ERROR"
        return $null
    }
}

function New-SigningReport {
    param([string]$ExecutablePath)
    
    $reportPath = "build\signing-report-prod-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    
    # Créer répertoire si nécessaire
    $buildDir = Split-Path $reportPath -Parent
    if (-not (Test-Path $buildDir)) {
        New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
    }
    
    try {
        $info = Get-SignatureInfo $ExecutablePath
        $signDetails = signtool verify /v /pa /all $ExecutablePath 2>&1
        
        $report = @"
USB Video Vault - Rapport de Signature Production
==============================================
Date: $(Get-Date)
Fichier: $ExecutablePath
Certificat: $(if($info) { $info.SignerCertificate } else { "Non disponible" })
Status: $(if($info) { $info.Status } else { "Non disponible" })

Détails techniques:
$signDetails

Machine: $env:COMPUTERNAME
Utilisateur: $env:USERNAME
PowerShell: $($PSVersionTable.PSVersion)
"@
        
        $report | Out-File -FilePath $reportPath -Encoding UTF8
        Write-Log "Rapport sauvegardé: $reportPath" "SUCCESS"
        
    }
    catch {
        Write-Log "❌ Erreur création rapport: $_" "ERROR"
    }
}

# Fonction principale
function Main {
    Write-Log "=== Signature Production Windows - USB Video Vault ===" "INFO"
    
    try {
        Test-Prerequisites
        
        # Mode import seul
        if ($ImportOnly) {
            Import-ProductionCertificate -PfxPath $PfxPath -Password $PfxPassword
            Write-Log "Import terminé" "SUCCESS"
            return
        }
        
        # Mode signature seule
        if ($SignOnly) {
            Invoke-ExecutableSigning -ExecutablePath $ExecutablePath -TimestampServer $TimestampServer
            Test-SignatureValidity -ExecutablePath $ExecutablePath
            New-SigningReport -ExecutablePath $ExecutablePath
            Write-Log "Signature terminée" "SUCCESS"
            return
        }
        
        # Mode vérification seule
        if ($VerifyOnly) {
            Test-SignatureValidity -ExecutablePath $ExecutablePath
            $info = Get-SignatureInfo -ExecutablePath $ExecutablePath
            if ($info) {
                $info | Format-Table -AutoSize
            }
            Write-Log "Vérification terminée" "SUCCESS"
            return
        }
        
        # Processus complet
        Write-Log "Processus complet: Import + Signature + Vérification" "INFO"
        
        # 1. Import du certificat
        Import-ProductionCertificate -PfxPath $PfxPath -Password $PfxPassword
        
        # 2. Signature
        Invoke-ExecutableSigning -ExecutablePath $ExecutablePath -TimestampServer $TimestampServer
        
        # 3. Vérification
        Test-SignatureValidity -ExecutablePath $ExecutablePath
        
        # 4. Rapport
        New-SigningReport -ExecutablePath $ExecutablePath
        
        Write-Log "🎉 Signature production terminée avec succès!" "SUCCESS"
        
        # Afficher informations finales
        $info = Get-SignatureInfo -ExecutablePath $ExecutablePath
        if ($info) {
            Write-Log "=== Informations finales ===" "INFO"
            Write-Log "Fichier: $($info.Path)" "INFO"
            Write-Log "Status: $($info.Status)" "INFO" 
            Write-Log "Certificat: $($info.SignerCertificate)" "INFO"
            Write-Log "Expiration timestamp: $($info.TimestampExpiry)" "INFO"
        }
        
    }
    catch {
        Write-Log "❌ Erreur critique: $_" "ERROR"
        exit 1
    }
}

# Exécution
Main