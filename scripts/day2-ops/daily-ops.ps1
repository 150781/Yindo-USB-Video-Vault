# 🌅 Daily Operations Script
# Routines quotidiennes automatisées

param(
    [Parameter(Mandatory=$false)]
    [switch]$Morning = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Evening = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$All = $false
)

$ErrorActionPreference = "Continue"

Write-Host "🌅 === DAILY OPS - USB Video Vault ===" -ForegroundColor Cyan
Write-Host "📅 Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray

function Start-MorningChecks {
    Write-Host "`n☀️ === CHECKS MATINAUX (9h00) ===" -ForegroundColor Yellow
    
    # 1. Vérifier tickets support en attente
    Write-Host "📧 Vérification tickets support..." -ForegroundColor White
    if (Test-Path "support-tickets-pending.txt") {
        $pendingCount = (Get-Content "support-tickets-pending.txt" | Measure-Object -Line).Lines
        if ($pendingCount -gt 0) {
            Write-Host "⚠️ $pendingCount tickets en attente" -ForegroundColor Yellow
            Write-Host "💡 Action: Générer diagnostics si besoin" -ForegroundColor Blue
        } else {
            Write-Host "✅ Aucun ticket en attente" -ForegroundColor Green
        }
    } else {
        Write-Host "ℹ️ Aucun fichier tickets trouvé" -ForegroundColor Gray
    }
    
    # 2. Stats licences + alertes expiration
    Write-Host "`n🔑 Vérification licences..." -ForegroundColor White
    try {
        $stats = node tools/license-management/license-manager.mjs stats 2>$null
        if ($stats) {
            Write-Host $stats
            
            # Alertes licences expirant bientôt
            if ($stats -match "expiring_soon:\s*([1-9]\d*)") {
                $expiring = $matches[1]
                Write-Host "⚠️ $expiring licence(s) expirent dans 7 jours" -ForegroundColor Yellow
                Write-Host "📋 Action: Contacter clients pour renouvellement" -ForegroundColor Blue
            }
        } else {
            Write-Host "✅ Système licences opérationnel" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Erreur vérification licences: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # 3. Vérification intégrité système
    Write-Host "`n🔍 Intégrité système..." -ForegroundColor White
    
    # Vérifier builds signés
    if (Test-Path "dist\USB-Video-Vault-*.exe") {
        $exeFile = Get-ChildItem "dist\USB-Video-Vault-*.exe" | Select-Object -First 1
        Write-Host "📦 Build trouvé: $($exeFile.Name)" -ForegroundColor Gray
        
        # Vérifier signature (si signé)
        try {
            $sig = Get-AuthenticodeSignature $exeFile.FullName
            if ($sig.Status -eq "Valid") {
                Write-Host "✅ Signature valide" -ForegroundColor Green
            } else {
                Write-Host "⚠️ Signature: $($sig.Status)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "ℹ️ Signature non vérifiable (normal en dev)" -ForegroundColor Gray
        }
    }
    
    Write-Host "✅ Checks matinaux terminés" -ForegroundColor Green
}

function Start-EveningBackup {
    Write-Host "`n🌙 === BACKUP QUOTIDIEN (18h00) ===" -ForegroundColor Yellow
    
    $today = Get-Date -Format "yyyy-MM-dd"
    $backupDir = "backups"
    
    # Créer dossier backup si inexistant
    if (!(Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    
    # 1. Backup registre licences
    Write-Host "💾 Backup registre licences..." -ForegroundColor White
    $registryPath = "tools\license-management\registry\issued.json"
    if (Test-Path $registryPath) {
        $backupPath = "$backupDir\issued-$today.json"
        Copy-Item $registryPath $backupPath -Force
        Write-Host "✅ Registre sauvé: $backupPath" -ForegroundColor Green
        
        # Compresser anciens backups (>30 jours)
        $oldBackups = Get-ChildItem "$backupDir\issued-*.json" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
        if ($oldBackups) {
            Write-Host "🗜️ Compression backups anciens..." -ForegroundColor Gray
            Compress-Archive -Path $oldBackups.FullName -DestinationPath "$backupDir\archive-$today.zip" -Update
            $oldBackups | Remove-Item -Force
            Write-Host "✅ $($oldBackups.Count) anciens backups archivés" -ForegroundColor Green
        }
    } else {
        Write-Host "⚠️ Registre licences introuvable" -ForegroundColor Yellow
    }
    
    # 2. Backup configurations
    Write-Host "`n⚙️ Backup configurations..." -ForegroundColor White
    $configFiles = @(
        "package.json",
        "build-config.json", 
        "electron-builder.yml"
    )
    
    foreach ($config in $configFiles) {
        if (Test-Path $config) {
            Copy-Item $config "$backupDir\$config-$today" -Force
        }
    }
    Write-Host "✅ Configurations sauvées" -ForegroundColor Green
    
    # 3. Stats quotidiennes
    Write-Host "`n📊 Génération stats quotidiennes..." -ForegroundColor White
    $statsFile = "$backupDir\daily-stats-$today.txt"
    
    @"
USB Video Vault - Stats Quotidiennes
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
=====================================

Licences:
$(node tools/license-management/license-manager.mjs stats 2>$null)

Système:
- OS: $([System.Environment]::OSVersion.VersionString)
- PowerShell: $($PSVersionTable.PSVersion)
- Espace disque: $(Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3} | ForEach-Object {"$($_.DeviceID) $([math]::Round($_.FreeSpace/1GB,2))GB libre"})

Fichiers projet:
- Taille dist/: $(if(Test-Path "dist") { [math]::Round((Get-ChildItem "dist" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 2) } else { "N/A" }) MB
- Dernière build: $(if(Test-Path "dist\USB-Video-Vault-*.exe") { (Get-ChildItem "dist\USB-Video-Vault-*.exe" | Select-Object -First 1).LastWriteTime } else { "N/A" })

"@ | Out-File $statsFile -Encoding UTF8
    
    Write-Host "✅ Stats sauvées: $statsFile" -ForegroundColor Green
    Write-Host "✅ Backup quotidien terminé" -ForegroundColor Green
}

function Test-LicenseExpiry {
    Write-Host "`n⏰ === ALERTE EXPIRATION LICENCES ===" -ForegroundColor Magenta
    
    try {
        $licenseData = node tools/license-management/license-manager.mjs stats 2>$null
        if ($licenseData -match "expiring_soon:\s*([1-9]\d*)") {
            $count = $matches[1]
            Write-Host "🚨 ATTENTION: $count licence(s) expirent bientôt !" -ForegroundColor Red
            Write-Host ""
            Write-Host "📋 Actions requises:" -ForegroundColor Yellow
            Write-Host "   1. Identifier les clients concernés" -ForegroundColor White
            Write-Host "   2. Envoyer notification renouvellement" -ForegroundColor White
            Write-Host "   3. Préparer nouvelles licences si demandées" -ForegroundColor White
            Write-Host ""
            Write-Host "🔍 Commande détails: node tools/license-management/license-manager.mjs stats" -ForegroundColor Blue
            
            return $false  # Alerte active
        } else {
            Write-Host "✅ Aucune licence en expiration imminente" -ForegroundColor Green
            return $true   # Tout OK
        }
    } catch {
        Write-Host "❌ Erreur vérification expiration: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ===== EXECUTION =====

$allOK = $true

if ($Morning -or $All) {
    Start-MorningChecks
    $allOK = $allOK -and (Test-LicenseExpiry)
}

if ($Evening -or $All) {
    Start-EveningBackup
}

if (!$Morning -and !$Evening -and !$All) {
    Write-Host "💡 Usage:" -ForegroundColor Blue
    Write-Host "   .\daily-ops.ps1 -Morning     # Checks matinaux" -ForegroundColor White
    Write-Host "   .\daily-ops.ps1 -Evening     # Backup quotidien" -ForegroundColor White
    Write-Host "   .\daily-ops.ps1 -All         # Tout" -ForegroundColor White
    Write-Host ""
    Write-Host "📅 Programmation recommandée:" -ForegroundColor Yellow
    Write-Host "   9h00: .\daily-ops.ps1 -Morning" -ForegroundColor Gray
    Write-Host "   18h00: .\daily-ops.ps1 -Evening" -ForegroundColor Gray
}

Write-Host "`n📊 === RÉSUMÉ DAILY OPS ===" -ForegroundColor Cyan
if ($allOK) {
    Write-Host "✅ Toutes les opérations quotidiennes OK" -ForegroundColor Green
    Write-Host "🎯 Système opérationnel - Aucune action requise" -ForegroundColor Green
} else {
    Write-Host "⚠️ Alertes détectées - Actions requises" -ForegroundColor Yellow
    Write-Host "🔍 Consulter les détails ci-dessus" -ForegroundColor White
}

Write-Host "🕒 Fin des opérations: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray