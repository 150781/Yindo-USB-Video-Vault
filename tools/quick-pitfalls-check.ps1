# CHECKLIST ULTRA-RAPIDE - Pièges courants avant déploiement
# Usage: .\quick-pitfalls-check.ps1 -Version "0.1.5"

param([string]$Version = "0.1.5")

Write-Host "🚨 PIÈGES COURANTS - CHECK RAPIDE" -ForegroundColor Red
Write-Host "Version: $Version" -ForegroundColor Cyan
Write-Host ""

$pitfalls = @()

# PIÈGE 1: Version incohérente
Write-Host "1. 🏷️ Cohérence versions..." -ForegroundColor Yellow

$versionFiles = @(
    @{File="package.json"; Pattern='"version":\s*"([^"]+)"'},
    @{File="src\main\main.ts"; Pattern='version:\s*[''"]([^''"]+)[''"]'},
    @{File="packaging\winget\Yindo.USBVideoVault.yaml"; Pattern='PackageVersion:\s*(.+)'},
    @{File="packaging\chocolatey\usbvideovault.nuspec"; Pattern='<version>([^<]+)</version>'}
)

$versionMismatches = @()
foreach ($vf in $versionFiles) {
    if (Test-Path $vf.File) {
        $content = Get-Content $vf.File -Raw
        if ($content -match $vf.Pattern) {
            $foundVersion = $matches[1].Trim()
            if ($foundVersion -ne $Version) {
                $versionMismatches += "$($vf.File): $foundVersion (attendu: $Version)"
            }
        } else {
            $versionMismatches += "$($vf.File): pattern non trouvé"
        }
    } else {
        $versionMismatches += "$($vf.File): fichier manquant"
    }
}

if ($versionMismatches.Count -eq 0) {
    Write-Host "   ✅ Versions cohérentes" -ForegroundColor Green
} else {
    Write-Host "   ❌ VERSIONS INCOHÉRENTES:" -ForegroundColor Red
    $versionMismatches | ForEach-Object { Write-Host "     $_" -ForegroundColor White }
    $pitfalls += "CRITIQUE: Versions incohérentes détectées"
}

# PIÈGE 2: SHA256 placeholder
Write-Host "2. #️⃣ SHA256 placeholders..." -ForegroundColor Yellow

$sha256Files = @(
    "packaging\winget\installer.yaml",
    "packaging\chocolatey\chocolateyinstall.ps1"
)

$sha256Issues = @()
foreach ($file in $sha256Files) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        if ($content -match "InstallerSha256:\s*YOUR_SHA256_HERE" -or $content -match "checksum\s*=\s*['""]YOUR_SHA256_HERE['""]") {
            $sha256Issues += $file
        }
    }
}

if ($sha256Issues.Count -eq 0) {
    Write-Host "   ✅ SHA256 à jour ou inexistants" -ForegroundColor Green
} else {
    Write-Host "   ⚠️ SHA256 placeholders détectés:" -ForegroundColor Yellow
    $sha256Issues | ForEach-Object { Write-Host "     $_" -ForegroundColor White }
    Write-Host "     (Normal avant build signé final)" -ForegroundColor Gray
}

# PIÈGE 3: Secrets GitHub manquants
Write-Host "3. 🔐 Secrets GitHub..." -ForegroundColor Yellow

$secretsFile = ".github\workflows\release.yml"
if (Test-Path $secretsFile) {
    $workflowContent = Get-Content $secretsFile -Raw
    $requiredSecrets = @("WINDOWS_CERT_BASE64", "WINDOWS_CERT_PASSWORD", "GITHUB_TOKEN")
    
    $missingSecrets = @()
    foreach ($secret in $requiredSecrets) {
        if ($workflowContent -notmatch "secrets\.$secret") {
            $missingSecrets += $secret
        }
    }
    
    if ($missingSecrets.Count -eq 0) {
        Write-Host "   ✅ Secrets référencés dans workflow" -ForegroundColor Green
        Write-Host "     (Verifier manuellement leur configuration sur GitHub)" -ForegroundColor Gray
    } else {
        Write-Host "   ❌ Secrets manquants dans workflow:" -ForegroundColor Red
        $missingSecrets | ForEach-Object { Write-Host "     $_" -ForegroundColor White }
        $pitfalls += "CRITIQUE: Secrets GitHub non référencés"
    }
} else {
    Write-Host "   ❌ Workflow GitHub Actions manquant" -ForegroundColor Red
    $pitfalls += "CRITIQUE: Workflow release.yml manquant"
}

# PIÈGE 4: Build artifacts taille
Write-Host "4. 📦 Build artifacts..." -ForegroundColor Yellow

$setupFile = "dist\USB Video Vault Setup $Version.exe"
$portableFile = "dist\USB Video Vault $Version.exe"

$sizeIssues = @()
if (Test-Path $setupFile) {
    $sizeMB = [math]::Round((Get-Item $setupFile).Length / 1MB, 1)
    if ($sizeMB -lt 50) {
        $sizeIssues += "Setup trop petit: ${sizeMB}MB (attendu >50MB)"
    } elseif ($sizeMB -gt 500) {
        $sizeIssues += "Setup trop gros: ${sizeMB}MB (attendu <500MB)"
    } else {
        Write-Host "   ✅ Setup size OK: ${sizeMB}MB" -ForegroundColor Green
    }
} else {
    $sizeIssues += "Setup file manquant: $setupFile"
}

if (Test-Path $portableFile) {
    $sizeMB = [math]::Round((Get-Item $portableFile).Length / 1MB, 1)
    if ($sizeMB -lt 40) {
        $sizeIssues += "Portable trop petit: ${sizeMB}MB (attendu >40MB)"
    } elseif ($sizeMB -gt 400) {
        $sizeIssues += "Portable trop gros: ${sizeMB}MB (attendu <400MB)"
    } else {
        Write-Host "   ✅ Portable size OK: ${sizeMB}MB" -ForegroundColor Green
    }
} else {
    $sizeIssues += "Portable file manquant: $portableFile"
}

if ($sizeIssues.Count -gt 0) {
    Write-Host "   ❌ Problèmes build artifacts:" -ForegroundColor Red
    $sizeIssues | ForEach-Object { Write-Host "     $_" -ForegroundColor White }
    $pitfalls += "Build artifacts problématiques"
}

# PIÈGE 5: Node_modules et cache
Write-Host "5. 🗂️ Cache et dépendances..." -ForegroundColor Yellow

$cacheIssues = @()

# Vérifier node_modules récent
if (Test-Path "node_modules") {
    $nodeModulesAge = (Get-Date) - (Get-Item "node_modules").LastWriteTime
    if ($nodeModulesAge.TotalDays -gt 7) {
        $cacheIssues += "node_modules vieux de $([int]$nodeModulesAge.TotalDays) jours"
    }
} else {
    $cacheIssues += "node_modules manquant - npm install requis"
}

# Vérifier package-lock.json
if (-not (Test-Path "package-lock.json")) {
    $cacheIssues += "package-lock.json manquant - versions instables"
}

# Vérifier cache electron
$electronCacheSize = 0
if (Test-Path "$env:LOCALAPPDATA\electron\Cache") {
    $electronCacheSize = (Get-ChildItem "$env:LOCALAPPDATA\electron\Cache" -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    if ($electronCacheSize -gt 1000) {
        $cacheIssues += "Cache Electron volumineux: $([int]$electronCacheSize)MB"
    }
}

if ($cacheIssues.Count -eq 0) {
    Write-Host "   ✅ Dépendances et cache OK" -ForegroundColor Green
} else {
    Write-Host "   ⚠️ Problèmes cache/dépendances:" -ForegroundColor Yellow
    $cacheIssues | ForEach-Object { Write-Host "     $_" -ForegroundColor White }
}

# PIÈGE 6: Firewall/Antivirus
Write-Host "6. 🛡️ Sécurité locale..." -ForegroundColor Yellow

$securityWarnings = @()

# Test Windows Defender
try {
    $defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($defenderStatus.RealTimeProtectionEnabled) {
        $securityWarnings += "Windows Defender actif - possibles faux positifs"
    }
} catch {
    # Silencieusement ignorer si Get-MpComputerStatus n'est pas disponible
}

# Test répertoire dans exclusions (approximatif)
$currentDir = Get-Location
if ($currentDir.Path -like "*node_modules*" -or $currentDir.Path -like "*AppData*") {
    $securityWarnings += "Répertoire suspect pour antivirus: $($currentDir.Path)"
}

if ($securityWarnings.Count -eq 0) {
    Write-Host "   ✅ Pas d'alertes sécurité détectées" -ForegroundColor Green
} else {
    Write-Host "   ⚠️ Alertes sécurité:" -ForegroundColor Yellow
    $securityWarnings | ForEach-Object { Write-Host "     $_" -ForegroundColor White }
}

# RÉSUMÉ FINAL
Write-Host "`n🎯 RÉSUMÉ PIÈGES" -ForegroundColor Cyan

if ($pitfalls.Count -eq 0) {
    Write-Host "✅ Aucun piège critique détecté" -ForegroundColor Green
    Write-Host "🚀 Vous pouvez procéder au déploiement" -ForegroundColor Green
} else {
    Write-Host "❌ PIÈGES DÉTECTÉS:" -ForegroundColor Red
    for ($i = 0; $i -lt $pitfalls.Count; $i++) {
        Write-Host "   $($i+1). $($pitfalls[$i])" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "🛑 CORRIGEZ CES PROBLÈMES AVANT DÉPLOIEMENT" -ForegroundColor Red
}

Write-Host "`n💡 Actions suivantes recommandées:" -ForegroundColor Blue
Write-Host "   1. .\tools\check-go-nogo.ps1 -Version '$Version' -Detailed" -ForegroundColor White
Write-Host "   2. .\tools\final-vm-tests.ps1 (si disponible)" -ForegroundColor White  
Write-Host "   3. .\tools\deploy-first-public.ps1 -Version '$Version'" -ForegroundColor White

return $pitfalls.Count