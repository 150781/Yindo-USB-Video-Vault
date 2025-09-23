# Next10 - Pack d'Scripts Avancés pour USB Video Vault

## Vue d'Ensemble

Ce pack contient 10 scripts PowerShell avancés pour l'administration, le monitoring et le support de USB Video Vault en production.

## Scripts Principaux

### 📊 Monitoring & Analytics
- **`New-ExecDashboard.ps1`** - Génère un tableau de bord HTML avec 4 KPI critiques
- **`Watch-Abuse.ps1`** - Détecte les tentatives d'abus de licence en temps réel

### 🔄 Gestion des Licences
- **`Enable-KidCanary.ps1`** - Sélectionne N% des licences pour des tests canary (KID=2)
- **`Start-RenewalsJob.ps1`** - Job de renouvellement en lot avec support canary

### 🔍 Diagnostics & Support
- **`Invoke-ClientDiag.ps1`** - Collecte de diagnostics client en ZIP
- **`New-SupportPack.ps1`** - Génère un pack de support complet pour tickets
- **`New-Postmortem.ps1`** - Template de post-mortem d'incident

### 🧪 Tests & Validation
- **`Invoke-LicenseChaos.ps1`** - Simule des scénarios de chaos (expiration, signatures, USB)
- **`Invoke-SBOMGate.ps1`** - Gate de déploiement basé sur les CVE critiques
- **`Test-KeyBackups.ps1`** - Validation de l'intégrité des sauvegardes de clés GPG

### 📅 Tâches Programmées
- **`scheduled/Renewals-Weekly.xml`** - Renouvellement automatique hebdomadaire
- **`scheduled/Watch-Abuse-Hourly.xml`** - Surveillance d'abus horaire

## Installation

```powershell
# Import depuis la racine du projet
cd c:\path\to\USB-Video-Vault
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Test d'un script
.\scripts\next10\New-ExecDashboard.ps1 -OutFile ".\dashboard.html"

# Installation d'une tâche programmée
schtasks /create /xml ".\scripts\next10\scheduled\Watch-Abuse-Hourly.xml" /tn "USB-VideoVault-WatchAbuse"
```

## Usage Typique

### Surveillance Continue
```powershell
# Surveillance d'abus (à programmer horaire)
.\Watch-Abuse.ps1 -WindowHours 24 -Threshold 3

# Dashboard exécutif (à programmer quotidien)
.\New-ExecDashboard.ps1 -OutFile "C:\Reports\exec-dashboard.html"
```

### Gestion des Licences
```powershell
# Activer 5% des licences en canary
.\Enable-KidCanary.ps1 -Percentage 5

# Renouvellement en production
.\Start-RenewalsJob.ps1 -DryRun:$false -OutFile "renewals-report.json"
```

### Support Client
```powershell
# Pack de support pour ticket #12345
.\New-SupportPack.ps1 -TicketNumber "12345" -UserEmail "client@company.com"

# Diagnostics rapides
.\Invoke-ClientDiag.ps1 -OutFile "client-diag.zip"
```

### Tests Chaos
```powershell
# Simulation d'expiration
.\Invoke-LicenseChaos.ps1 -Scenario "Expire" -LicenseId "lic-123"

# Test d'intégrité des clés
.\Test-KeyBackups.ps1 -KeyBackupPath "C:\Backup\keys"
```

## Intégration CI/CD

### Gate de Déploiement
```powershell
# Dans votre pipeline, avant déploiement
.\Invoke-SBOMGate.ps1 -SBOMPath ".\sbom.json"
if ($LASTEXITCODE -ne 0) { 
    Write-Error "Déploiement bloqué: CVE critiques"
    exit 1
}
```

## Sorties et Formats

- **JSON** : Tous les scripts produisent des sorties JSON structurées
- **HTML** : Dashboard exécutif en format web
- **ZIP** : Packs de diagnostics et support
- **Markdown** : Templates de post-mortem

## Prérequis

- Windows PowerShell 5.1+ ou PowerShell 7+
- Droits administrateur pour certains scripts
- Module `Microsoft.PowerShell.Archive` (inclus)
- Accès aux logs USB Video Vault (`$env:APPDATA\USB Video Vault\logs`)

## Sécurité

- Tous les scripts utilisent `$ErrorActionPreference='Stop'`
- Validation des paramètres d'entrée
- Échappement des sorties JSON
- Pas d'exposition de secrets dans les logs

## Support

Pour les issues techniques:
1. Générer un support pack: `.\New-SupportPack.ps1 -TicketNumber "XXX"`
2. Joindre les logs de diagnostic
3. Créer un post-mortem si incident: `.\New-Postmortem.ps1 -IncidentId "XXX"`

---
**Version**: 1.0  
**Auteur**: USB Video Vault Operations Team  
**Dernière mise à jour**: $(Get-Date -Format "yyyy-MM-dd")