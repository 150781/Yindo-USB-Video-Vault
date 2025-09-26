# Script de test scenario reel telechargement avec MOTW/SmartScreen
# Usage: .\tools\test-real-download.ps1 -Version "0.1.5" [-CleanVM] [-SkipUnblock]

param(
    [string]$Version = "0.1.5",
    [switch]$CleanVM,
    [switch]$SkipUnblock
)

Write-Host "=== TEST SCENARIO REEL TELECHARGEMENT v$Version ===" -ForegroundColor Cyan
Write-Host ""

# Configuration
$releaseUrl = "https://github.com/150781/Yindo-USB-Video-Vault/releases/tag/v$Version"
$setupFileName = "USB Video Vault Setup $Version.exe"
$downloadUrl = "https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v$Version/$([uri]::EscapeDataString($setupFileName))"
$testDir = "$env:USERPROFILE\Downloads\USB-Video-Vault-Test"
$setupPath = "$testDir\$setupFileName"

Write-Host "Configuration test:" -ForegroundColor Yellow
Write-Host "  Release: $releaseUrl" -ForegroundColor White
Write-Host "  Setup: $setupFileName" -ForegroundColor White
Write-Host "  Dossier test: $testDir" -ForegroundColor White
Write-Host ""

# Preparation dossier test
if (Test-Path $testDir) {
    Write-Host "Nettoyage dossier test existant..." -ForegroundColor Gray
    Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $testDir -Force | Out-Null
Write-Host "Dossier test cree: $testDir" -ForegroundColor Green

# ETAPE 1: Telechargement reel depuis GitHub
Write-Host ""
Write-Host "1. TELECHARGEMENT REEL..." -ForegroundColor Yellow
Write-Host "  URL: $downloadUrl" -ForegroundColor White

try {
    Write-Host "  Telechargement en cours..." -ForegroundColor Gray

    # Utiliser WebClient pour simuler un telechargement navigateur
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
    $webClient.DownloadFile($downloadUrl, $setupPath)

    if (Test-Path $setupPath) {
        $fileSize = [math]::Round((Get-Item $setupPath).Length / 1MB, 2)
        Write-Host "  SUCCES: Setup telecharge (${fileSize}MB)" -ForegroundColor Green
    } else {
        Write-Host "  ECHEC: Fichier non trouve apres telechargement" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ERREUR telechargement: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Verifier que la release v$Version existe et est publique" -ForegroundColor Yellow
    exit 1
}

# ETAPE 2: Verification MOTW (Mark of the Web)
Write-Host ""
Write-Host "2. VERIFICATION MOTW..." -ForegroundColor Yellow

try {
    # Lire les Alternate Data Streams pour detecter MOTW
    $adsInfo = Get-Item $setupPath -Stream * -ErrorAction SilentlyContinue
    $hasMotw = $adsInfo | Where-Object { $_.Stream -eq "Zone.Identifier" }

    if ($hasMotw) {
        Write-Host "  MOTW PRESENT - Fichier marque comme telecharge d'Internet" -ForegroundColor Green

        # Lire le contenu MOTW
        $motwContent = Get-Content "$setupPath`:Zone.Identifier" -ErrorAction SilentlyContinue
        if ($motwContent) {
            Write-Host "  Contenu MOTW:" -ForegroundColor Gray
            $motwContent | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
    } else {
        Write-Host "  MOTW ABSENT - SmartScreen peut ne pas s'activer" -ForegroundColor Yellow
        Write-Host "  Note: Certains outils de telechargement ne preservent pas MOTW" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Erreur verification MOTW: $($_.Exception.Message)" -ForegroundColor Red
}

# ETAPE 3: Test SmartScreen (sans deblocage)
if (-not $SkipUnblock) {
    Write-Host ""
    Write-Host "3. TEST SMARTSCREEN AUTHENTIQUE..." -ForegroundColor Yellow
    Write-Host "  Execution du setup WITH SmartScreen..." -ForegroundColor White

    try {
        # Tentative execution avec SmartScreen actif
        Write-Host "  Lancement: $setupPath" -ForegroundColor Gray
        Write-Host "  ATTENTION: SmartScreen peut bloquer l'execution" -ForegroundColor Yellow
        Write-Host "  Resultat attendu: Alerte 'Windows a protege votre PC'" -ForegroundColor Yellow

        # Lancement en arriere-plan pour eviter blocage
        $process = Start-Process -FilePath $setupPath -ArgumentList "/?" -PassThru -ErrorAction SilentlyContinue

        if ($process) {
            Write-Host "  Processus lance (PID: $($process.Id))" -ForegroundColor Green
            Start-Sleep -Seconds 2

            if (-not $process.HasExited) {
                Write-Host "  Processus actif - SmartScreen peut avoir affiche alerte" -ForegroundColor Yellow
                $process.Kill()
            } else {
                Write-Host "  Processus termine rapidement (exit code: $($process.ExitCode))" -ForegroundColor Gray
            }
        } else {
            Write-Host "  SmartScreen a probablement bloque l'execution" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Erreur execution: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Ceci peut indiquer un blocage SmartScreen" -ForegroundColor Yellow
    }
}

# ETAPE 4: Deblocage et test propre
Write-Host ""
Write-Host "4. DEBLOCAGE ET TEST PROPRE..." -ForegroundColor Yellow

try {
    # Debloquer le fichier pour tests subsequents
    Write-Host "  Deblocage du fichier..." -ForegroundColor Gray
    Unblock-File $setupPath -ErrorAction Stop

    Write-Host "  Fichier debloque avec succes" -ForegroundColor Green

    # Verification suppression MOTW
    $adsAfter = Get-Item $setupPath -Stream * -ErrorAction SilentlyContinue
    $hasMotwAfter = $adsAfter | Where-Object { $_.Stream -eq "Zone.Identifier" }

    if (-not $hasMotwAfter) {
        Write-Host "  MOTW supprime - SmartScreen desactive pour ce fichier" -ForegroundColor Green
    } else {
        Write-Host "  MOTW toujours present - deblocage partiel" -ForegroundColor Yellow
    }

} catch {
    Write-Host "  Erreur deblocage: $($_.Exception.Message)" -ForegroundColor Red
}

# ETAPE 5: Verification signature post-telechargement
Write-Host ""
Write-Host "5. VERIFICATION SIGNATURE POST-TELECHARGEMENT..." -ForegroundColor Yellow

try {
    $signature = Get-AuthenticodeSignature $setupPath -ErrorAction SilentlyContinue

    if ($signature -and $signature.Status -eq "Valid") {
        Write-Host "  Signature: VALIDE" -ForegroundColor Green
        Write-Host "  Certificat: $($signature.SignerCertificate.Subject.Split(',')[0])" -ForegroundColor Gray

        if ($signature.TimeStamperCertificate) {
            Write-Host "  Horodatage: PRESENT" -ForegroundColor Green
        } else {
            Write-Host "  Horodatage: MANQUANT" -ForegroundColor Red
        }
    } else {
        Write-Host "  Signature: INVALIDE ou MANQUANTE" -ForegroundColor Red
        if ($signature) {
            Write-Host "  Status: $($signature.Status)" -ForegroundColor White
        }
    }
} catch {
    Write-Host "  Erreur verification signature: $($_.Exception.Message)" -ForegroundColor Red
}

# ETAPE 6: Test execution debloquee
Write-Host ""
Write-Host "6. TEST EXECUTION DEBLOQUEE..." -ForegroundColor Yellow

try {
    Write-Host "  Test parametres ligne de commande..." -ForegroundColor Gray

    # Test avec parametres help
    $result = & $setupPath "/?" 2>&1
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) {
        Write-Host "  Execution reussie - setup repond aux parametres" -ForegroundColor Green
    } else {
        Write-Host "  Execution echouee (exit code: $LASTEXITCODE)" -ForegroundColor Red
    }

} catch {
    Write-Host "  Erreur test execution: $($_.Exception.Message)" -ForegroundColor Red
}

# RAPPORT FINAL
Write-Host ""
Write-Host "=== RAPPORT TEST TELECHARGEMENT ===" -ForegroundColor Cyan

$testResults = @{
    "Telechargement" = (Test-Path $setupPath)
    "MOTW_Present" = $hasMotw -ne $null
    "Signature_Valide" = $signature -and $signature.Status -eq "Valid"
    "Horodatage_Present" = $signature -and $signature.TimeStamperCertificate
    "Execution_OK" = $LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1
}

foreach ($test in $testResults.GetEnumerator()) {
    $status = if ($test.Value) { "OK" } else { "ECHEC" }
    $color = if ($test.Value) { "Green" } else { "Red" }
    Write-Host "$($test.Key): $status" -ForegroundColor $color
}

Write-Host ""
if ($CleanVM) {
    Write-Host "RECOMMANDATION VM PROPRE:" -ForegroundColor Blue
    Write-Host "  1. Installer sur VM Windows 10/11 fraiche" -ForegroundColor White
    Write-Host "  2. Telecharger depuis navigateur (pas PowerShell)" -ForegroundColor White
    Write-Host "  3. Observer alerte SmartScreen reelle" -ForegroundColor White
    Write-Host "  4. Tester bypass utilisateur (Informations complementaires)" -ForegroundColor White
}

Write-Host ""
Write-Host "Fichier test conserve: $setupPath" -ForegroundColor Gray
Write-Host "Nettoyage: Remove-Item '$testDir' -Recurse -Force" -ForegroundColor Gray
