# Support Bundle Generator - Script Simplifié
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
}

function Sanitize-LogContent {
    param([string]$LogContent)
    
    # Patterns sensibles à nettoyer
    $sensitivePatterns = @(
        "(?i)(private[_\s]*key|secret|password|token)[:\s=]*[a-zA-Z0-9+/]{20,}",
        "C:\\Users\\[^\\]+\\",
        "(?:192\.168\.|10\.|172\.(?:1[6-9]|2[0-9]|3[01])\.)\d{1,3}\.\d{1,3}",
        "(?i)serial[:\s=]*[A-Z0-9]{10,}",
        "(?i)fingerprint[:\s=]*[a-f0-9]{32,}"
    )
    
    $sanitizedContent = $LogContent
    
    foreach ($pattern in $sensitivePatterns) {
        $sanitizedContent = $sanitizedContent -replace $pattern, "[REDACTED]"
    }
    
    # Remplacer nom utilisateur
    $sanitizedContent = $sanitizedContent -replace [regex]::Escape($env:USERNAME), "[USER]"
    
    return $sanitizedContent
}

# === EXÉCUTION PRINCIPALE ===
try {
    Write-SupportLog "=== GÉNÉRATION BUNDLE SUPPORT USB VIDEO VAULT ===" 
    
    # Chemin logs application
    $logsPath = Join-Path $env:APPDATA "USB Video Vault\logs"
    
    Write-SupportLog "Collecte logs: $logsPath"
    
    if (-not (Test-Path $logsPath)) {
        Write-SupportLog "Dossier logs non trouvé: $logsPath" "WARN"
        Write-Host "⚠️ Aucun log trouvé. L'application a-t-elle été lancée ?" -ForegroundColor Yellow
        exit 1
    }
    
    # Générer nom bundle
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $clientSuffix = if ($ClientId) { "-$ClientId" } else { "" }
    $bundleName = "UVV-support$clientSuffix-$timestamp"
    $zipFile = Join-Path $OutputPath "$bundleName.zip"
    
    # Version simple avec 7z directement sur les logs
    Write-SupportLog "Compression logs vers: $zipFile"
    
    # Vérifier 7-Zip
    $7zPath = Get-Command "7z" -ErrorAction SilentlyContinue
    if (-not $7zPath) {
        # Fallback PowerShell si 7z pas disponible
        Write-SupportLog "7-Zip non trouvé, utilisation compression PowerShell"
        
        # Créer archive avec compression PowerShell
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        $tempDir = Join-Path $env:TEMP $bundleName
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        
        # Copier et nettoyer les logs
        $logFiles = Get-ChildItem $logsPath -Filter "*.log" | 
                   Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) }
        
        foreach ($logFile in $logFiles) {
            $content = Get-Content $logFile.FullName -Raw
            $sanitized = Sanitize-LogContent -LogContent $content
            $targetFile = Join-Path $tempDir $logFile.Name
            $sanitized | Out-File -FilePath $targetFile -Encoding UTF8
        }
        
        # Ajouter métadonnées
        $metadata = @{
            generatedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            hostname = $env:COMPUTERNAME
            clientId = $ClientId
            logsCount = $logFiles.Count
            sanitized = $true
        }
        
        $metadataFile = Join-Path $tempDir "bundle-info.json"
        $metadata | ConvertTo-Json | Out-File -FilePath $metadataFile -Encoding UTF8
        
        # Créer ZIP
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipFile)
        
        # Nettoyer
        Remove-Item $tempDir -Recurse -Force
        
    } else {
        # Utiliser 7-Zip (méthode recommandée)
        & 7z a -tzip "$zipFile" "$logsPath*.log" | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            throw "Erreur compression 7-Zip (code: $LASTEXITCODE)"
        }
    }
    
    # Vérifier résultat
    if (Test-Path $zipFile) {
        $bundleSize = (Get-Item $zipFile).Length
        
        Write-Host "`n🎯 BUNDLE DE SUPPORT GÉNÉRÉ" -ForegroundColor Green
        Write-Host "📁 Fichier: $zipFile" -ForegroundColor Yellow
        Write-Host "📊 Taille: $([math]::Round($bundleSize / 1KB, 2)) KB" -ForegroundColor Yellow
        Write-Host "🔒 Logs nettoyés automatiquement" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "📧 PROCHAINES ÉTAPES:" -ForegroundColor Cyan
        Write-Host "1. Joindre ce fichier à votre ticket support" -ForegroundColor White
        Write-Host "2. Référence bundle: $bundleName" -ForegroundColor White
        Write-Host ""
        
    } else {
        throw "Le fichier bundle n'a pas été créé"
    }
    
} catch {
    Write-SupportLog "ERREUR: $($_.Exception.Message)" "ERROR"
    Write-Host "❌ Erreur: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}