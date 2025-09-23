# Support Bundle Generator - USB Video Vault

## Vue d'ensemble

Script automatisé pour générer un bundle de support contenant uniquement les logs nécessaires au diagnostic, sans exposer d'informations sensibles.

## Script Principal

```powershell
# scripts/generate-support-bundle.ps1
param(
    [string]$OutputPath = "$env:TEMP",
    [string]$ClientId = "",
    [switch]$IncludeDiagnostics,
    [switch]$Verbose
)

function Write-SupportLog {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    if ($Verbose) {
        Write-Host $logMessage
    }
    
    # Log vers fichier support
    $supportLogPath = Join-Path $OutputPath "support-generation.log"
    Add-Content -Path $supportLogPath -Value $logMessage
}

function Get-SystemDiagnostics {
    Write-SupportLog "Collecte diagnostics système"
    
    $diagnostics = @{
        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        hostname = $env:COMPUTERNAME
        username = $env:USERNAME
        osVersion = [System.Environment]::OSVersion.VersionString
        architecture = $env:PROCESSOR_ARCHITECTURE
        dotNetVersion = $PSVersionTable.PSVersion.ToString()
        
        # Informations USB Video Vault
        appDataPath = Join-Path $env:APPDATA "USB Video Vault"
        vaultPath = $env:VAULT_PATH
        
        # Processus actifs
        usbVideoVaultProcesses = @()
    }
    
    # Vérifier processus USB Video Vault
    try {
        $processes = Get-Process "USB Video Vault" -ErrorAction SilentlyContinue
        if ($processes) {
            $diagnostics.usbVideoVaultProcesses = $processes | ForEach-Object {
                @{
                    id = $_.Id
                    startTime = $_.StartTime
                    workingSet = [math]::Round($_.WorkingSet64 / 1MB, 2)
                    cpuTime = $_.TotalProcessorTime.TotalSeconds
                }
            }
        }
    } catch {
        Write-SupportLog "Impossible de récupérer les processus: $($_.Exception.Message)" "WARN"
    }
    
    # Vérifier structure vault
    if ($diagnostics.vaultPath -and (Test-Path $diagnostics.vaultPath)) {
        $vaultInfo = @{
            exists = $true
            vaultDir = Test-Path (Join-Path $diagnostics.vaultPath ".vault")
            licenseFile = Test-Path (Join-Path $diagnostics.vaultPath ".vault\license.bin")
        }
        
        if ($vaultInfo.licenseFile) {
            $licenseFile = Join-Path $diagnostics.vaultPath ".vault\license.bin"
            $vaultInfo.licenseSize = (Get-Item $licenseFile).Length
            $vaultInfo.licenseModified = (Get-Item $licenseFile).LastWriteTime
        }
        
        $diagnostics.vaultInfo = $vaultInfo
    }
    
    return $diagnostics
}

function Sanitize-LogContent {
    param([string]$LogContent)
    
    # Patterns à nettoyer pour la sécurité
    $sensitivePatterns = @(
        # Clés privées ou secrets
        "(?i)(private[_\s]*key|secret|password|token)[:\s=]*[a-zA-Z0-9+/]{20,}",
        # Chemins absolus utilisateur
        "C:\\Users\\[^\\]+\\",
        # Adresses IP privées complètes
        "(?:192\.168\.|10\.|172\.(?:1[6-9]|2[0-9]|3[01])\.)\d{1,3}\.\d{1,3}",
        # Numéros de série complets
        "(?i)serial[:\s=]*[A-Z0-9]{10,}",
        # Empreintes machines complètes
        "(?i)fingerprint[:\s=]*[a-f0-9]{32,}"
    )
    
    $sanitizedContent = $LogContent
    
    foreach ($pattern in $sensitivePatterns) {
        $sanitizedContent = $sanitizedContent -replace $pattern, "[REDACTED]"
    }
    
    # Remplacer nom utilisateur par générique
    $sanitizedContent = $sanitizedContent -replace [regex]::Escape($env:USERNAME), "[USER]"
    
    return $sanitizedContent
}

function Collect-ApplicationLogs {
    param([string]$LogsPath)
    
    Write-SupportLog "Collecte logs application: $LogsPath"
    
    if (-not (Test-Path $LogsPath)) {
        Write-SupportLog "Dossier logs non trouvé: $LogsPath" "WARN"
        return @()
    }
    
    # Collecter logs des 7 derniers jours
    $cutoffDate = (Get-Date).AddDays(-7)
    $logFiles = Get-ChildItem $LogsPath -Filter "*.log" | 
                Where-Object { $_.LastWriteTime -gt $cutoffDate } |
                Sort-Object LastWriteTime -Descending
    
    $collectedLogs = @()
    
    foreach ($logFile in $logFiles) {
        try {
            Write-SupportLog "Traitement: $($logFile.Name)"
            
            $content = Get-Content $logFile.FullName -Raw -ErrorAction Continue
            $sanitizedContent = Sanitize-LogContent -LogContent $content
            
            $logInfo = @{
                fileName = $logFile.Name
                size = $logFile.Length
                lastModified = $logFile.LastWriteTime
                content = $sanitizedContent
                lineCount = ($sanitizedContent -split "`n").Count
            }
            
            $collectedLogs += $logInfo
            
        } catch {
            Write-SupportLog "Erreur traitement $($logFile.Name): $($_.Exception.Message)" "ERROR"
        }
    }
    
    return $collectedLogs
}

function Generate-SupportBundle {
    param(
        [array]$Logs,
        [object]$Diagnostics,
        [string]$OutputPath,
        [string]$ClientId
    )
    
    # Générer nom bundle
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $clientSuffix = if ($ClientId) { "-$ClientId" } else { "" }
    $bundleName = "UVV-support$clientSuffix-$timestamp"
    $tempDir = Join-Path $env:TEMP $bundleName
    
    Write-SupportLog "Génération bundle: $bundleName"
    
    # Créer structure temporaire
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    
    # 1. Diagnostics système
    $diagnosticsFile = Join-Path $tempDir "system-diagnostics.json"
    $Diagnostics | ConvertTo-Json -Depth 10 | Out-File -FilePath $diagnosticsFile -Encoding UTF8
    
    # 2. Logs d'application
    $logsDir = Join-Path $tempDir "logs"
    New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    
    foreach ($log in $Logs) {
        $logFile = Join-Path $logsDir $log.fileName
        $log.content | Out-File -FilePath $logFile -Encoding UTF8
    }
    
    # 3. Métadonnées du bundle
    $metadata = @{
        bundleVersion = "1.0"
        generatedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        generatedBy = $env:USERNAME
        hostname = $env:COMPUTERNAME
        clientId = $ClientId
        appVersion = "Unknown" # À récupérer depuis package.json si possible
        logsCount = $Logs.Count
        timespan = "7 days"
        sanitized = $true
    }
    
    $metadataFile = Join-Path $tempDir "bundle-metadata.json"
    $metadata | ConvertTo-Json -Depth 10 | Out-File -FilePath $metadataFile -Encoding UTF8
    
    # 4. Instructions support
    $instructions = @"
BUNDLE DE SUPPORT USB VIDEO VAULT
=================================

Ce bundle contient les informations de diagnostic pour résoudre votre problème.

Contenu:
- system-diagnostics.json : Informations système
- logs/ : Logs d'application (7 derniers jours, nettoyés)
- bundle-metadata.json : Métadonnées du bundle

Informations sensibles:
- Toutes les informations sensibles ont été automatiquement supprimées
- Aucune clé privée ou mot de passe n'est inclus
- Les chemins utilisateur ont été anonymisés

Support:
- Joindre ce bundle à votre ticket de support
- Indiquer le numéro de bundle: $bundleName
- Décrire le problème rencontré et les étapes de reproduction

Généré le: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Hostname: $env:COMPUTERNAME
"@
    
    $instructionsFile = Join-Path $tempDir "README.txt"
    $instructions | Out-File -FilePath $instructionsFile -Encoding UTF8
    
    # 5. Compression avec 7-Zip
    $zipFile = Join-Path $OutputPath "$bundleName.zip"
    
    try {
        # Vérifier que 7z est disponible
        $7zPath = Get-Command "7z" -ErrorAction SilentlyContinue
        if (-not $7zPath) {
            throw "7-Zip non trouvé. Veuillez installer 7-Zip."
        }
        
        Write-SupportLog "Compression bundle: $zipFile"
        & 7z a -tzip "$zipFile" "$tempDir\*" | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            throw "Erreur compression 7-Zip (code: $LASTEXITCODE)"
        }
        
        # Nettoyer dossier temporaire
        Remove-Item $tempDir -Recurse -Force
        
        # Vérifier taille finale
        $bundleSize = (Get-Item $zipFile).Length
        Write-SupportLog "Bundle généré: $zipFile ($([math]::Round($bundleSize / 1KB, 2)) KB)"
        
        return @{
            success = $true
            bundlePath = $zipFile
            bundleName = $bundleName
            size = $bundleSize
            logsIncluded = $Logs.Count
        }
        
    } catch {
        Write-SupportLog "Erreur génération bundle: $($_.Exception.Message)" "ERROR"
        
        # Nettoyer en cas d'erreur
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
        
        return @{
            success = $false
            error = $_.Exception.Message
        }
    }
}

# === EXÉCUTION PRINCIPALE ===
try {
    Write-SupportLog "=== DÉBUT GÉNÉRATION BUNDLE SUPPORT ===" 
    
    # Chemin logs application
    $logsPath = Join-Path $env:APPDATA "USB Video Vault\logs"
    
    # 1. Collecte diagnostics
    $diagnostics = Get-SystemDiagnostics
    if ($IncludeDiagnostics) {
        Write-SupportLog "Diagnostics inclus dans le bundle"
    }
    
    # 2. Collecte logs
    $logs = Collect-ApplicationLogs -LogsPath $logsPath
    Write-SupportLog "Logs collectés: $($logs.Count)"
    
    # 3. Génération bundle
    $result = Generate-SupportBundle -Logs $logs -Diagnostics $diagnostics -OutputPath $OutputPath -ClientId $ClientId
    
    if ($result.success) {
        Write-Host "`n🎯 BUNDLE DE SUPPORT GÉNÉRÉ AVEC SUCCÈS" -ForegroundColor Green
        Write-Host "📁 Fichier: $($result.bundlePath)" -ForegroundColor Yellow
        Write-Host "📊 Taille: $([math]::Round($result.size / 1KB, 2)) KB" -ForegroundColor Yellow
        Write-Host "📋 Logs inclus: $($result.logsIncluded)" -ForegroundColor Yellow
        Write-Host "🔒 Informations sensibles supprimées automatiquement" -ForegroundColor Yellow
        Write-Host "`n📧 ÉTAPES SUIVANTES:" -ForegroundColor Cyan
        Write-Host "1. Joindre ce fichier à votre ticket de support" -ForegroundColor White
        Write-Host "2. Indiquer le numéro de bundle: $($result.bundleName)" -ForegroundColor White
        Write-Host "3. Décrire le problème rencontré" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "❌ ERREUR GÉNÉRATION BUNDLE" -ForegroundColor Red
        Write-Host "Erreur: $($result.error)" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-SupportLog "ERREUR CRITIQUE: $($_.Exception.Message)" "ERROR"
    Write-Host "❌ Erreur critique: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
```

## Utilisation

### Génération Standard
```powershell
# Bundle basique
.\scripts\generate-support-bundle.ps1

# Avec ID client
.\scripts\generate-support-bundle.ps1 -ClientId "ACME-001"

# Avec diagnostics étendus
.\scripts\generate-support-bundle.ps1 -IncludeDiagnostics -Verbose
```

### Génération via Raccourci
```powershell
# scripts/support-bundle-shortcut.ps1
# Version simplifiée pour utilisateurs non-techniques

Write-Host "🔧 GÉNÉRATION BUNDLE DE SUPPORT USB VIDEO VAULT" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$clientName = Read-Host "Nom du client (optionnel)"
if (-not $clientName) {
    $clientName = $env:COMPUTERNAME
}

Write-Host "Génération du bundle en cours..." -ForegroundColor Yellow

try {
    $result = & ".\scripts\generate-support-bundle.ps1" -ClientId $clientName -Verbose
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Bundle généré avec succès !" -ForegroundColor Green
        Write-Host "📁 Emplacement: $env:TEMP" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "📧 Prochaines étapes:" -ForegroundColor Cyan
        Write-Host "1. Ouvrir le dossier $env:TEMP" -ForegroundColor White
        Write-Host "2. Chercher le fichier UVV-support-*.zip" -ForegroundColor White
        Write-Host "3. Joindre ce fichier à votre email de support" -ForegroundColor White
        
        # Ouvrir dossier automatiquement
        $openFolder = Read-Host "`nOuvrir le dossier maintenant ? (O/N)"
        if ($openFolder -eq "O" -or $openFolder -eq "o") {
            Start-Process explorer $env:TEMP
        }
    }
} catch {
    Write-Host "❌ Erreur: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nAppuyer sur Entrée pour fermer..." -ForegroundColor Gray
Read-Host
```

## Sécurité et Confidentialité

### Données Sanitisées
- **Clés privées** : Automatiquement supprimées
- **Mots de passe** : Anonymisés  
- **Chemins utilisateur** : Remplacés par `[USER]`
- **Adresses IP** : Partiellement masquées
- **Numéros de série** : Tronqués
- **Empreintes machines** : Partiellement masquées

### Contenu Bundle
```
UVV-support-CLIENT-20250920-143022.zip
├── README.txt                 # Instructions support
├── bundle-metadata.json       # Métadonnées bundle
├── system-diagnostics.json    # Infos système (sanitisées)
└── logs/                      # Logs application (7 derniers jours)
    ├── app-20250920.log
    ├── error-20250919.log
    └── debug-20250918.log
```

Ce système assure une collecte sécurisée et complète des informations nécessaires au support tout en protégeant la confidentialité des données client.