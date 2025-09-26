# Script de test uninstall silencieux pour Chocolatey
# Usage: .\tools\test-uninstall-silent.ps1 -Version "0.1.5" [-TestMode]

param(
    [string]$Version = "0.1.5",
    [switch]$TestMode
)

Write-Host "=== TEST UNINSTALL SILENCIEUX v$Version ===" -ForegroundColor Cyan
Write-Host ""

# Chemins potentiels de desinstallation
$uninstallPaths = @(
    "C:\Program Files\USB Video Vault\Uninstall USB Video Vault.exe",
    "C:\Program Files (x86)\USB Video Vault\Uninstall USB Video Vault.exe",
    "$env:LOCALAPPDATA\Programs\USB Video Vault\Uninstall USB Video Vault.exe"
)

# Recherche dans le registre Windows
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

Write-Host "1. RECHERCHE UNINSTALLER..." -ForegroundColor Yellow

$foundUninstaller = $null
$registryEntry = $null

# Recherche fichier uninstall direct
foreach ($path in $uninstallPaths) {
    if (Test-Path $path) {
        Write-Host "  Trouve: $path" -ForegroundColor Green
        $foundUninstaller = $path
        break
    } else {
        Write-Host "  Non trouve: $path" -ForegroundColor Gray
    }
}

# Recherche dans le registre
Write-Host ""
Write-Host "  Recherche registre Windows..." -ForegroundColor Gray

foreach ($regPath in $registryPaths) {
    try {
        $entries = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -like "*USB Video Vault*" }

        foreach ($entry in $entries) {
            Write-Host "  Registre: $($entry.DisplayName)" -ForegroundColor Green
            Write-Host "    Version: $($entry.DisplayVersion)" -ForegroundColor Gray
            Write-Host "    Uninstall: $($entry.UninstallString)" -ForegroundColor Gray

            $registryEntry = $entry
            if (-not $foundUninstaller -and $entry.UninstallString) {
                $foundUninstaller = $entry.UninstallString.Trim('"')
            }
        }
    } catch {
        # Ignorer erreurs acces registre
    }
}

if (-not $foundUninstaller) {
    Write-Host ""
    Write-Host "RESULTAT: Aucun uninstaller trouve" -ForegroundColor Red
    Write-Host "L'application n'est probablement pas installee" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Pour tester avec installation:" -ForegroundColor Blue
    Write-Host "  1. Installer: .\dist\USB Video Vault Setup $Version.exe /S" -ForegroundColor White
    Write-Host "  2. Re-executer: .\tools\test-uninstall-silent.ps1 -Version '$Version'" -ForegroundColor White
    exit 0
}

Write-Host ""
Write-Host "2. TEST UNINSTALL SILENCIEUX..." -ForegroundColor Yellow
Write-Host "  Uninstaller: $foundUninstaller" -ForegroundColor White

if ($TestMode) {
    Write-Host ""
    Write-Host "MODE TEST - Pas de desinstallation reelle" -ForegroundColor Blue
    Write-Host "Commande qui serait executee:" -ForegroundColor Blue
    Write-Host "  & '$foundUninstaller' /S" -ForegroundColor Cyan
    exit 0
}

# Confirmation avant desinstallation
Write-Host ""
Write-Host "ATTENTION: Desinstallation silencieuse d'USB Video Vault" -ForegroundColor Red
$confirmation = Read-Host "Continuer? (y/N)"

if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "Annule par l'utilisateur" -ForegroundColor Yellow
    exit 0
}

# Execution desinstallation silencieuse
Write-Host ""
Write-Host "Execution desinstallation silencieuse..." -ForegroundColor Yellow

try {
    # Detecter type d'uninstaller et arguments
    $uninstallArgs = "/S"  # Standard NSIS

    if ($foundUninstaller -like "*msiexec*") {
        # MSI uninstaller
        $uninstallArgs = "/quiet /norestart"
    } elseif ($foundUninstaller -like "*setup.exe*" -or $foundUninstaller -like "*install*.exe*") {
        # Autres installateurs
        $uninstallArgs = "/S /VERYSILENT /NORESTART"
    }

    Write-Host "  Arguments: $uninstallArgs" -ForegroundColor Gray

    # Lancement desinstallation
    $startTime = Get-Date
    $process = Start-Process -FilePath $foundUninstaller -ArgumentList $uninstallArgs -Wait -PassThru -NoNewWindow
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds

    Write-Host ""
    Write-Host "Desinstallation terminee:" -ForegroundColor Cyan
    Write-Host "  Duree: $([math]::Round($duration, 1))s" -ForegroundColor White
    Write-Host "  Code sortie: $($process.ExitCode)" -ForegroundColor White

    # Interpretation du code de sortie
    switch ($process.ExitCode) {
        0 {
            Write-Host "  Resultat: SUCCES" -ForegroundColor Green
        }
        1 {
            Write-Host "  Resultat: SUCCES (avec redemarrage requis)" -ForegroundColor Yellow
        }
        3010 {
            Write-Host "  Resultat: SUCCES (redemarrage requis)" -ForegroundColor Yellow
        }
        default {
            Write-Host "  Resultat: ECHEC (code $($process.ExitCode))" -ForegroundColor Red
        }
    }

} catch {
    Write-Host "  ERREUR execution: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verification post-desinstallation
Write-Host ""
Write-Host "3. VERIFICATION POST-DESINSTALLATION..." -ForegroundColor Yellow

$cleanupIssues = @()

# Verifier fichiers residuels
$installDirs = @(
    "C:\Program Files\USB Video Vault",
    "C:\Program Files (x86)\USB Video Vault",
    "$env:LOCALAPPDATA\Programs\USB Video Vault"
)

foreach ($dir in $installDirs) {
    if (Test-Path $dir) {
        $residualFiles = Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue
        if ($residualFiles) {
            Write-Host "  Fichiers residuels: $dir ($($residualFiles.Count) fichiers)" -ForegroundColor Yellow
            $cleanupIssues += "Fichiers residuels dans $dir"
        } else {
            Write-Host "  Dossier vide: $dir" -ForegroundColor Gray
        }
    } else {
        Write-Host "  Dossier supprime: $dir" -ForegroundColor Green
    }
}

# Verifier entrees registre
$residualRegistry = @()
foreach ($regPath in $registryPaths) {
    try {
        $entries = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -like "*USB Video Vault*" }
        $residualRegistry += $entries
    } catch {
        # Ignorer
    }
}

if ($residualRegistry.Count -gt 0) {
    Write-Host "  Entrees registre residuelles: $($residualRegistry.Count)" -ForegroundColor Yellow
    $cleanupIssues += "Entrees registre residuelles"
} else {
    Write-Host "  Registre nettoye" -ForegroundColor Green
}

# Verifier raccourcis
$shortcutPaths = @(
    "$env:PUBLIC\Desktop\USB Video Vault.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\USB Video Vault.lnk",
    "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\USB Video Vault.lnk"
)

foreach ($shortcut in $shortcutPaths) {
    if (Test-Path $shortcut) {
        Write-Host "  Raccourci residuel: $shortcut" -ForegroundColor Yellow
        $cleanupIssues += "Raccourci residuel: $shortcut"
    }
}

# RAPPORT FINAL
Write-Host ""
Write-Host "=== RAPPORT DESINSTALLATION ===" -ForegroundColor Cyan

if ($process.ExitCode -eq 0 -and $cleanupIssues.Count -eq 0) {
    Write-Host "RESULTAT: DESINSTALLATION PROPRE" -ForegroundColor Green
    Write-Host "L'application a ete completement supprimee" -ForegroundColor Green
} elseif ($process.ExitCode -eq 0) {
    Write-Host "RESULTAT: DESINSTALLATION PARTIELLE" -ForegroundColor Yellow
    Write-Host "Desinstallation reussie mais elements residuels:" -ForegroundColor Yellow
    foreach ($issue in $cleanupIssues) {
        Write-Host "  - $issue" -ForegroundColor White
    }
} else {
    Write-Host "RESULTAT: ECHEC DESINSTALLATION" -ForegroundColor Red
    Write-Host "Code d'erreur: $($process.ExitCode)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Duree totale: $([math]::Round($duration, 1))s" -ForegroundColor Gray
Write-Host "Compatible Chocolatey silentArgs: '/S'" -ForegroundColor Green
