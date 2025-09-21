# Plan de Sécurité et Gestion d'Incident
# USB Video Vault - Production Security Plan

## 🔐 Sauvegardes et Protection des Clés

### Clé Privée Packager (Critique)

#### Emplacement Sécurisé
- **Coffre-fort numérique** : Azure Key Vault ou HSM physique
- **Sauvegarde offline** : Support chiffré dans coffre-fort physique
- **Réplication** : 3 sites géographiquement séparés

#### Contrôle d'Accès
- **Personnel autorisé** : Maximum 2 personnes (Lead Dev + CTO)
- **Authentification** : Multi-facteurs obligatoire
- **Logs d'audit** : Traçabilité complète de tous les accès

#### Procédure de Sauvegarde
```powershell
# Script de sauvegarde sécurisée
# Exécution : Mensuelle + avant rotation

# 1. Export chiffré de la clé
$keyPath = "secure-vault:\packager-private-key"
$backupPath = "offline-storage:\backup-$(Get-Date -Format 'yyyyMM')"

# 2. Chiffrement avec clé de sauvegarde
gpg --encrypt --armor --recipient backup@yindo.com $keyPath > $backupPath.asc

# 3. Vérification intégrité
gpg --verify $backupPath.asc

# 4. Stockage physique sécurisé
Write-Log "Backup ready for offline storage: $backupPath.asc"
```

### Rotation des Clés

#### Calendrier de Rotation
- **KID 1** : Production actuelle (expire 2026-12-31)
- **KID 2** : Préparé et testé (activation 2026-06-01)
- **KID 3** : En préparation (génération 2026-03-01)

#### Test de Rotation KID 2
```powershell
# Test rotation KID 2 sur Ring 0
# Exécution : Avant passage Ring 1

Write-Host "Test rotation KID 2..." -ForegroundColor Cyan

# 1. Générer licence test avec KID 2
$testMachine = "TEST-MACHINE-01"
$testFingerprint = "abc123def456..."

node scripts\make-license.mjs $testFingerprint --kid 2 --exp "2027-12-31T23:59:59Z"

# 2. Installer et tester
Copy-Item .\out\license.bin "\\$testMachine\C$\temp\license-kid2.bin"

# 3. Vérifier avec application
$testResult = Invoke-Command -ComputerName $testMachine -ScriptBlock {
    $appPath = "C:\Program Files\USB Video Vault\USB Video Vault.exe"
    & $appPath --test-license "C:\temp\license-kid2.bin" 2>&1
}

if ($testResult -match "License valid") {
    Write-Host "✓ KID 2 fonctionne correctement" -ForegroundColor Green
} else {
    Write-Host "❌ Problème avec KID 2: $testResult" -ForegroundColor Red
    throw "Test KID 2 échoué"
}
```

### Calendrier de Maintenance

#### Rappels Automatiques
```powershell
# Script de rappels automatiques
# Tâche planifiée : Hebdomadaire

$certExpirations = @{
    "Code Signing Cert" = "2026-03-15"
    "Apple Developer Cert" = "2026-08-22"
    "License Key Rotation" = "2026-06-01"
}

foreach ($item in $certExpirations.GetEnumerator()) {
    $expiry = [DateTime]::Parse($item.Value)
    $daysUntil = ($expiry - (Get-Date)).Days
    
    if ($daysUntil -le 90) {
        $urgency = if ($daysUntil -le 30) { "URGENT" } else { "WARNING" }
        
        # Email automatique
        Send-MailMessage -To "security@yindo.com" -Subject "[$urgency] $($item.Key) expire dans $daysUntil jours" -Body "Planifier renouvellement immédiatement."
        
        # Slack notification
        $webhook = "https://hooks.slack.com/services/xxx/yyy/zzz"
        $payload = @{
            text = "🚨 $($item.Key) expire dans $daysUntil jours ($($item.Value))"
            channel = "#security-alerts"
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri $webhook -Method Post -Body $payload -ContentType "application/json"
    }
}
```

## 🔄 Plan de Rollback

### Procédure de Rollback d'Urgence

#### 1. Détection d'Incident
```powershell
# Triggers de rollback automatique
$criticalErrors = @(
    "License validation failing > 50%",
    "Application crashes > 10/hour", 
    "Security breach detected",
    "Mass license revocation needed"
)

# Monitoring automatique
foreach ($error in $criticalErrors) {
    # Logic de détection + alerte immédiate
    if (Test-CriticalCondition $error) {
        Invoke-EmergencyRollback -Reason $error
    }
}
```

#### 2. Rollback Installer
```powershell
# Rollback vers version stable précédente
# Exécution : Manuel ou automatique selon criticité

param([string]$RollbackVersion = "1.0.3")

Write-Host "🔄 Rollback d'urgence vers v$RollbackVersion" -ForegroundColor Yellow

# 1. Arrêter déploiements en cours
Stop-Process -Name "USB-Video-Vault*" -Force -ErrorAction SilentlyContinue

# 2. Restaurer installeur stable
$stableInstaller = "archive\USB-Video-Vault-$RollbackVersion-Setup.exe"
if (-not (Test-Path $stableInstaller)) {
    throw "❌ Installeur stable v$RollbackVersion non trouvé!"
}

# 3. Mise à disposition urgente
Copy-Item $stableInstaller "releases\emergency\USB-Video-Vault-Emergency-Setup.exe" -Force

# 4. Notification équipes
Send-AlertToTeams -Message "🚨 ROLLBACK ACTIF - Version stable: v$RollbackVersion disponible" -Urgency "CRITICAL"

# 5. Documentation incident
$incidentReport = @{
    Timestamp = Get-Date
    TriggerReason = $Reason
    RollbackVersion = $RollbackVersion
    AffectedSystems = "Ring 0 + Ring 1"
    Status = "ACTIVE"
} | ConvertTo-Json

$incidentReport | Out-File "incidents\rollback-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

Write-Host "✓ Rollback actif - Version d'urgence disponible" -ForegroundColor Green
```

#### 3. Communication de Crise
```powershell
# Templates de communication d'urgence

$emergencyTemplates = @{
    "Ring0" = @{
        Subject = "URGENT - Problème USB Video Vault détecté"
        Body = @"
Équipe,

Un problème critique a été détecté avec USB Video Vault v1.0.4.
ACTION IMMÉDIATE : Arrêtez l'utilisation et contactez le support.

Version de secours disponible : [lien]
ETA correction : En cours d'évaluation

Support d'urgence : +33 X XX XX XX XX
"@
    }
    
    "Ring1" = @{
        Subject = "Maintenance d'urgence - USB Video Vault"  
        Body = @"
Cher client,

Nous avons détecté un problème technique nécessitant une maintenance d'urgence.
Votre version actuelle peut présenter des dysfonctionnements.

Actions recommandées :
1. Télécharger la version de correction : [lien]
2. Contacter notre support si problèmes

Nous nous excusons pour la gêne occasionnée.
L'équipe Yindo
"@
    }
}
```

### Infrastructure de Secours

#### Serveurs de Sauvegarde
```powershell
# Configuration serveurs de backup/fallback

$backupServers = @{
    "Primary" = "backup1.yindo.com"
    "Secondary" = "backup2.yindo.com" 
    "Emergency" = "emergency.yindo.com"
}

# Test automatique de basculement
foreach ($server in $backupServers.Values) {
    try {
        $response = Invoke-WebRequest "https://$server/health" -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ $server opérationnel" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ $server indisponible" -ForegroundColor Red
        # Alerte automatique
    }
}
```

## 🚨 Révocation d'Urgence

### Révocation par LicenseId

#### Méthode Temporaire (avant CRL complet)
```powershell
# Révocation d'urgence sans CRL
# Méthode : Patch mineur qui blacklist licenseId

param([string[]]$RevokedLicenseIds)

Write-Host "🚨 Révocation d'urgence pour $($RevokedLicenseIds.Count) licence(s)" -ForegroundColor Red

# 1. Créer patch de révocation
$revocationPatch = @{
    version = "1.0.4.1"
    revokedLicenses = $RevokedLicenseIds
    effectiveDate = (Get-Date).ToString("yyyy-MM-dd")
    reason = "Security incident"
} | ConvertTo-Json

# 2. Intégrer dans code source
$patchCode = @"
// EMERGENCY REVOCATION PATCH v1.0.4.1
const EMERGENCY_REVOKED_LICENSES = $($revocationPatch | ConvertTo-Json -Compress);

function isLicenseRevoked(licenseId) {
    return EMERGENCY_REVOKED_LICENSES.revokedLicenses.includes(licenseId);
}
"@

# 3. Build patch rapide
$patchCode | Out-File "src\shared\emergency-revocation.ts" -Encoding UTF8

# 4. Build accéléré
npm run build:emergency-patch

# 5. Signature et distribution
.\scripts\windows-sign-prod.ps1 -SignOnly
```

#### Révocation avec CRL (Méthode Propre)
```powershell
# Utiliser système CRL existant pour révocation propre

# 1. Ajouter à CRL
.\scripts\crl-management.ps1 -Action Revoke -LicenseId "lic_xxx" -Reason "Security breach"

# 2. Republier CRL
.\scripts\crl-management.ps1 -Action Publish

# 3. Notification push (si implémenté)
.\scripts\crl-management.ps1 -Action NotifyClients

Write-Host "✓ Licence révoquée via CRL - Effective immédiatement" -ForegroundColor Green
```

### Force de Réémission Massive

#### En Cas de Compromission Clé
```powershell
# Réémission d'urgence pour toutes licences actives
# Scénario : Clé privée potentiellement compromise

Write-Host "🚨 RÉÉMISSION MASSIVE D'URGENCE" -ForegroundColor Red

# 1. Rotation forcée vers nouveau KID
$newKid = 3  # KID d'urgence pré-généré

# 2. Récupérer toutes licences actives
$activeLicenses = Import-Csv "audit\all-active-licenses.csv"

# 3. Réémission en lot avec nouveau KID
foreach ($license in $activeLicenses) {
    Write-Host "Réémission urgente: $($license.machine)" -ForegroundColor Yellow
    
    node scripts\make-license.mjs $license.fingerprint $license.usbSerial --kid $newKid --exp "2027-12-31T23:59:59Z"
    
    # Sauvegarde immédiate
    Copy-Item .\out\license.bin "emergency-reissue\$($license.machine)-emergency.bin" -Force
    
    # Log audit
    "$($license.machine),$($license.fingerprint),EMERGENCY_REISSUE,$(Get-Date)" | Add-Content "audit\emergency-reissue-log.csv"
}

Write-Host "✓ Réémission massive terminée - Distribuer d'urgence!" -ForegroundColor Green
```

## 📋 Procédures d'Incident

### Classification des Incidents

#### Niveau 1 - CRITIQUE
- **Compromission** de clé privée
- **Faille de sécurité** majeure
- **Panne totale** du système de licence

**Réponse** : < 1 heure, équipe complète mobilisée

#### Niveau 2 - MAJEUR  
- **Bugs** affectant > 25% des utilisateurs
- **Performance** dégradée significativement
- **Erreurs** de validation licence sporadiques

**Réponse** : < 4 heures, équipe technique mobilisée

#### Niveau 3 - MINEUR
- **Bugs** cosmétiques ou fonctionnalités secondaires
- **Performance** légèrement dégradée
- **Problèmes** utilisateur isolés

**Réponse** : < 24 heures, correction dans prochaine release

### Procédure de Gestion d'Incident

#### 1. Détection et Évaluation
```powershell
# Template de rapport d'incident initial

$incidentTemplate = @{
    ID = "INC-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    DetectedAt = Get-Date
    DetectedBy = $env:USERNAME
    Severity = "TBD"  # CRITICAL/MAJOR/MINOR
    Category = "TBD"  # SECURITY/PERFORMANCE/FUNCTIONALITY
    Description = "Description détaillée du problème"
    AffectedSystems = @()  # Ring0, Ring1, GA
    AffectedUsers = "TBD"  # Nombre estimé
    InitialAssessment = "Évaluation préliminaire"
    ImmediateActions = @()  # Actions immédiates prises
    Assignee = "TBD"
    Status = "INVESTIGATING"
}

# Sauvegarde automatique
$incidentTemplate | ConvertTo-Json | Out-File "incidents\INC-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
```

#### 2. Communication et Coordination
```powershell
# Alertes automatiques selon sévérité

function Send-IncidentAlert {
    param($Incident)
    
    $alertChannels = switch ($Incident.Severity) {
        "CRITICAL" { @("SMS", "Email", "Slack", "Phone") }
        "MAJOR"    { @("Email", "Slack") }
        "MINOR"    { @("Slack") }
    }
    
    foreach ($channel in $alertChannels) {
        Send-Alert -Channel $channel -Message "🚨 INCIDENT $($Incident.ID) - $($Incident.Severity)" -Incident $Incident
    }
}
```

#### 3. Documentation et Post-Mortem
```markdown
# Template Post-Mortem

## Incident INC-YYYYMMDD-HHMMSS

### Résumé
- **Date** : 
- **Durée** : 
- **Impact** : 
- **Cause racine** : 

### Timeline
- HH:MM - Détection
- HH:MM - Escalade
- HH:MM - Correction appliquée
- HH:MM - Résolution confirmée

### Actions Correctives
1. **Immédiat** : 
2. **Court terme** : 
3. **Long terme** : 

### Leçons Apprises
- 
- 

### Améliorations Processus
- 
- 
```

## 🔍 Monitoring Sécurité

### Alertes Automatiques
```powershell
# Surveillance sécurité 24/7

$securityMetrics = @{
    "FailedLicenseValidations" = { Get-FailedValidationRate -Threshold 5 }
    "UnusualUsagePatterns" = { Get-AnomalousUsage -Threshold 3 }
    "UnauthorizedAccess" = { Get-SecurityLogs -Level "Warning" }
    "SystemIntegrityChecks" = { Test-SystemIntegrity }
}

# Vérification continue
while ($true) {
    foreach ($metric in $securityMetrics.GetEnumerator()) {
        $result = & $metric.Value
        if ($result.IsAlert) {
            Send-SecurityAlert -Type $metric.Key -Data $result
        }
    }
    Start-Sleep -Seconds 300  # 5 minutes
}
```

---

**Ce plan de sécurité doit être révisé trimestriellement et testé semestriellement via des exercices de simulation d'incident.**

🚨 **EN CAS D'URGENCE** : Contacter immédiatement l'équipe de sécurité : security@yindo.com / +33 X XX XX XX XX