# Script d'automatisation du runbook de deploiement
# Usage: .\deploy-first-public.ps1 -Version "0.1.5" -Phase "prep|verify|test|deploy|monitor"

param(
    [string]$Version = "0.1.5",
    [ValidateSet("prep", "verify", "test", "deploy", "monitor", "all")]
    [string]$Phase = "all",
    [switch]$Execute,
    [switch]$DryRun
)

Write-Host "=== DEPLOIEMENT PUBLIC v$Version ===" -ForegroundColor Magenta
Write-Host "Phase: $Phase" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "MODE DRY-RUN - Simulation uniquement" -ForegroundColor Yellow
    Write-Host ""
}

# Variables globales
$setupFileName = "USB Video Vault Setup $Version.exe"
$setupUrl = "https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v$Version/$setupFileName"
$logFile = ".\logs\deployment-v$Version.log"

# Fonction de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    if (-not (Test-Path (Split-Path $logFile -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $logFile -Parent) -Force | Out-Null
    }
    $logEntry | Out-File $logFile -Append -Encoding UTF8
}

# PHASE T-60: PREPARATION
function Start-PreparationPhase {
    Write-Host "🔧 T-60 min: PREPARATION" -ForegroundColor Yellow
    Write-Log "Debut phase preparation"
    
    # 1. Verification pre-requis
    Write-Host "  1. Verification GO/NO-GO..." -ForegroundColor Blue
    
    $checks = @(
        @{Name="Package.json"; Path=".\package.json"},
        @{Name="Build dist"; Path=".\dist"},
        @{Name="Winget manifest"; Path=".\packaging\winget"},
        @{Name="Chocolatey spec"; Path=".\packaging\chocolatey\usbvideovault.nuspec"}
    )
    
    $failed = @()
    foreach ($check in $checks) {
        if (Test-Path $check.Path) {
            Write-Host "    ✅ $($check.Name)" -ForegroundColor Green
            Write-Log "$($check.Name): OK"
        } else {
            Write-Host "    ❌ $($check.Name)" -ForegroundColor Red
            $failed += $check.Name
            Write-Log "$($check.Name): MISSING" "ERROR"
        }
    }
    
    if ($failed.Count -gt 0) {
        Write-Host "  ERREUR Pre-requis manquants: $($failed -join ', ')" -ForegroundColor Red
        return $false
    }
    
    # 2. Bump version si necessaire
    Write-Host "  2. Version check..." -ForegroundColor Blue
    $packageJson = Get-Content ".\package.json" | ConvertFrom-Json
    $currentVersion = $packageJson.version
    
    if ($currentVersion -ne $Version) {
        Write-Host "    Version actuelle: $currentVersion" -ForegroundColor Yellow
        Write-Host "    Version cible: $Version" -ForegroundColor Yellow
        
        if (-not $DryRun -and $Execute) {
            Write-Host "    Mise a jour version..." -ForegroundColor Blue
            npm version $Version --no-git-tag-version
            Write-Log "Version mise a jour: $currentVersion → $Version"
        } else {
            Write-Host "    [SIMULATION] npm version $Version" -ForegroundColor Gray
        }
    } else {
        Write-Host "    ✅ Version correcte: $Version" -ForegroundColor Green
    }
    
    # 3. Build final
    Write-Host "  3. Build final..." -ForegroundColor Blue
    if (-not $DryRun -and $Execute) {
        Write-Host "    Nettoyage + build complet..." -ForegroundColor Blue
        & npm run clean
        & npm run build
        & npm run electron:build
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✅ Build reussi" -ForegroundColor Green
            Write-Log "Build final: SUCCESS"
        } else {
            Write-Host "    ❌ Build echec" -ForegroundColor Red
            Write-Log "Build final: FAILED" "ERROR"
            return $false
        }
    } else {
        Write-Host "    [SIMULATION] npm run clean && npm run build && npm run electron:build" -ForegroundColor Gray
    }
    
    # 4. Commit + tag
    Write-Host "  4. Git release..." -ForegroundColor Blue
    if (-not $DryRun -and $Execute) {
        Write-Host "    Commit de release..." -ForegroundColor Blue
        git add -A
        git commit -m "chore(release): v$Version - Ready for public release"
        git tag "v$Version"
        git push origin master --tags
        Write-Log "Git release: Tag v$Version cree et pousse"
    } else {
        Write-Host "    [SIMULATION] git commit + tag v$Version + push" -ForegroundColor Gray
    }
    
    Write-Host "  ✅ Phase preparation terminee" -ForegroundColor Green
    return $true
}

# PHASE T-30: VERIFICATION ARTEFACTS
function Start-VerificationPhase {
    Write-Host "`n🔍 T-30 min: VERIFICATION ARTEFACTS" -ForegroundColor Yellow
    Write-Log "Debut phase verification"
    
    # Attendre que GitHub Actions termine
    Write-Host "  1. Attente GitHub Actions..." -ForegroundColor Blue
    Write-Host "    ⏳ Verifier manuellement: https://github.com/150781/Yindo-USB-Video-Vault/actions" -ForegroundColor Yellow
    
    # Tentative de telechargement
    Write-Host "  2. Telechargement setup signe..." -ForegroundColor Blue
    try {
        if (-not $DryRun) {
            Write-Host "    URL: $setupUrl" -ForegroundColor Gray
            Invoke-WebRequest -Uri $setupUrl -OutFile ".\$setupFileName" -ErrorAction Stop
            Write-Host "    ✅ Setup telecharge" -ForegroundColor Green
            Write-Log "Setup telecharge: $setupFileName"
        } else {
            Write-Host "    [SIMULATION] Download $setupUrl" -ForegroundColor Gray
        }
    } catch {
        Write-Host "    ❌ Echec telechargement: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Telechargement echec: $($_.Exception.Message)" "ERROR"
        return $false
    }
    
    # Verification signature
    if (Test-Path ".\$setupFileName") {
        Write-Host "  3. Verification signature..." -ForegroundColor Blue
        
        try {
            $signature = Get-AuthenticodeSignature ".\$setupFileName"
            Write-Host "    Status: $($signature.Status)" -ForegroundColor $(if($signature.Status -eq 'Valid'){'Green'}else{'Red'})
            
            if ($signature.SignerCertificate) {
                Write-Host "    Signer: $($signature.SignerCertificate.Subject.Split(',')[0])" -ForegroundColor Blue
                Write-Log "Signature verification: $($signature.Status)"
            }
            
            if ($signature.Status -ne 'Valid') {
                Write-Host "    ❌ Signature invalide - ARRETER DEPLOIEMENT" -ForegroundColor Red
                Write-Log "Signature invalide: $($signature.Status)" "ERROR"
                return $false
            }
        } catch {
            Write-Host "    ❌ Erreur verification signature: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "Erreur signature: $($_.Exception.Message)" "ERROR"
            return $false
        }
        
        # Calcul SHA256 reel
        Write-Host "  4. Calcul SHA256 reel..." -ForegroundColor Blue
        $realSha256 = (Get-FileHash ".\$setupFileName" -Algorithm SHA256).Hash
        Write-Host "    SHA256: $realSha256" -ForegroundColor Green
        Write-Log "SHA256 reel: $realSha256"
        
        # Sauvegarde pour manifests
        $realSha256 | Out-File ".\SHA256_REAL.txt" -Encoding ASCII
        Write-Host "    💾 SHA256 sauve dans SHA256_REAL.txt" -ForegroundColor Blue
    }
    
    Write-Host "  ✅ Phase verification terminee" -ForegroundColor Green
    return $true
}

# PHASE T-20: TESTS INSTALLATION
function Start-TestPhase {
    Write-Host "`n🧪 T-20 min: TESTS INSTALLATION" -ForegroundColor Yellow
    Write-Log "Debut phase tests"
    
    if (-not (Test-Path ".\$setupFileName")) {
        Write-Host "  ❌ Setup file non trouve pour tests" -ForegroundColor Red
        return $false
    }
    
    Write-Host "  Tests sur environnement courant..." -ForegroundColor Blue
    
    # Test 1: Installation silencieuse
    Write-Host "  1. Test installation silencieuse..." -ForegroundColor Blue
    if (-not $DryRun -and $Execute) {
        try {
            $installTime = Measure-Command {
                Start-Process ".\$setupFileName" -ArgumentList "/S" -Wait
            }
            Write-Host "    ✅ Installation OK en $([math]::Round($installTime.TotalSeconds,1))s" -ForegroundColor Green
            Write-Log "Installation test: SUCCESS ($([math]::Round($installTime.TotalSeconds,1))s)"
        } catch {
            Write-Host "    ❌ Installation echec: $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "Installation test: FAILED - $($_.Exception.Message)" "ERROR"
            return $false
        }
    } else {
        Write-Host "    [SIMULATION] Installation silencieuse" -ForegroundColor Gray
    }
    
    # Test 2: Verification installation
    Write-Host "  2. Verification installation..." -ForegroundColor Blue
    $installPath = "$env:ProgramFiles\USB Video Vault\USB Video Vault.exe"
    if (Test-Path $installPath) {
        Write-Host "    ✅ Application installee: $installPath" -ForegroundColor Green
        Write-Log "Verification installation: OK"
    } else {
        Write-Host "    ❌ Application non trouvee apres installation" -ForegroundColor Red
        Write-Log "Verification installation: FAILED" "ERROR"
        return $false
    }
    
    # Test 3: Lancement rapide
    Write-Host "  3. Test lancement application..." -ForegroundColor Blue
    if (-not $DryRun -and $Execute) {
        try {
            Start-Process $installPath -WindowStyle Minimized
            Start-Sleep 5
            $process = Get-Process "USB Video Vault" -ErrorAction SilentlyContinue
            if ($process) {
                Write-Host "    ✅ Application lance correctement" -ForegroundColor Green
                $process | Stop-Process -Force
                Write-Log "Test lancement: SUCCESS"
            } else {
                Write-Host "    ⚠️ Application non detectee (peut etre normal)" -ForegroundColor Yellow
                Write-Log "Test lancement: Process not found" "WARN"
            }
        } catch {
            Write-Host "    ⚠️ Erreur test lancement: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Log "Test lancement: ERROR - $($_.Exception.Message)" "WARN"
        }
    } else {
        Write-Host "    [SIMULATION] Lancement + verification process" -ForegroundColor Gray
    }
    
    Write-Host "  ✅ Phase tests terminee" -ForegroundColor Green
    return $true
}

# PHASE T-10: DEPLOIEMENT
function Start-DeployPhase {
    Write-Host "`n📦 T-10 min: DEPLOIEMENT MULTI-CANAUX" -ForegroundColor Yellow
    Write-Log "Debut phase deploiement"
    
    # 1. Finalisation GitHub Release
    Write-Host "  1. GitHub Release finalisation..." -ForegroundColor Blue
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        if (-not $DryRun -and $Execute) {
            try {
                # Upload assets supplementaires
                if (Test-Path ".\dist\SHA256SUMS") {
                    gh release upload "v$Version" ".\dist\SHA256SUMS"
                    Write-Host "    ✅ SHA256SUMS uploaded" -ForegroundColor Green
                }
                
                # Marquer comme latest
                gh release edit "v$Version" --latest
                Write-Host "    ✅ Release marquee latest" -ForegroundColor Green
                Write-Log "GitHub Release: Finalisee"
            } catch {
                Write-Host "    ⚠️ Erreur GitHub Release: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Log "GitHub Release: ERROR - $($_.Exception.Message)" "WARN"
            }
        } else {
            Write-Host "    [SIMULATION] Upload assets + mark latest" -ForegroundColor Gray
        }
    } else {
        Write-Host "    ⚠️ GitHub CLI non installe - actions manuelles requises" -ForegroundColor Yellow
    }
    
    # 2. Instructions Winget
    Write-Host "  2. Winget PR preparation..." -ForegroundColor Blue
    Write-Host "    📋 Actions manuelles Winget:" -ForegroundColor Yellow
    Write-Host "      1. Fork microsoft/winget-pkgs" -ForegroundColor White
    Write-Host "      2. Branch: yindo-usbvideovault-$Version" -ForegroundColor White
    Write-Host "      3. Mettre SHA256 reel dans installer.yaml" -ForegroundColor White
    Write-Host "      4. PR: 'New version: Yindo.USBVideoVault version $Version'" -ForegroundColor White
    
    if (Test-Path ".\SHA256_REAL.txt") {
        $realSha = Get-Content ".\SHA256_REAL.txt"
        Write-Host "      SHA256 a utiliser: $realSha" -ForegroundColor Cyan
    }
    
    # 3. Instructions Chocolatey
    Write-Host "  3. Chocolatey package..." -ForegroundColor Blue
    if (Test-Path ".\packaging\chocolatey\usbvideovault.nuspec") {
        Write-Host "    📋 Actions Chocolatey:" -ForegroundColor Yellow
        Write-Host "      1. Mettre SHA256 reel dans chocolateyinstall.ps1" -ForegroundColor White
        Write-Host "      2. choco pack .\packaging\chocolatey\usbvideovault.nuspec" -ForegroundColor White
        Write-Host "      3. choco push usbvideovault.$Version.nupkg --api-key <KEY>" -ForegroundColor White
    }
    
    Write-Host "  ✅ Phase deploiement preparee" -ForegroundColor Green
    return $true
}

# PHASE T+0: MONITORING
function Start-MonitoringPhase {
    Write-Host "`n📊 T+0: MONITORING INTENSIF (60 min)" -ForegroundColor Yellow
    Write-Log "Debut phase monitoring"
    
    Write-Host "  1. Demarrage monitoring automatique..." -ForegroundColor Blue
    if (-not $DryRun -and $Execute) {
        if (Test-Path ".\tools\monitor-release.ps1") {
            Start-Process PowerShell -ArgumentList "-File", ".\tools\monitor-release.ps1", "-Version", $Version, "-Hours", "1" -WindowStyle Minimized
            Write-Host "    ✅ Monitoring 60min demarre" -ForegroundColor Green
            Write-Log "Monitoring automatique: STARTED (60min)"
        } else {
            Write-Host "    ⚠️ Script monitor-release.ps1 non trouve" -ForegroundColor Yellow
        }
    } else {
        Write-Host "    [SIMULATION] Monitor 60min en arriere-plan" -ForegroundColor Gray
    }
    
    Write-Host "  2. Points de surveillance manuelle..." -ForegroundColor Blue
    Write-Host "    📊 GitHub Release: https://github.com/150781/Yindo-USB-Video-Vault/releases/tag/v$Version" -ForegroundColor Cyan
    Write-Host "    📊 Issues: https://github.com/150781/Yindo-USB-Video-Vault/issues" -ForegroundColor Cyan
    Write-Host "    📊 Actions: https://github.com/150781/Yindo-USB-Video-Vault/actions" -ForegroundColor Cyan
    
    Write-Host "  3. Seuils critiques rollback..." -ForegroundColor Blue
    Write-Host "    🚨 Echec installation > 3%" -ForegroundColor Red
    Write-Host "    🚨 Crashes recurrents au demarrage" -ForegroundColor Red
    Write-Host "    🚨 Probleme signature/certificat" -ForegroundColor Red
    Write-Host "    ⚠️ SmartScreen warnings (normal avec OV)" -ForegroundColor Yellow
    
    Write-Host "  4. Commande rollback d'urgence..." -ForegroundColor Blue
    Write-Host "    .\tools\emergency-rollback.ps1 -FromVersion '$Version' -ToVersion '0.1.4' -Execute" -ForegroundColor Red
    
    Write-Host "  ✅ Monitoring en cours - Surveiller 60 minutes" -ForegroundColor Green
    return $true
}

# EXECUTION PRINCIPALE
Write-Log "Debut deploiement v$Version - Phase: $Phase"

$success = $true

if ($Phase -eq "all" -or $Phase -eq "prep") {
    $success = $success -and (Start-PreparationPhase)
}

if (($Phase -eq "all" -or $Phase -eq "verify") -and $success) {
    Write-Host "`n⏳ Attendre completion GitHub Actions avant phase verification..." -ForegroundColor Yellow
    if ($Phase -eq "verify") {
        # Pause pour verification manuelle GitHub Actions
        Read-Host "Appuyer Enter quand GitHub Actions est termine"
    }
    $success = $success -and (Start-VerificationPhase)
}

if (($Phase -eq "all" -or $Phase -eq "test") -and $success) {
    $success = $success -and (Start-TestPhase)
}

if (($Phase -eq "all" -or $Phase -eq "deploy") -and $success) {
    $success = $success -and (Start-DeployPhase)
}

if (($Phase -eq "all" -or $Phase -eq "monitor") -and $success) {
    $success = $success -and (Start-MonitoringPhase)
}

# RAPPORT FINAL
Write-Host "`n=== DEPLOIEMENT $(if($success){'REUSSI'}else{'ECHEC'}) ===" -ForegroundColor $(if($success){'Green'}else{'Red'})
Write-Host "Version: $Version" -ForegroundColor Cyan
Write-Host "Phase: $Phase" -ForegroundColor Cyan
Write-Host "Log: $logFile" -ForegroundColor Cyan

if ($success) {
    Write-Host "🚀 PREMIER DEPLOIEMENT PUBLIC EN COURS!" -ForegroundColor Green
    Write-Host "📊 Surveiller monitoring pendant 60 minutes critiques" -ForegroundColor Yellow
} else {
    Write-Host "❌ DEPLOIEMENT INTERROMPU - Verifier logs et corriger" -ForegroundColor Red
}

Write-Log "Deploiement termine - Success: $success"