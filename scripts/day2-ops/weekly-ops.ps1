# 📅 Weekly Security & Maintenance Script
# Tests sécurité hebdomadaires + audit santé système

param(
    [Parameter(Mandatory=$false)]
    [switch]$SecurityOnly = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$ReportsOnly = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$All = $true
)

$ErrorActionPreference = "Continue"

Write-Host "📅 === WEEKLY OPS - Sécurité & Maintenance ===" -ForegroundColor Cyan
Write-Host "🗓️ Semaine du: $(Get-Date -Format 'yyyy-MM-dd')" -ForegroundColor Gray

function Test-WeeklySecurity {
    Write-Host "`n🔒 === TESTS SÉCURITÉ HEBDOMADAIRES ===" -ForegroundColor Red
    
    $securityPassed = $true
    
    # 1. Tests scénarios rouges (échecs attendus)
    Write-Host "🔴 Tests scénarios rouges..." -ForegroundColor Yellow
    try {
        $redTestOutput = node test-red-scenarios.mjs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Tous les scénarios d'attaque sont bloqués" -ForegroundColor Green
            Write-Host "🛡️ Sécurité validée" -ForegroundColor Green
        } else {
            Write-Host "❌ ALERTE: Tests rouges échoués !" -ForegroundColor Red
            Write-Host $redTestOutput -ForegroundColor Red
            $securityPassed = $false
            
            # Alerter équipe sécurité
            Write-Host "🚨 ACTION CRITIQUE: Notifier équipe sécurité immédiatement" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Erreur exécution tests rouges: $($_.Exception.Message)" -ForegroundColor Red
        $securityPassed = $false
    }
    
    # 2. Scan APIs crypto dépréciées
    Write-Host "`n🔍 Scan APIs crypto dépréciées..." -ForegroundColor Yellow
    try {
        $deprecatedAPIs = git grep -r "createCipher\|createDecipher\|crypto\.createHash\('md5'\)" src/ 2>$null
        if ($deprecatedAPIs) {
            Write-Host "❌ APIs crypto dépréciées détectées:" -ForegroundColor Red
            $deprecatedAPIs | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
            $securityPassed = $false
            
            Write-Host "🔧 ACTION REQUISE: Remplacer par APIs modernes" -ForegroundColor Yellow
        } else {
            Write-Host "✅ Aucune API crypto dépréciée trouvée" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️ Git grep non disponible - vérification manuelle requise" -ForegroundColor Yellow
    }
    
    # 3. Audit dépendances npm
    Write-Host "`n📦 Audit dépendances npm..." -ForegroundColor Yellow
    try {
        $auditOutput = npm audit --audit-level=high 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Aucune vulnérabilité critique détectée" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Vulnérabilités détectées:" -ForegroundColor Yellow
            Write-Host $auditOutput -ForegroundColor Yellow
            Write-Host "🔧 ACTION: Review et mise à jour requises" -ForegroundColor Blue
            
            # Pas critique mais à surveiller
        }
    } catch {
        Write-Host "❌ Erreur audit npm: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # 4. Vérification intégrité builds
    Write-Host "`n🔍 Vérification intégrité builds..." -ForegroundColor Yellow
    
    $buildFiles = Get-ChildItem "dist\USB-Video-Vault-*.exe" -ErrorAction SilentlyContinue
    if ($buildFiles) {
        foreach ($build in $buildFiles) {
            # Hash SHA256
            $hash = (certutil -hashfile $build.FullName SHA256 | Select-String -Pattern "^[0-9a-f]{64}$").Line
            Write-Host "📊 $($build.Name): $hash" -ForegroundColor Gray
            
            # Vérifier signature si présente
            try {
                $sig = Get-AuthenticodeSignature $build.FullName
                if ($sig.Status -eq "Valid") {
                    Write-Host "✅ Signature valide" -ForegroundColor Green
                } elseif ($sig.Status -eq "NotSigned") {
                    Write-Host "ℹ️ Non signé (normal en dev)" -ForegroundColor Gray
                } else {
                    Write-Host "⚠️ Signature invalide: $($sig.Status)" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "⚠️ Erreur vérification signature" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "ℹ️ Aucun build trouvé dans dist/" -ForegroundColor Gray
    }
    
    return $securityPassed
}

function New-WeeklyReports {
    Write-Host "`n📊 === RAPPORTS HEBDOMADAIRES ===" -ForegroundColor Blue
    
    $weekNumber = Get-Date -UFormat %V
    $year = Get-Date -Format yyyy
    $reportDate = Get-Date -Format "yyyy-MM-dd"
    
    # Créer dossier rapports
    $reportsDir = "reports\weekly"
    if (!(Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
    }
    
    # 1. Rapport licences
    Write-Host "📋 Génération rapport licences..." -ForegroundColor White
    $licenseReport = "$reportsDir\licenses-week$weekNumber-$year.txt"
    
    $licenseStats = node tools/license-management/license-manager.mjs stats 2>$null
    @"
=== RAPPORT LICENCES HEBDOMADAIRE ===
Semaine: $weekNumber/$year
Date: $reportDate

STATISTIQUES:
$licenseStats

ACTIONS REQUISES:
$(if ($licenseStats -match "expiring_soon:\s*([1-9]\d*)") { "⚠️ $($matches[1]) licence(s) expirent bientôt - Contacter clients" } else { "✅ Aucune action licence requise" })

HEALTH CHECK:
$(if ($licenseStats -match "active:\s*(\d+)") { "📈 $($matches[1]) licences actives" } else { "❓ Stats licences indisponibles" })
$(if ($licenseStats -match "revoked:\s*([1-9]\d*)") { "🚫 $($matches[1]) licence(s) révoquée(s)" } else { "✅ Aucune révocation" })

"@ | Out-File $licenseReport -Encoding UTF8
    
    Write-Host "✅ Rapport licences: $licenseReport" -ForegroundColor Green
    
    # 2. Rapport système
    Write-Host "💻 Génération rapport système..." -ForegroundColor White
    $systemReport = "$reportsDir\system-week$weekNumber-$year.txt"
    
    $diskInfo = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3} | 
                ForEach-Object {"$($_.DeviceID) $([math]::Round($_.FreeSpace/1GB,2))GB libre / $([math]::Round($_.Size/1GB,2))GB total"}
    
    @"
=== RAPPORT SYSTÈME HEBDOMADAIRE ===
Semaine: $weekNumber/$year  
Date: $reportDate

ENVIRONNEMENT:
- OS: $([System.Environment]::OSVersion.VersionString)
- PowerShell: $($PSVersionTable.PSVersion)
- Node.js: $(node --version 2>$null)
- NPM: $(npm --version 2>$null)

STOCKAGE:
$($diskInfo -join "`n")

PROJET:
- Dernière build: $(if(Test-Path "dist\USB-Video-Vault-*.exe") { (Get-ChildItem "dist\USB-Video-Vault-*.exe" | Select-Object -First 1).LastWriteTime } else { "Aucune" })
- Taille dist/: $(if(Test-Path "dist") { [math]::Round((Get-ChildItem "dist" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 2) } else { "0" }) MB
- Dernière MAJ code: $(git log -1 --format="%cd" --date=short 2>$null)

BACKUPS:
- Backups quotidiens: $(if(Test-Path "backups") { (Get-ChildItem "backups\issued-*.json" | Measure-Object).Count } else { "0" }) fichiers
- Dernière sauvegarde: $(if(Test-Path "backups") { (Get-ChildItem "backups\issued-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime } else { "Jamais" })

"@ | Out-File $systemReport -Encoding UTF8
    
    Write-Host "✅ Rapport système: $systemReport" -ForegroundColor Green
    
    # 3. Rapport sécurité
    Write-Host "🔒 Génération rapport sécurité..." -ForegroundColor White
    $securityReport = "$reportsDir\security-week$weekNumber-$year.txt"
    
    $redTestResult = if (Test-Path "test-red-scenarios.mjs") { 
        try { 
            node test-red-scenarios.mjs 2>&1 | Out-String 
        } catch { 
            "Erreur exécution tests rouges" 
        }
    } else { 
        "Script tests rouges non trouvé" 
    }
    
    @"
=== RAPPORT SÉCURITÉ HEBDOMADAIRE ===
Semaine: $weekNumber/$year
Date: $reportDate

TESTS SCÉNARIOS ROUGES:
$redTestResult

AUDIT DÉPENDANCES:
$(npm audit --audit-level=moderate 2>&1 | Out-String)

RECOMMENDATIONS:
- ✅ Effectuer tests sécurité hebdomadaires
- ✅ Maintenir dépendances à jour
- ✅ Surveiller CVE nouvelles
- ✅ Backup sécurité KEK mensuel

"@ | Out-File $securityReport -Encoding UTF8
    
    Write-Host "✅ Rapport sécurité: $securityReport" -ForegroundColor Green
}

function Test-LicenseHealth {
    Write-Host "`n🔑 === HEALTH CHECK LICENCES ===" -ForegroundColor Magenta
    
    try {
        $stats = node tools/license-management/license-manager.mjs stats 2>$null
        
        if ($stats) {
            Write-Host "📊 Statistiques licences actuelles:" -ForegroundColor White
            Write-Host $stats
            
            # Alertes
            $alerts = @()
            
            if ($stats -match "expiring_soon:\s*([1-9]\d*)") {
                $alerts += "⚠️ $($matches[1]) licence(s) expirent dans 7 jours"
            }
            
            if ($stats -match "expired:\s*([1-9]\d*)") {
                $alerts += "🚫 $($matches[1]) licence(s) expirée(s)"
            }
            
            if ($stats -match "revoked:\s*([1-9]\d*)") {
                $alerts += "❌ $($matches[1]) licence(s) révoquée(s)"
            }
            
            if ($alerts) {
                Write-Host "`n🚨 Alertes détectées:" -ForegroundColor Yellow
                $alerts | ForEach-Object { Write-Host "   $_" -ForegroundColor Yellow }
            } else {
                Write-Host "✅ Toutes les licences sont en bon état" -ForegroundColor Green
            }
        } else {
            Write-Host "⚠️ Impossible de récupérer les stats licences" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ Erreur health check licences: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ===== EXECUTION =====

$overallSuccess = $true

Write-Host "🎯 Mode exécution: $(if($SecurityOnly){'Sécurité uniquement'}elseif($ReportsOnly){'Rapports uniquement'}else{'Complet'})" -ForegroundColor Cyan

if ($SecurityOnly -or $All) {
    $securityPassed = Test-WeeklySecurity
    $overallSuccess = $overallSuccess -and $securityPassed
    
    Test-LicenseHealth
}

if ($ReportsOnly -or $All) {
    New-WeeklyReports
}

Write-Host "`n📊 === RÉSUMÉ WEEKLY OPS ===" -ForegroundColor Cyan

if ($overallSuccess) {
    Write-Host "✅ Toutes les opérations hebdomadaires réussies" -ForegroundColor Green
    Write-Host "🛡️ Sécurité: VALIDÉE" -ForegroundColor Green
    Write-Host "📊 Rapports: GÉNÉRÉS" -ForegroundColor Green
    Write-Host "🎯 Système: OPÉRATIONNEL" -ForegroundColor Green
} else {
    Write-Host "⚠️ Alertes sécurité détectées" -ForegroundColor Red
    Write-Host "🚨 ACTIONS REQUISES - Consulter détails ci-dessus" -ForegroundColor Red
    Write-Host "📞 Notifier équipe sécurité si critique" -ForegroundColor Yellow
}

Write-Host "`n📅 Prochaine exécution recommandée: $(Get-Date (Get-Date).AddDays(7) -Format 'yyyy-MM-dd (dddd)')" -ForegroundColor Blue
Write-Host "🕒 Fin weekly ops: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray