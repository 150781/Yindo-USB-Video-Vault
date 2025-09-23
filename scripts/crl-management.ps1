# CRL Management Tools - USB Video Vault
# Outils de gestion des révocations de licences

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("revoke", "restore", "list", "status", "create", "export")]
    [string]$Action,
    
    [string]$LicenseId,
    [string]$Kid,
    [ValidateSet("suspected_compromise", "unauthorized_use", "license_abuse", "administrative", "superseded")]
    [string]$Reason,
    [string]$Description,
    [string]$Serial,
    [string]$CrlPath = ".\crl\revoked-licenses.json",
    [string]$PrivateKeyPath = ".\keys\crl-private.pem",
    [string]$PublicKeyPath = ".\keys\crl-public.pem",
    [string]$OutputPath,
    [switch]$Force,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Vérification prérequis..." "INFO"
    
    # Vérifier Node.js
    try {
        $nodeVersion = & node --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Node.js détecté: $nodeVersion" "SUCCESS"
        } else {
            throw "Node.js non trouvé"
        }
    } catch {
        Write-Log "Node.js requis pour les outils CRL" "ERROR"
        throw "Installez Node.js depuis https://nodejs.org/"
    }
    
    # Créer dossiers si nécessaires
    $crlDir = Split-Path $CrlPath -Parent
    if (-not (Test-Path $crlDir)) {
        New-Item -Path $crlDir -ItemType Directory -Force | Out-Null
        Write-Log "Dossier CRL créé: $crlDir" "INFO"
    }
    
    $keysDir = Split-Path $PrivateKeyPath -Parent
    if (-not (Test-Path $keysDir)) {
        New-Item -Path $keysDir -ItemType Directory -Force | Out-Null
        Write-Log "Dossier clés créé: $keysDir" "INFO"
    }
}

function New-CRLKeys {
    Write-Log "Génération des clés CRL..." "INFO"
    
    if ((Test-Path $PrivateKeyPath) -and -not $Force) {
        Write-Log "Clés existantes trouvées. Utilisez -Force pour forcer la régénération." "WARNING"
        return
    }
    
    try {
        # Générer clé privée
        $opensslCmd = "openssl genpkey -algorithm RSA -out `"$PrivateKeyPath`" -pkcs8 -aes256"
        Write-Log "Génération clé privée..." "INFO"
        if ($Verbose) { Write-Log "Commande: $opensslCmd" "INFO" }
        
        Invoke-Expression $opensslCmd
        
        # Extraire clé publique
        $pubKeyCmd = "openssl rsa -in `"$PrivateKeyPath`" -pubout -out `"$PublicKeyPath`""
        Write-Log "Extraction clé publique..." "INFO"
        if ($Verbose) { Write-Log "Commande: $pubKeyCmd" "INFO" }
        
        Invoke-Expression $pubKeyCmd
        
        Write-Log "Clés CRL générées avec succès" "SUCCESS"
        Write-Log "Clé privée: $PrivateKeyPath" "INFO"
        Write-Log "Clé publique: $PublicKeyPath" "INFO"
        
    } catch {
        Write-Log "Erreur génération clés: $($_.Exception.Message)" "ERROR"
        Write-Log "OpenSSL requis. Installez depuis: https://slproweb.com/products/Win32OpenSSL.html" "INFO"
        throw
    }
}

function Initialize-CRL {
    Write-Log "Initialisation CRL..." "INFO"
    
    if ((Test-Path $CrlPath) -and -not $Force) {
        Write-Log "CRL existante trouvée: $CrlPath" "WARNING"
        return
    }
    
    # Vérifier les clés
    if (-not (Test-Path $PublicKeyPath)) {
        Write-Log "Clé publique non trouvée. Génération des clés..." "INFO"
        New-CRLKeys
    }
    
    # Créer CRL vide
    $emptyCrl = @{
        version = "1.0"
        issuer = "USB Video Vault CRL Authority"
        issuedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        nextUpdate = (Get-Date).AddHours(24).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        revokedLicenses = @()
    }
    
    # Sauvegarder CRL
    $crlJson = $emptyCrl | ConvertTo-Json -Depth 10
    Set-Content -Path $CrlPath -Value $crlJson -Encoding UTF8
    
    Write-Log "CRL initialisée: $CrlPath" "SUCCESS"
}

function Invoke-CRLAction {
    param([string]$NodeAction, [hashtable]$Parameters = @{})
    
    $crlScript = @"
const CRLManager = require('./src/main/crlManager.ts').default;
const fs = require('fs');

async function main() {
    const config = {
        crlPath: '$CrlPath',
        privateKeyPath: '$PrivateKeyPath',
        publicKeyPath: '$PublicKeyPath',
        updateIntervalHours: 24,
        maxAge: 72
    };
    
    const crlManager = new CRLManager(config);
    
    try {
        switch ('$NodeAction') {
            case 'revoke':
                const result = await crlManager.revokeLicense(
                    '$LicenseId',
                    '$Kid', 
                    '$Reason',
                    '$Description',
                    '$Serial'
                );
                console.log(JSON.stringify({success: result, action: 'revoke'}));
                break;
                
            case 'restore':
                const restoreResult = await crlManager.restoreLicense('$LicenseId', '$Kid');
                console.log(JSON.stringify({success: restoreResult, action: 'restore'}));
                break;
                
            case 'status':
                const stats = crlManager.getStats();
                console.log(JSON.stringify({success: true, stats}));
                break;
                
            case 'list':
                await crlManager.loadCRL();
                const revoked = crlManager.listRevokedLicenses();
                console.log(JSON.stringify({success: true, revokedLicenses: revoked}));
                break;
                
            case 'check':
                const checkResult = await crlManager.isLicenseRevoked('$LicenseId', '$Kid');
                console.log(JSON.stringify({success: true, result: checkResult}));
                break;
        }
    } catch (error) {
        console.log(JSON.stringify({success: false, error: error.message}));
        process.exit(1);
    }
}

main();
"@
    
    # Écrire le script temporaire
    $tempScript = [System.IO.Path]::GetTempFileName() + ".js"
    Set-Content -Path $tempScript -Value $crlScript
    
    try {
        # Exécuter avec Node.js
        $result = & node $tempScript 2>&1
        $jsonResult = $result | ConvertFrom-Json
        
        if (-not $jsonResult.success) {
            throw $jsonResult.error
        }
        
        return $jsonResult
        
    } finally {
        # Nettoyer
        if (Test-Path $tempScript) {
            Remove-Item $tempScript -Force
        }
    }
}

function Revoke-License {
    Write-Log "Révocation de licence..." "INFO"
    
    if (-not $LicenseId -and -not $Kid) {
        throw "LicenseId ou Kid requis pour la révocation"
    }
    
    if (-not $Reason) {
        throw "Raison de révocation requise"
    }
    
    try {
        $result = Invoke-CRLAction -NodeAction "revoke"
        
        if ($result.success) {
            Write-Log "Licence révoquée avec succès" "SUCCESS"
            Write-Log "LicenseId: $LicenseId" "INFO"
            Write-Log "Kid: $Kid" "INFO"
            Write-Log "Raison: $Reason" "INFO"
            if ($Description) { Write-Log "Description: $Description" "INFO" }
            if ($Serial) { Write-Log "Série: $Serial" "INFO" }
        } else {
            Write-Log "Échec révocation licence" "ERROR"
        }
        
    } catch {
        Write-Log "Erreur révocation: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Restore-License {
    Write-Log "Restauration de licence..." "INFO"
    
    if (-not $LicenseId -and -not $Kid) {
        throw "LicenseId ou Kid requis pour la restauration"
    }
    
    try {
        $result = Invoke-CRLAction -NodeAction "restore"
        
        if ($result.success) {
            Write-Log "Licence restaurée avec succès" "SUCCESS"
            Write-Log "LicenseId: $LicenseId" "INFO"
            Write-Log "Kid: $Kid" "INFO"
        } else {
            Write-Log "Échec restauration licence" "ERROR"
        }
        
    } catch {
        Write-Log "Erreur restauration: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Get-CRLStatus {
    Write-Log "Statut CRL..." "INFO"
    
    try {
        $result = Invoke-CRLAction -NodeAction "status"
        
        if ($result.success) {
            $stats = $result.stats
            
            Write-Log "STATUT CRL" "SUCCESS"
            Write-Log "=========" "INFO"
            Write-Log "Chargée: $($stats.loaded)" "INFO"
            Write-Log "Licences révoquées: $($stats.revokedCount)" "INFO"
            Write-Log "Dernière mise à jour: $($stats.lastUpdate)" "INFO"
            Write-Log "Prochaine mise à jour: $($stats.nextUpdate)" "INFO"
            Write-Log "Expirée: $($stats.expired)" "INFO"
            
            if ($stats.expired) {
                Write-Log "⚠️ CRL expirée - mise à jour recommandée" "WARNING"
            }
        }
        
    } catch {
        Write-Log "Erreur statut: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Get-RevokedLicenses {
    Write-Log "Liste des licences révoquées..." "INFO"
    
    try {
        $result = Invoke-CRLAction -NodeAction "list"
        
        if ($result.success) {
            $revoked = $result.revokedLicenses
            
            if ($revoked.Count -eq 0) {
                Write-Log "Aucune licence révoquée" "INFO"
                return
            }
            
            Write-Log "LICENCES RÉVOQUÉES ($($revoked.Count))" "SUCCESS"
            Write-Log "===================" "INFO"
            
            foreach ($license in $revoked) {
                Write-Log "" "INFO"
                Write-Log "LicenseId: $($license.licenseId)" "INFO"
                Write-Log "Kid: $($license.kid)" "INFO"
                Write-Log "Révoquée le: $($license.revokedAt)" "INFO"
                Write-Log "Raison: $($license.reason)" "INFO"
                if ($license.description) {
                    Write-Log "Description: $($license.description)" "INFO"
                }
                if ($license.serial) {
                    Write-Log "Série: $($license.serial)" "INFO"
                }
            }
            
            # Export optionnel
            if ($OutputPath) {
                $result.revokedLicenses | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
                Write-Log "Export sauvegardé: $OutputPath" "SUCCESS"
            }
        }
        
    } catch {
        Write-Log "Erreur liste: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# SCRIPT PRINCIPAL
try {
    Write-Log "CRL Management Tools - USB Video Vault" "SUCCESS"
    Write-Log "======================================" "INFO"
    
    Test-Prerequisites
    
    switch ($Action.ToLower()) {
        "create" {
            Initialize-CRL
        }
        
        "revoke" {
            Revoke-License
        }
        
        "restore" {
            Restore-License
        }
        
        "status" {
            Get-CRLStatus
        }
        
        "list" {
            Get-RevokedLicenses
        }
        
        "export" {
            if (-not $OutputPath) {
                $OutputPath = "crl-export-$(Get-Date -Format 'yyyy-MM-dd-HHmm').json"
            }
            Get-RevokedLicenses
        }
        
        default {
            Write-Log "Action non reconnue: $Action" "ERROR"
            Write-Log "Actions disponibles: create, revoke, restore, status, list, export" "INFO"
            exit 1
        }
    }
    
    Write-Log "Opération '$Action' terminée avec succès" "SUCCESS"
    
} catch {
    Write-Log "Erreur critique: $($_.Exception.Message)" "ERROR"
    exit 1
}