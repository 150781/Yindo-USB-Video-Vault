#!/usr/bin/env pwsh
# Emergency Reset - USB Video Vault

param(
    [string]$CorrectDateTime = "",
    [switch]$Force,
    [switch]$SkipNTP
)

Write-Host @"
🚨 RESET D'URGENCE - USB Video Vault
====================================
ATTENTION: Cette procédure va réinitialiser l'état de licence
et potentiellement modifier l'horloge système.
"@ -ForegroundColor Red

if (-not $Force) {
    Write-Host "`nConfirmez-vous cette action ? (tapez 'RESET' pour confirmer):" -ForegroundColor Yellow
    $confirm = Read-Host
    if ($confirm -ne "RESET") { 
        Write-Host "Opération annulée" -ForegroundColor Yellow
        exit 0 
    }
}

Write-Host "`n1. ARRET APPLICATION..." -ForegroundColor Cyan

# Arrêter application si en cours
$processes = Get-Process "USB Video Vault" -ErrorAction SilentlyContinue
if ($processes) {
    $processes | Stop-Process -Force
    Write-Host "Application arrêtée" -ForegroundColor Green
    Start-Sleep 2
} else {
    Write-Host "Application non en cours d'exécution" -ForegroundColor Gray
}

Write-Host "`n2. CORRECTION HORLOGE..." -ForegroundColor Cyan

if ($CorrectDateTime) {
    try {
        Set-Date $CorrectDateTime
        Write-Host "Horloge corrigée: $CorrectDateTime" -ForegroundColor Green
    } catch {
        Write-Host "ERREUR correction horloge: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Aucune correction horloge demandée" -ForegroundColor Gray
}

# Sync NTP si pas skip
if (-not $SkipNTP) {
    try {
        Write-Host "Tentative synchronisation NTP..." -ForegroundColor Yellow
        w32tm /resync /force 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Synchronisation NTP réussie" -ForegroundColor Green
        } else {
            Write-Host "Synchronisation NTP échouée (normal si pas d'internet)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Synchronisation NTP non disponible" -ForegroundColor Yellow
    }
}

Write-Host "`n3. RESET STATE LICENSE..." -ForegroundColor Cyan

# Reset state license
$statePath = "$env:APPDATA\USB Video Vault\.license_state.json"
if (Test-Path $statePath) {
    try {
        # Backup avant suppression
        $backupPath = "$statePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $statePath $backupPath
        Remove-Item $statePath -Force
        Write-Host "License state réinitialisé (backup: $backupPath)" -ForegroundColor Green
    } catch {
        Write-Host "ERREUR reset state: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Aucun state license à réinitialiser" -ForegroundColor Gray
}

Write-Host "`n4. GENERATION RAPPORT..." -ForegroundColor Cyan

# Générer rapport incident
$reportPath = "incident-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$bindingInfo = try { & node scripts/print-bindings.mjs 2>$null } catch { "ERREUR: Impossible de récupérer l'empreinte" }

$report = @"
RAPPORT INCIDENT - RESET D'URGENCE
==================================
Date/Heure: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Machine: $env:COMPUTERNAME
Utilisateur: $env:USERNAME
Domaine: $env:USERDOMAIN

ACTIONS EFFECTUEES:
- Application arrêtée: $(if($processes) { "Oui" } else { "Non nécessaire" })
- Correction horloge: $(if($CorrectDateTime) { $CorrectDateTime } else { "Non demandée" })
- Sync NTP: $(if(-not $SkipNTP) { "Tentée" } else { "Ignorée" })
- State license reset: $(if(Test-Path $statePath) { "Erreur" } else { "Réussi" })

NOUVELLE EMPREINTE MACHINE:
$bindingInfo

ETAT SYSTEME POST-RESET:
- Heure système: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- Fuseau horaire: $(Get-TimeZone | Select-Object -ExpandProperty Id)

ACTIONS REQUISES:
1. Redémarrer l'application USB Video Vault
2. Si erreur "licence invalide", regénérer licence avec nouvelle empreinte
3. Vérifier fonctionnement normal
4. Transmettre ce rapport à l'administrateur si problème persiste

CONTACTS URGENCE:
- Support IT: [CONTACT_IT]
- Administrateur Licence: [CONTACT_ADMIN]
"@

$report | Out-File $reportPath -Encoding UTF8

Write-Host "`n✅ RESET D'URGENCE TERMINE" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Host "Rapport généré: $reportPath" -ForegroundColor White

Write-Host "`nETAPES SUIVANTES:" -ForegroundColor Cyan
Write-Host "1. Redémarrer l'application USB Video Vault" -ForegroundColor White
Write-Host "2. Tester accès aux médias" -ForegroundColor White
Write-Host "3. Si erreur licence, envoyer rapport à l'administrateur" -ForegroundColor White
Write-Host "4. Surveiller logs pour anomalies" -ForegroundColor White

# Proposer ouverture du rapport
$openReport = Read-Host "`nOuvrir le rapport maintenant? (O/N)"
if ($openReport -eq "O") {
    try {
        Start-Process notepad $reportPath
    } catch {
        Write-Host "Impossible d'ouvrir le rapport - localisation: $reportPath" -ForegroundColor Yellow
    }
}

Write-Host "`nReset d'urgence terminé avec succès" -ForegroundColor Green