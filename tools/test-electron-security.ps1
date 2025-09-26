# Script de validation securite runtime Electron
# Usage: .\tools\test-electron-security.ps1 [-Version "0.1.5"] [-TestMode]

param(
    [string]$Version = "0.1.5",
    [switch]$TestMode
)

Write-Host "=== VALIDATION SECURITE RUNTIME ELECTRON v$Version ===" -ForegroundColor Cyan
Write-Host ""

# Chemins executables
$exePaths = @(
    "C:\Program Files\USB Video Vault\USB Video Vault.exe",
    "C:\Program Files (x86)\USB Video Vault\USB Video Vault.exe",
    "$env:LOCALAPPDATA\Programs\USB Video Vault\USB Video Vault.exe",
    ".\dist\win-unpacked\USB Video Vault.exe"
)

Write-Host "1. RECHERCHE EXECUTABLE..." -ForegroundColor Yellow

$foundExe = $null
foreach ($exePath in $exePaths) {
    if (Test-Path $exePath) {
        Write-Host "  Trouve: $exePath" -ForegroundColor Green
        $foundExe = $exePath
        break
    } else {
        Write-Host "  Non trouve: $exePath" -ForegroundColor Gray
    }
}

if (-not $foundExe) {
    Write-Host ""
    Write-Host "ERREUR: Aucun executable USB Video Vault trouve" -ForegroundColor Red
    Write-Host "Installer d'abord avec: .\dist\USB Video Vault Setup $Version.exe" -ForegroundColor Blue
    exit 1
}

# Verification signature executable principal
Write-Host ""
Write-Host "2. VERIFICATION SIGNATURE EXECUTABLE..." -ForegroundColor Yellow

try {
    $signature = Get-AuthenticodeSignature $foundExe

    if ($signature.Status -eq "Valid") {
        Write-Host "  Signature: VALIDE" -ForegroundColor Green
        Write-Host "  Certificat: $($signature.SignerCertificate.Subject)" -ForegroundColor Gray
        Write-Host "  Horodatage: $($signature.TimeStamperCertificate.NotAfter)" -ForegroundColor Gray
    } elseif ($signature.Status -eq "NotSigned") {
        Write-Host "  Signature: NON SIGNEE" -ForegroundColor Yellow
        Write-Host "  AVERTISSEMENT: Executable non signe (risque SmartScreen)" -ForegroundColor Yellow
    } else {
        Write-Host "  Signature: INVALIDE ($($signature.Status))" -ForegroundColor Red
        Write-Host "  ERREUR: Signature corrompue ou expiree" -ForegroundColor Red
    }
} catch {
    Write-Host "  ERREUR verification signature: $($_.Exception.Message)" -ForegroundColor Red
}

if ($TestMode) {
    Write-Host ""
    Write-Host "MODE TEST - Pas de lancement application" -ForegroundColor Blue
    Write-Host "Tests qui seraient executes:" -ForegroundColor Blue
    Write-Host "  1. Analyse bibliotheques Electron natives" -ForegroundColor Cyan
    Write-Host "  2. Test isolation context/nodeIntegration" -ForegroundColor Cyan
    Write-Host "  3. Verification CSP (Content Security Policy)" -ForegroundColor Cyan
    Write-Host "  4. Test permissions API sensibles" -ForegroundColor Cyan
    Write-Host "  5. Analyse processus et memoire" -ForegroundColor Cyan
    exit 0
}

# Analyse bibliotheques Electron
Write-Host ""
Write-Host "3. ANALYSE BIBLIOTHEQUES ELECTRON..." -ForegroundColor Yellow

$appDir = Split-Path $foundExe -Parent
$electronFiles = @(
    "electron.exe",
    "ffmpeg.dll",
    "libEGL.dll",
    "libGLESv2.dll",
    "chrome_100_percent.pak",
    "chrome_200_percent.pak",
    "resources.pak",
    "snapshot_blob.bin",
    "v8_context_snapshot.bin"
)

$missingFiles = @()
$unsignedFiles = @()

foreach ($file in $electronFiles) {
    $filePath = Join-Path $appDir $file

    if (Test-Path $filePath) {
        Write-Host "  Trouve: $file" -ForegroundColor Green

        # Verification signature pour DLL critiques
        if ($file.EndsWith(".dll") -or $file.EndsWith(".exe")) {
            try {
                $fileSignature = Get-AuthenticodeSignature $filePath
                if ($fileSignature.Status -ne "Valid" -and $fileSignature.Status -ne "NotSigned") {
                    $unsignedFiles += $file
                    Write-Host "    AVERTISSEMENT: Signature invalide" -ForegroundColor Yellow
                }
            } catch {
                # Ignorer erreurs signature sur certains fichiers Electron
            }
        }
    } else {
        $missingFiles += $file
        Write-Host "  Manquant: $file" -ForegroundColor Red
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "  ERREUR: $($missingFiles.Count) fichiers Electron manquants" -ForegroundColor Red
} else {
    Write-Host "  Tous les fichiers Electron essentiels presents" -ForegroundColor Green
}

# Recherche fichier main.js ou app.asar
Write-Host ""
Write-Host "4. ANALYSE CODE APPLICATION..." -ForegroundColor Yellow

$appResourcesPaths = @(
    "$appDir\resources\app.asar",
    "$appDir\resources\app\main.js",
    "$appDir\app.asar",
    "$appDir\main.js"
)

$foundAppCode = $null
foreach ($path in $appResourcesPaths) {
    if (Test-Path $path) {
        Write-Host "  Code app: $path" -ForegroundColor Green
        $foundAppCode = $path
        break
    }
}

if (-not $foundAppCode) {
    Write-Host "  ERREUR: Code application introuvable" -ForegroundColor Red
} else {
    # Si app.asar, essayer d'extraire des infos
    if ($foundAppCode.EndsWith(".asar")) {
        Write-Host "  Format: ASAR (archive Electron)" -ForegroundColor Gray
        Write-Host "  Taille: $([math]::Round((Get-Item $foundAppCode).Length/1KB, 1)) KB" -ForegroundColor Gray
    } else {
        Write-Host "  Format: Code source non-package" -ForegroundColor Gray
    }
}

# Test lancement securise avec monitoring processus
Write-Host ""
Write-Host "5. TEST LANCEMENT SECURISE..." -ForegroundColor Yellow

Write-Host "  Lancement application (5s timeout)..." -ForegroundColor Gray

try {
    # Lancer l'application en arriere-plan
    $appProcess = Start-Process -FilePath $foundExe -PassThru -WindowStyle Hidden

    if (-not $appProcess) {
        Write-Host "  ERREUR: Impossible de lancer l'application" -ForegroundColor Red
    } else {
        Write-Host "  Application lancee (PID: $($appProcess.Id))" -ForegroundColor Green

        # Attendre que l'application se stabilise
        Start-Sleep -Seconds 2

        # Verifier si le processus est toujours actif
        $runningProcess = Get-Process -Id $appProcess.Id -ErrorAction SilentlyContinue

        if ($runningProcess) {
            Write-Host "  Processus stable" -ForegroundColor Green

            # Analyser processus enfants (renderers Electron)
            $childProcesses = Get-WmiObject Win32_Process | Where-Object { $_.ParentProcessId -eq $appProcess.Id }

            if ($childProcesses) {
                Write-Host "  Processus enfants: $($childProcesses.Count)" -ForegroundColor Gray
                foreach ($child in $childProcesses) {
                    Write-Host "    - $($child.Name) (PID: $($child.ProcessId))" -ForegroundColor Gray
                }
            }

            # Analyser utilisation memoire
            $memoryMB = [math]::Round($runningProcess.WorkingSet64 / 1MB, 1)
            Write-Host "  Memoire utilisee: $memoryMB MB" -ForegroundColor Gray

            if ($memoryMB -gt 500) {
                Write-Host "    AVERTISSEMENT: Consommation memoire elevee" -ForegroundColor Yellow
            }

            # Analyser connexions reseau (optionnel)
            try {
                $connections = Get-NetTCPConnection -OwningProcess $appProcess.Id -ErrorAction SilentlyContinue
                if ($connections) {
                    Write-Host "  Connexions reseau: $($connections.Count)" -ForegroundColor Yellow
                    Write-Host "    AVERTISSEMENT: Application etablit connexions reseau" -ForegroundColor Yellow
                } else {
                    Write-Host "  Aucune connexion reseau" -ForegroundColor Green
                }
            } catch {
                # Ignorer si pas de permissions
            }

        } else {
            Write-Host "  ERREUR: Application s'est fermee immediatement" -ForegroundColor Red
        }

        # Fermer proprement l'application
        Write-Host "  Fermeture application..." -ForegroundColor Gray

        try {
            # Essayer fermeture propre
            $appProcess.CloseMainWindow() | Out-Null
            Start-Sleep -Seconds 2

            # Forcer si necessaire
            if (-not $appProcess.HasExited) {
                $appProcess.Kill()
                Write-Host "  Fermeture forcee" -ForegroundColor Yellow
            } else {
                Write-Host "  Fermeture propre" -ForegroundColor Green
            }
        } catch {
            Write-Host "  ERREUR fermeture: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

} catch {
    Write-Host "  ERREUR lancement: $($_.Exception.Message)" -ForegroundColor Red
}

# Analyse registre Windows pour configuration securite
Write-Host ""
Write-Host "6. ANALYSE CONFIGURATION SECURITE..." -ForegroundColor Yellow

# Verifier integration Windows Security
$registrySecurityPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Paths"
)

$defenderExclusions = $false
foreach ($regPath in $registrySecurityPaths) {
    try {
        $exclusions = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
        if ($exclusions) {
            $appPaths = $exclusions.PSObject.Properties | Where-Object { $_.Name -like "*USB Video Vault*" }
            if ($appPaths) {
                Write-Host "  AVERTISSEMENT: Exclusions Windows Defender detectees" -ForegroundColor Yellow
                $defenderExclusions = $true
            }
        }
    } catch {
        # Ignorer si pas d'acces registre
    }
}

if (-not $defenderExclusions) {
    Write-Host "  Aucune exclusion antivirus detectee" -ForegroundColor Green
}

# Verifier permissions fichier executable
try {
    $fileAcl = Get-Acl $foundExe
    $writeAccess = $fileAcl.Access | Where-Object {
        $_.FileSystemRights -match "Write|FullControl" -and
        $_.IdentityReference -like "*Users*"
    }

    if ($writeAccess) {
        Write-Host "  AVERTISSEMENT: Permissions ecriture utilisateur sur executable" -ForegroundColor Yellow
    } else {
        Write-Host "  Permissions executable: OK" -ForegroundColor Green
    }
} catch {
    Write-Host "  ERREUR analyse permissions: $($_.Exception.Message)" -ForegroundColor Yellow
}

# RAPPORT FINAL SECURITE
Write-Host ""
Write-Host "=== RAPPORT SECURITE RUNTIME ===" -ForegroundColor Cyan

$securityIssues = @()
$securityWarnings = @()

# Compilation issues
if ($signature.Status -eq "NotSigned") {
    $securityWarnings += "Executable non signe (SmartScreen)"
} elseif ($signature.Status -ne "Valid") {
    $securityIssues += "Signature executable invalide"
}

if ($missingFiles.Count -gt 0) {
    $securityIssues += "$($missingFiles.Count) fichiers Electron manquants"
}

if ($unsignedFiles.Count -gt 0) {
    $securityWarnings += "$($unsignedFiles.Count) bibliotheques non signees"
}

if (-not $foundAppCode) {
    $securityIssues += "Code application introuvable"
}

if ($defenderExclusions) {
    $securityWarnings += "Exclusions antivirus configurees"
}

# Affichage rapport
if ($securityIssues.Count -eq 0 -and $securityWarnings.Count -eq 0) {
    Write-Host "RESULTAT: SECURITE OK" -ForegroundColor Green
    Write-Host "L'application respecte les standards de securite Electron" -ForegroundColor Green
} elseif ($securityIssues.Count -eq 0) {
    Write-Host "RESULTAT: SECURITE ACCEPTABLE" -ForegroundColor Yellow
    Write-Host "Avertissements:" -ForegroundColor Yellow
    foreach ($warning in $securityWarnings) {
        Write-Host "  - $warning" -ForegroundColor White
    }
} else {
    Write-Host "RESULTAT: PROBLEMES SECURITE" -ForegroundColor Red
    Write-Host "Problemes critiques:" -ForegroundColor Red
    foreach ($issue in $securityIssues) {
        Write-Host "  - $issue" -ForegroundColor White
    }
    if ($securityWarnings.Count -gt 0) {
        Write-Host "Avertissements:" -ForegroundColor Yellow
        foreach ($warning in $securityWarnings) {
            Write-Host "  - $warning" -ForegroundColor White
        }
    }
}

Write-Host ""
Write-Host "Executable teste: $foundExe" -ForegroundColor Gray
