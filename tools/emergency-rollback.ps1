# Script de rollback d'urgence
# Usage: .\emergency-rollback.ps1 -FromVersion "0.1.5" -ToVersion "0.1.4" [-WhatIf] [-Execute]
# -WhatIf: simulation sans execution (test a blanc)
# -Execute: execution reelle du rollback

param(
  [string]$FromVersion,
  [string]$ToVersion = "0.1.4",
  [string]$Reason = "Critical issue",
  [switch]$Execute,
  [switch]$DryRun,
  [switch]$WhatIf
)

Write-Host "=== ROLLBACK D'URGENCE ===" -ForegroundColor Red
Write-Host "FROM: v$FromVersion → TO: v$ToVersion" -ForegroundColor Yellow
Write-Host "RAISON: $Reason" -ForegroundColor Yellow
Write-Host ""

# Gestion des modes d'execution
$IsSimulation = $DryRun -or $WhatIf
$IsExecution = $Execute

if (-not $IsExecution -and -not $IsSimulation) {
  Write-Host "ATTENTION: Rollback d'urgence!" -ForegroundColor Red
  Write-Host "Modes disponibles:" -ForegroundColor Yellow
  Write-Host "  -WhatIf  : Test a blanc (recommande)" -ForegroundColor White
  Write-Host "  -DryRun  : Simulation detaillee" -ForegroundColor White  
  Write-Host "  -Execute : Execution reelle (DANGER!)" -ForegroundColor Red
  exit 1
}

if ($IsSimulation) {
  $simulationMode = if ($WhatIf) { "WHAT-IF" } else { "DRY-RUN" }
  Write-Host "MODE $simulationMode - Simulation uniquement" -ForegroundColor Blue
  Write-Host ""
}

# ETAPE 1: Verification versions
Write-Host "1. Verification versions..." -ForegroundColor Yellow

# Verifier que la version TO existe
$toReleaseExists = $false
if (Get-Command gh -ErrorAction SilentlyContinue) {
  try {
    $releases = gh release list --json tagName | ConvertFrom-Json
    $toReleaseExists = $releases | Where-Object { $_.tagName -eq "v$ToVersion" }
    if ($toReleaseExists) {
      Write-Host "  OK Version v$ToVersion existe" -ForegroundColor Green
    }
    else {
      Write-Host "  ERREUR Version v$ToVersion introuvable" -ForegroundColor Red
      exit 1
    }
  }
  catch {
    Write-Host "  WARN Impossible de verifier les releases GitHub" -ForegroundColor Yellow
  }
}

# ETAPE 2: Depublier version defaillante
Write-Host "`n2. Depublication v$FromVersion..." -ForegroundColor Yellow

if ($IsExecution) {
  Write-Host "  Marquage en prerelease..." -ForegroundColor Blue
  try {
    gh release edit "v$FromVersion" --prerelease
    Write-Host "  OK v$FromVersion marquee en prerelease" -ForegroundColor Green
  }
  catch {
    Write-Host "  ERREUR Depublication v$FromVersion - $($_.Exception.Message)" -ForegroundColor Red
  }
}
else {
  Write-Host "  [SIMULATION] gh release edit v$FromVersion --prerelease" -ForegroundColor Gray
}

# ETAPE 3: Restaurer version stable
Write-Host "`n3. Restauration v$ToVersion..." -ForegroundColor Yellow

if (-not $DryRun -and $Execute) {
  Write-Host "  Marquage comme latest..." -ForegroundColor Blue
  try {
    gh release edit "v$ToVersion" --latest
    Write-Host "  OK v$ToVersion restauree comme latest" -ForegroundColor Green
  }
  catch {
    Write-Host "  ERREUR Restauration v$ToVersion - $($_.Exception.Message)" -ForegroundColor Red
  }
}
else {
  Write-Host "  [SIMULATION] gh release edit v$ToVersion --latest" -ForegroundColor Gray
}

# ETAPE 4: Communication d'urgence
Write-Host "`n4. Communication publique..." -ForegroundColor Yellow

$postMortemIssue = @"
# 🚨 ROLLBACK v$FromVersion → v$ToVersion

## Raison
$Reason

## Actions prises
- [x] v$FromVersion marquée en prerelease
- [x] v$ToVersion restaurée comme latest
- [ ] Investigation en cours
- [ ] Fix prévu dans prochaine version

## Utilisateurs impactés
Si vous avez installé v$FromVersion, nous recommandons:
1. Désinstaller la version actuelle
2. Télécharger v$ToVersion depuis les releases
3. Réinstaller la version stable

## Timeline
$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) - Rollback initié
$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) - Investigation en cours

## Suivi
Issue sera mise à jour avec post-mortem complet.
"@

if (-not $DryRun -and $Execute) {
  Write-Host "  Creation issue post-mortem..." -ForegroundColor Blue
  try {
    $issueTitle = "Emergency Rollback v$FromVersion - $Reason"
    gh issue create --title $issueTitle --body $postMortemIssue --label "critical,rollback"
    Write-Host "  OK Issue post-mortem creee" -ForegroundColor Green
  }
  catch {
    Write-Host "  ERREUR Creation issue - $($_.Exception.Message)" -ForegroundColor Red
  }
}
else {
  Write-Host "  [SIMULATION] Creation issue post-mortem" -ForegroundColor Gray
  Write-Host "  Titre: Emergency Rollback v$FromVersion - $Reason" -ForegroundColor Gray
}

# ETAPE 5: Rollback distributions
Write-Host "`n5. Rollback distributions..." -ForegroundColor Yellow

# Winget - Creation issue pour retrait
Write-Host "  Winget:" -ForegroundColor Blue
if (-not $DryRun -and $Execute) {
  Write-Host "    ACTION MANUELLE: Creer issue microsoft/winget-pkgs" -ForegroundColor Yellow
  Write-Host "    Titre: Remove Yindo.USBVideoVault $FromVersion - Critical issue" -ForegroundColor White
  Write-Host "    Corps: Emergency rollback due to: $Reason" -ForegroundColor White
}
else {
  Write-Host "    [SIMULATION] Issue retrait Winget" -ForegroundColor Gray
}

# Chocolatey - Unlisting
Write-Host "  Chocolatey:" -ForegroundColor Blue
if (-not $DryRun -and $Execute) {
  Write-Host "    ACTION MANUELLE: Contacter maintainers Chocolatey" -ForegroundColor Yellow
  Write-Host "    Demander unlisting usbvideovault.$FromVersion" -ForegroundColor White
}
else {
  Write-Host "    [SIMULATION] Unlisting Chocolatey" -ForegroundColor Gray
}

# ETAPE 6: Monitoring urgence
Write-Host "`n6. Monitoring post-rollback..." -ForegroundColor Yellow

if (-not $DryRun -and $Execute) {
  Write-Host "  Demarrage monitoring intensif..." -ForegroundColor Blue
  # Monitoring plus frequent post-rollback
  Start-Process PowerShell -ArgumentList "-File", ".\tools\monitor-release.ps1", "-Version", $ToVersion, "-Hours", "24" -WindowStyle Minimized
  Write-Host "  OK Monitoring 24h demarre" -ForegroundColor Green
}
else {
  Write-Host "  [SIMULATION] Monitoring intensif 24h" -ForegroundColor Gray
}

# ETAPE 7: Audit post-rollback
Write-Host "`n7. Audit post-incident..." -ForegroundColor Yellow

$auditLog = @"
# AUDIT POST-ROLLBACK v$FromVersion

## Timeline
$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) - Rollback initie
$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) - Actions completees

## Actions prises
1. v$FromVersion depubliee (prerelease)
2. v$ToVersion restauree (latest)
3. Issue post-mortem creee
4. Monitoring intensif demarre

## Causes racines
$Reason

## Actions preventives
- [ ] Review process QA pre-release
- [ ] Renforcer tests automatises
- [ ] Ameliorer monitoring proactif
- [ ] Documentation lessons learned

## Impact
- Utilisateurs: Notification via GitHub + README
- Distribution: Winget/Chocolatey notifies
- Reputation: Communication transparente

## Suivi
Investigation detaillee en cours.
Prevention mesures a implementer.
"@

$auditFile = ".\logs\rollback-audit-v$FromVersion-$((Get-Date).ToString('yyyyMMdd-HHmm')).md"
if (-not $DryRun -and $Execute) {
  New-Item -ItemType Directory -Path ".\logs" -Force | Out-Null
  $auditLog | Out-File $auditFile -Encoding UTF8
  Write-Host "  OK Audit log: $auditFile" -ForegroundColor Green
}
else {
  Write-Host "  [SIMULATION] Audit log: $auditFile" -ForegroundColor Gray
}

# RAPPORT FINAL
Write-Host "`n=== ROLLBACK EXECUTE ===" -ForegroundColor $(if ($Execute) { 'Green' }else { 'Blue' })
Write-Host ""
Write-Host "STATUT:" -ForegroundColor Cyan
Write-Host "  Version defaillante: v$FromVersion (prerelease)" -ForegroundColor Red
Write-Host "  Version stable: v$ToVersion (latest)" -ForegroundColor Green
Write-Host "  Raison: $Reason" -ForegroundColor Yellow
Write-Host "  Audit: $auditFile" -ForegroundColor White

Write-Host "`nACTIONS MANUELLES REQUISES:" -ForegroundColor Blue
Write-Host "  1. Verifier releases GitHub correctes" -ForegroundColor Yellow
Write-Host "  2. Creer issue microsoft/winget-pkgs (retrait)" -ForegroundColor Yellow
Write-Host "  3. Contacter Chocolatey maintainers" -ForegroundColor Yellow
Write-Host "  4. Repondre aux issues utilisateurs" -ForegroundColor Yellow
Write-Host "  5. Communiquer sur canaux officiels" -ForegroundColor Yellow

Write-Host "`nSUIVI:" -ForegroundColor Blue
Write-Host "  Issues: https://github.com/150781/Yindo-USB-Video-Vault/issues" -ForegroundColor White
Write-Host "  Monitoring: .\logs\release-monitoring-v$ToVersion.log" -ForegroundColor White
Write-Host "  Post-mortem: En cours de redaction" -ForegroundColor White

Write-Host ""
if ($Execute) {
  Write-Host "ROLLBACK COMPLETE - INVESTIGATION EN COURS" -ForegroundColor Red
}
else {
  Write-Host "SIMULATION TERMINEE - AJOUTER -Execute POUR ROLLBACK REEL" -ForegroundColor Blue
}
