# Scripts Day-2 Operations - Backup configuration et revocation d'urgence
# Usage: .\tools\day2-emergency-procedures.ps1 [-Action "backup|revoke|restore"] [-TestMode]

param(
    [string]$Action = "backup",
    [switch]$TestMode
)

Write-Host "=== DAY-2 EMERGENCY PROCEDURES ===" -ForegroundColor Cyan
Write-Host "Action: $Action" -ForegroundColor White
Write-Host ""

$backupDir = ".\backup\emergency\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$logFile = ".\logs\emergency-$(Get-Date -Format 'yyyyMMdd').log"

# Creer dossiers
@($backupDir, ".\logs") | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(if($Level -eq "ERROR"){"Red"}elseif($Level -eq "WARN"){"Yellow"}else{"White"})
    $logEntry | Out-File -FilePath $logFile -Append -Encoding UTF8
}

Write-Log "=== DEBUT PROCEDURES URGENCE ===" "INFO"
Write-Log "Action demandee: $Action" "INFO"

switch ($Action.ToLower()) {
    "backup" {
        Write-Host "=== BACKUP CONFIGURATION COMPLETE ===" -ForegroundColor Yellow
        Write-Log "Debut backup configuration complete" "INFO"
        
        # Configuration critique
        $criticalFiles = @(
            @{ Path = ".\package.json"; Essential = $true },
            @{ Path = ".\electron-builder.yml"; Essential = $true },
            @{ Path = ".\tsconfig.json"; Essential = $false },
            @{ Path = ".\vite.renderer.config.ts"; Essential = $false },
            @{ Path = ".\build-config.json"; Essential = $false },
            @{ Path = ".\.env"; Essential = $false },
            @{ Path = ".\tools\setup-code-signing.ps1"; Essential = $true },
            @{ Path = ".\tools\setup-code-signing-enhanced.ps1"; Essential = $true },
            @{ Path = ".\packaging\winget\*.yaml"; Essential = $true },
            @{ Path = ".\packaging\chocolatey\*.nuspec"; Essential = $true }
        )
        
        $backupManifest = @{
            timestamp = Get-Date
            version = (Get-Content ".\package.json" | ConvertFrom-Json).version
            files = @()
            certificates = @()
            environment = @{
                os = "$env:OS $env:PROCESSOR_ARCHITECTURE"
                powershell = "$($PSVersionTable.PSVersion)"
                node = (node --version 2>$null)
                npm = (npm --version 2>$null)
            }
        }
        
        Write-Host "1. SAUVEGARDE FICHIERS CONFIGURATION..." -ForegroundColor Cyan
        
        foreach ($fileSpec in $criticalFiles) {
            $files = @()
            
            if ($fileSpec.Path -like "*\**") {
                # Pattern avec wildcards
                $files = Get-ChildItem $fileSpec.Path -ErrorAction SilentlyContinue
            } else {
                # Fichier unique
                if (Test-Path $fileSpec.Path) {
                    $files = @(Get-Item $fileSpec.Path)
                }
            }
            
            foreach ($file in $files) {
                $relativePath = $file.FullName.Replace((Get-Location).Path, ".")
                $backupPath = Join-Path $backupDir $file.Name
                
                if (-not $TestMode) {
                    Copy-Item $file.FullName $backupPath -Force
                }
                
                $fileInfo = @{
                    original = $relativePath
                    backup = $backupPath
                    size = $file.Length
                    lastWrite = $file.LastWriteTime
                    hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash
                    essential = $fileSpec.Essential
                }
                
                $backupManifest.files += $fileInfo
                
                Write-Host "  Backup: $($file.Name)" -ForegroundColor Green
                Write-Log "Fichier sauvegarde: $relativePath" "INFO"
            }
            
            if ($files.Count -eq 0 -and $fileSpec.Essential) {
                Write-Host "  MANQUANT: $($fileSpec.Path)" -ForegroundColor Red
                Write-Log "Fichier critique manquant: $($fileSpec.Path)" "ERROR"
            }
        }
        
        Write-Host ""
        Write-Host "2. SAUVEGARDE CERTIFICATS..." -ForegroundColor Cyan
        
        $certs = Get-ChildItem -Path @("Cert:\CurrentUser\My", "Cert:\LocalMachine\My") |
            Where-Object { $_.EnhancedKeyUsageList -like "*Code Signing*" }
            
        foreach ($cert in $certs) {
            $certInfo = @{
                subject = $cert.Subject
                thumbprint = $cert.Thumbprint
                issuer = $cert.Issuer
                notBefore = $cert.NotBefore
                notAfter = $cert.NotAfter
                store = if ($cert.PSPath -like "*CurrentUser*") { "CurrentUser" } else { "LocalMachine" }
            }
            
            $backupManifest.certificates += $certInfo
            
            Write-Host "  Cert: $($cert.Subject)" -ForegroundColor Green
            Write-Host "    Expire: $($cert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
            Write-Log "Certificat documente: $($cert.Subject)" "INFO"
        }
        
        Write-Host ""
        Write-Host "3. SAUVEGARDE ENVIRONNEMENT..." -ForegroundColor Cyan
        
        # Variables environnement critiques
        $envVars = @("NODE_ENV", "ELECTRON_CACHE", "npm_config_cache", "CSC_LINK", "CSC_KEY_PASSWORD")
        $backupManifest.environment.variables = @{}
        
        foreach ($envVar in $envVars) {
            $value = [Environment]::GetEnvironmentVariable($envVar)
            if ($value) {
                $backupManifest.environment.variables[$envVar] = $value
                Write-Host "  Env: $envVar = [REDACTED]" -ForegroundColor Green
                Write-Log "Variable environnement sauvegardee: $envVar" "INFO"
            }
        }
        
        # Sauvegarder manifest
        $manifestFile = Join-Path $backupDir "backup-manifest.json"
        if (-not $TestMode) {
            $backupManifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $manifestFile -Encoding UTF8
        }
        
        Write-Host ""
        Write-Host "BACKUP TERMINE:" -ForegroundColor Green
        Write-Host "  Dossier: $backupDir" -ForegroundColor White
        Write-Host "  Fichiers: $($backupManifest.files.Count)" -ForegroundColor White
        Write-Host "  Certificats: $($backupManifest.certificates.Count)" -ForegroundColor White
        Write-Log "Backup complet termine: $($backupManifest.files.Count) fichiers" "INFO"
    }
    
    "revoke" {
        Write-Host "=== REVOCATION CERTIFICAT D'URGENCE ===" -ForegroundColor Red
        Write-Log "Debut procedure revocation urgence" "ERROR"
        
        if ($TestMode) {
            Write-Host "MODE TEST - Simulation revocation" -ForegroundColor Blue
        } else {
            Write-Host "ATTENTION: Revocation certificat en cours!" -ForegroundColor Red
            $confirm = Read-Host "Continuer la revocation? (TAPER 'REVOKE' pour confirmer)"
            
            if ($confirm -ne "REVOKE") {
                Write-Host "Revocation annulee par utilisateur" -ForegroundColor Yellow
                Write-Log "Revocation annulee par utilisateur" "WARN"
                exit 0
            }
        }
        
        Write-Host ""
        Write-Host "1. IDENTIFICATION CERTIFICATS ACTIFS..." -ForegroundColor Yellow
        
        $activeCerts = Get-ChildItem -Path @("Cert:\CurrentUser\My", "Cert:\LocalMachine\My") |
            Where-Object { 
                $_.EnhancedKeyUsageList -like "*Code Signing*" -and 
                $_.NotAfter -gt (Get-Date)
            }
            
        if ($activeCerts.Count -eq 0) {
            Write-Host "  Aucun certificat actif trouve" -ForegroundColor Yellow
            Write-Log "Aucun certificat actif pour revocation" "WARN"
        } else {
            foreach ($cert in $activeCerts) {
                Write-Host "  Certificat actif: $($cert.Subject)" -ForegroundColor Yellow
                Write-Host "    Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
                Write-Host "    Expire: $($cert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
                Write-Log "Certificat identifie pour revocation: $($cert.Subject)" "ERROR"
            }
        }
        
        Write-Host ""
        Write-Host "2. PROCEDURES REVOCATION..." -ForegroundColor Yellow
        
        # Etapes revocation (procedures manuelles)
        $revocationSteps = @(
            "Contacter Autorite Certification (CA)",
            "Soumettre demande revocation avec raison",
            "Attendre confirmation CRL mise a jour",
            "Verifier revocation dans CRL public",
            "Notifier equipes build/release",
            "Mettre a jour documentation"
        )
        
        for ($i = 0; $i -lt $revocationSteps.Count; $i++) {
            Write-Host "  Etape $($i+1): $($revocationSteps[$i])" -ForegroundColor $(if($TestMode){"Blue"}else{"Red"})
            Write-Log "Etape revocation $($i+1): $($revocationSteps[$i])" "ERROR"
        }
        
        Write-Host ""
        Write-Host "3. NOTIFICATIONS URGENCE..." -ForegroundColor Yellow
        
        $notifications = @{
            timestamp = Get-Date
            action = "Certificate Revocation"
            severity = "CRITICAL"
            certificates = $activeCerts | ForEach-Object { 
                @{ subject = $_.Subject; thumbprint = $_.Thumbprint }
            }
            nextSteps = @(
                "Arreter tous builds en cours",
                "Invalider releases non deployees",
                "Commander nouveau certificat",
                "Re-signer tous binaires"
            )
        }
        
        $notificationFile = Join-Path $backupDir "revocation-notification.json"
        if (-not $TestMode) {
            $notifications | ConvertTo-Json -Depth 10 | Out-File -FilePath $notificationFile -Encoding UTF8
        }
        
        Write-Host "  Notifications preparees: $notificationFile" -ForegroundColor $(if($TestMode){"Blue"}else{"Red"})
        Write-Log "Notifications revocation preparees" "ERROR"
        
        if (-not $TestMode) {
            Write-Host ""
            Write-Host "REVOCATION EN COURS - Surveiller CRL pour confirmation" -ForegroundColor Red
        }
    }
    
    "restore" {
        Write-Host "=== RESTAURATION CONFIGURATION ===" -ForegroundColor Green
        Write-Log "Debut restauration configuration" "INFO"
        
        # Rechercher backup le plus recent
        $backupDirs = Get-ChildItem ".\backup\emergency\" -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending
            
        if ($backupDirs.Count -eq 0) {
            Write-Host "ERREUR: Aucun backup trouve" -ForegroundColor Red
            Write-Log "Aucun backup disponible pour restauration" "ERROR"
            exit 1
        }
        
        $latestBackup = $backupDirs[0].FullName
        $manifestFile = Join-Path $latestBackup "backup-manifest.json"
        
        if (-not (Test-Path $manifestFile)) {
            Write-Host "ERREUR: Manifest backup manquant: $manifestFile" -ForegroundColor Red
            Write-Log "Manifest backup manquant: $manifestFile" "ERROR"
            exit 1
        }
        
        Write-Host "Backup selectionne: $($backupDirs[0].Name)" -ForegroundColor Green
        
        try {
            $manifest = Get-Content $manifestFile -Raw | ConvertFrom-Json
            
            Write-Host "  Version: $($manifest.version)" -ForegroundColor Gray
            Write-Host "  Date: $($manifest.timestamp)" -ForegroundColor Gray
            Write-Host "  Fichiers: $($manifest.files.Count)" -ForegroundColor Gray
            
            if (-not $TestMode) {
                $confirm = Read-Host "Confirmer restauration? (y/N)"
                if ($confirm -ne 'y' -and $confirm -ne 'Y') {
                    Write-Host "Restauration annulee" -ForegroundColor Yellow
                    Write-Log "Restauration annulee par utilisateur" "WARN"
                    exit 0
                }
            }
            
            Write-Host ""
            Write-Host "Restauration fichiers..." -ForegroundColor Yellow
            
            foreach ($fileInfo in $manifest.files) {
                if (Test-Path $fileInfo.backup) {
                    if (-not $TestMode) {
                        Copy-Item $fileInfo.backup $fileInfo.original -Force
                        
                        # Verifier integrite
                        $newHash = (Get-FileHash $fileInfo.original -Algorithm SHA256).Hash
                        if ($newHash -eq $fileInfo.hash) {
                            Write-Host "  Restaure: $($fileInfo.original)" -ForegroundColor Green
                        } else {
                            Write-Host "  ERREUR HASH: $($fileInfo.original)" -ForegroundColor Red
                        }
                    } else {
                        Write-Host "  [TEST] Restaurerait: $($fileInfo.original)" -ForegroundColor Blue
                    }
                    
                    Write-Log "Fichier restaure: $($fileInfo.original)" "INFO"
                } else {
                    Write-Host "  MANQUANT: $($fileInfo.backup)" -ForegroundColor Red
                    Write-Log "Fichier backup manquant: $($fileInfo.backup)" "ERROR"
                }
            }
            
            Write-Host ""
            Write-Host "RESTAURATION TERMINEE" -ForegroundColor Green
            Write-Log "Restauration terminee avec succes" "INFO"
            
        } catch {
            Write-Host "ERREUR restauration: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "Erreur restauration: $($_.Exception.Message)" "ERROR"
            exit 1
        }
    }
    
    default {
        Write-Host "ERREUR: Action inconnue '$Action'" -ForegroundColor Red
        Write-Host "Actions valides: backup, revoke, restore" -ForegroundColor Blue
        Write-Log "Action inconnue demandee: $Action" "ERROR"
        exit 1
    }
}

Write-Host ""
Write-Log "=== FIN PROCEDURES URGENCE ===" "INFO"
Write-Host "Log complet: $logFile" -ForegroundColor Gray