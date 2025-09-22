# Vérification Santé Rapide - USB Video Vault
# Snippets utiles pour contrôle instantané production

param(
    [switch]$QuickCheck,
    [switch]$ProcessInfo,
    [switch]$LicenseStatus,
    [switch]$LogErrors,
    [switch]$All,
    [int]$TailLines = 200
)

function Write-StatusLine {
    param($Check, $Status, $Details = "")
    $icon = if ($Status -eq "OK") { "✅" } else { "❌" }
    $color = if ($Status -eq "OK") { "Green" } else { "Red" }
    
    Write-Host "$icon $Check`: " -NoNewline
    Write-Host "$Status" -ForegroundColor $color
    if ($Details) {
        Write-Host "   $Details" -ForegroundColor Gray
    }
}

function Get-QuickHealthCheck {
    Write-Host "`n🏥 === VERIFICATION SANTE RAPIDE USB VIDEO VAULT ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    
    # 1. Process Status
    $process = Get-Process | Where-Object { $_.ProcessName -like "*USB*Video*Vault*" }
    if ($process) {
        $memoryMB = [math]::Round($process.WorkingSet64 / 1MB, 1)
        $uptime = (Get-Date) - $process.StartTime
        Write-StatusLine "Application Running" "OK" "PID: $($process.Id), Memory: $memoryMB MB, Uptime: $([math]::Round($uptime.TotalHours, 1))h"
    } else {
        Write-StatusLine "Application Running" "STOPPED" "Aucun processus USB Video Vault détecté"
    }
    
    # 2. License File
    $licensePath = "$env:ProgramData\USB Video Vault\license.bin"
    if (Test-Path $licensePath) {
        $licenseSize = (Get-Item $licensePath).Length
        $licenseDate = (Get-Item $licensePath).LastWriteTime
        Write-StatusLine "License File" "OK" "Size: $licenseSize bytes, Modified: $($licenseDate.ToString('yyyy-MM-dd HH:mm'))"
    } else {
        Write-StatusLine "License File" "MISSING" "Fichier licence non trouvé: $licensePath"
    }
    
    # 3. Log File
    $logPath = "$env:APPDATA\USB Video Vault\logs\main.log"
    if (Test-Path $logPath) {
        $logSize = [math]::Round((Get-Item $logPath).Length / 1KB, 1)
        $logDate = (Get-Item $logPath).LastWriteTime
        Write-StatusLine "Log File" "OK" "Size: $logSize KB, Modified: $($logDate.ToString('yyyy-MM-dd HH:mm'))"
    } else {
        Write-StatusLine "Log File" "MISSING" "Fichier log non trouvé: $logPath"
    }
    
    # 4. Recent Errors (dernières 24h)
    if (Test-Path $logPath) {
        $recentErrors = Get-Content $logPath -Tail 1000 | 
            Where-Object { $_ -match 'Signature invalide|licence expirée|Anti-rollback|Erreur|ERROR|crash|fatal' } |
            Where-Object { $_ -match (Get-Date).ToString('yyyy-MM-dd') -or $_ -match (Get-Date).AddDays(-1).ToString('yyyy-MM-dd') }
        
        if ($recentErrors) {
            Write-StatusLine "Recent Errors (24h)" "FOUND" "$($recentErrors.Count) erreur(s) détectée(s)"
        } else {
            Write-StatusLine "Recent Errors (24h)" "OK" "Aucune erreur récente"
        }
    }
    
    # 5. Vault Access
    $vaultPaths = @(
        "$env:ProgramData\USB Video Vault\vault",
        ".\vault",
        ".\usb-package\vault"
    )
    
    $vaultFound = $false
    foreach ($vaultPath in $vaultPaths) {
        if (Test-Path $vaultPath) {
            $vaultItems = Get-ChildItem $vaultPath -ErrorAction SilentlyContinue
            Write-StatusLine "Vault Access" "OK" "Path: $vaultPath, Items: $($vaultItems.Count)"
            $vaultFound = $true
            break
        }
    }
    
    if (!$vaultFound) {
        Write-StatusLine "Vault Access" "WARNING" "Aucun vault trouvé dans les chemins standards"
    }
    
    Write-Host ""
}

function Get-ProcessDetails {
    Write-Host "`n💻 === DETAILS PROCESSUS ===" -ForegroundColor Cyan
    
    $processes = Get-Process | Where-Object { $_.ProcessName -like "*USB*Video*Vault*" -or $_.ProcessName -like "*usbvv*" }
    
    if ($processes) {
        $processes | ForEach-Object {
            Write-Host "Process: $($_.ProcessName)" -ForegroundColor Yellow
            Write-Host "  PID: $($_.Id)"
            Write-Host "  Memory: $([math]::Round($_.WorkingSet64/1MB,1)) MB (Working Set)"
            Write-Host "  Peak Memory: $([math]::Round($_.PeakWorkingSet64/1MB,1)) MB"
            Write-Host "  CPU Time: $($_.TotalProcessorTime)"
            Write-Host "  Start Time: $($_.StartTime)"
            Write-Host "  Threads: $($_.Threads.Count)"
            Write-Host "  Handles: $($_.HandleCount)"
            Write-Host ""
        }
    } else {
        Write-Host "Aucun processus USB Video Vault en cours d'exécution" -ForegroundColor Red
    }
}

function Get-LicenseDetails {
    Write-Host "`n🔐 === STATUS LICENCE ===" -ForegroundColor Cyan
    
    $licensePaths = @(
        "$env:ProgramData\USB Video Vault\license.bin",
        ".\license.bin",
        ".\deliveries\ring1\*.bin"
    )
    
    foreach ($licensePath in $licensePaths) {
        $licenses = Get-ChildItem $licensePath -ErrorAction SilentlyContinue
        
        if ($licenses) {
            $licenses | ForEach-Object {
                Write-Host "License: $($_.Name)" -ForegroundColor Yellow
                Write-Host "  Path: $($_.FullName)"
                Write-Host "  Size: $($_.Length) bytes"
                Write-Host "  Created: $($_.CreationTime)"
                Write-Host "  Modified: $($_.LastWriteTime)"
                
                # Test de validation si possible
                $verifyScript = Join-Path "scripts" "verify-license.mjs"
                if (Test-Path $verifyScript) {
                    try {
                        $validation = & node $verifyScript $_.FullName 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  Validation: ✅ VALIDE" -ForegroundColor Green
                        } else {
                            Write-Host "  Validation: ❌ INVALIDE" -ForegroundColor Red
                            Write-Host "    Error: $validation" -ForegroundColor Red
                        }
                    } catch {
                        Write-Host "  Validation: ⚠️ IMPOSSIBLE" -ForegroundColor Yellow
                    }
                }
                Write-Host ""
            }
        }
    }
}

function Get-LogErrors {
    Write-Host "`n📋 === ERREURS LOGS RECENTES ===" -ForegroundColor Cyan
    
    $logPath = "$env:APPDATA\USB Video Vault\logs\main.log"
    
    if (Test-Path $logPath) {
        Write-Host "Analyse: $logPath (dernières $TailLines lignes)" -ForegroundColor Gray
        Write-Host ""
        
        $errorPatterns = @(
            'Signature invalide',
            'licence expirée', 
            'Anti-rollback',
            'Erreur',
            'ERROR',
            'crash',
            'fatal',
            'exception',
            'unhandled'
        )
        
        $errors = Get-Content $logPath -Tail $TailLines | 
            Where-Object { 
                $line = $_
                $errorPatterns | Where-Object { $line -match $_ }
            } | 
            Select-Object -Last 20  # Dernières 20 erreurs max
        
        if ($errors) {
            Write-Host "🚨 Erreurs trouvées:" -ForegroundColor Red
            $errors | ForEach-Object {
                # Colorer selon le type d'erreur
                $color = switch -regex ($_) {
                    'fatal|crash' { 'Red' }
                    'ERROR|Erreur' { 'Magenta' }
                    'licence|signature' { 'Yellow' }
                    default { 'White' }
                }
                Write-Host "  $_" -ForegroundColor $color
            }
        } else {
            Write-Host "✅ Aucune erreur trouvée dans les dernières $TailLines lignes" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Fichier log non trouvé: $logPath" -ForegroundColor Red
    }
    
    Write-Host ""
}

# === SNIPPET UTILISATEUR (comme demandé) ===
function Show-UserSnippets {
    Write-Host "`n📄 === SNIPPETS UTILISATEUR ===" -ForegroundColor Cyan
    
    Write-Host "`n1️⃣ Vérification santé rapide (poste client):" -ForegroundColor Yellow
    Write-Host @'
$log="$env:APPDATA\USB Video Vault\logs\main.log"
Get-Content $log -Tail 200 | Select-String 'Signature invalide|licence expirée|Anti-rollback|Erreur'
Get-Process | ? {$_.ProcessName -like '*USB*Video*Vault*'} |
  Select ProcessName,@{n='MB';e={[math]::Round($_.WorkingSet64/1MB,1)}}
'@ -ForegroundColor Cyan
    
    Write-Host "`n2️⃣ Renouvellement lot (ex. J-15):" -ForegroundColor Yellow
    Write-Host @'
Import-Csv .\ring1-renewals.csv | % {
  node .\scripts\make-license.mjs $_.Fingerprint $_.UsbSerial
  Move-Item .\license.bin ".\deliveries\renewals\$($_.Machine)-license.bin" -Force
  node .\scripts\verify-license.mjs ".\deliveries\renewals\$($_.Machine)-license.bin"
}
'@ -ForegroundColor Cyan
    
    Write-Host "`n3️⃣ Contrôle signature/horodatage binaire:" -ForegroundColor Yellow
    Write-Host @'
Get-AuthenticodeSignature ".\releases\v1.0.4\USB Video Vault.exe" | fl *
'@ -ForegroundColor Cyan
    
    Write-Host ""
}

# === EXECUTION PRINCIPALE ===

if ($All) {
    Get-QuickHealthCheck
    Get-ProcessDetails  
    Get-LicenseDetails
    Get-LogErrors
    Show-UserSnippets
} else {
    if ($QuickCheck -or (!$ProcessInfo -and !$LicenseStatus -and !$LogErrors)) {
        Get-QuickHealthCheck
    }
    
    if ($ProcessInfo) {
        Get-ProcessDetails
    }
    
    if ($LicenseStatus) {
        Get-LicenseDetails
    }
    
    if ($LogErrors) {
        Get-LogErrors
    }
}