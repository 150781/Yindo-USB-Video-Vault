# 🔧 Runbook Opérateur - Système de Licence Yindo

## ⚡ Actions Courantes (Copier-Coller)

### 🎯 Générer une licence client

#### 1. Obtenir le fingerprint machine
```powershell
# Chez le client ou par remote
node scripts/print-bindings.mjs
```

#### 2. Générer la licence
```powershell
# Variables CI/CD
$env:PACKAGER_PRIVATE_HEX = "RÉCUPÉRER_DEPUIS_VAULT_SECRETS"

# Génération standard (12 mois)
node scripts/make-license.mjs "FINGERPRINT_CLIENT" --kid 1 --exp "2025-09-19T23:59:59Z"

# Génération personnalisée
node scripts/make-license.mjs "FINGERPRINT_CLIENT" --kid 1 --exp "2026-12-31T23:59:59Z" --out "client-specific-vault"
```

#### 3. Livrer au client
```
📁 Package client à envoyer:
   ✅ license.bin
   ✅ install-license-simple.ps1 (script auto-install)
   ✅ README-CLIENT.md (guide 1-page)
   
📋 Instructions client (copier-coller):
   1. Extraire le package
   2. PowerShell en admin: .\install-license-simple.ps1
   3. Vérifier "SUCCESS LICENCE VALIDEE"
   4. Si erreur: capture écran au support
```

### 🔍 Diagnostiquer un problème client

#### 1. Installation automatisée chez le client
```powershell
# Client exécute le script d'installation
.\install-license-simple.ps1 -Verbose

# Codes de sortie:
# 0 = Licence OK
# 1 = Erreur installation/logs
# 2 = Licence invalide
```

#### 2. Diagnostic à distance
```powershell
# Demander au client d'exécuter
Get-Content "$env:APPDATA\USB Video Vault\logs\main.log" -Tail 20

# Ou utiliser script de diagnostic
.\scripts\install-license-simple.ps1 -LicenseSource "license.bin" -Verbose
```

#### 2. Analyser les erreurs courantes
```powershell
# Licence expirée
if ($output -match "expired") {
    Write-Host "🔄 Générer nouvelle licence avec expiration future"
}

# Machine différente
if ($output -match "Machine binding failed") {
    Write-Host "💻 Demander nouveau fingerprint avec print-bindings.mjs"
}

# Fichier corrompu
if ($output -match "Invalid signature") {
    Write-Host "📁 Renvoyer fichier license.bin intact"
}
```

#### 3. Régénérer si nécessaire
```powershell
# Avec nouveau fingerprint
node scripts/print-bindings.mjs  # Chez le client
node scripts/make-license.mjs "NOUVEAU_FINGERPRINT" --kid 1 --exp "2025-12-31T23:59:59Z"
```

### 🔄 Rotation des clés

#### 1. Vérifier état actuel
```powershell
# Distribution des kids
node scripts/analyze-kid-distribution.mjs

# Clés actives
node scripts/test-all-keys.mjs
```

#### 2. Générer nouvelle clé
```powershell
# Générer paire Ed25519
node scripts/keygen.cjs --kid 2 --output scripts/keys/

# Mettre à jour PUB_KEYS dans src/main/licenseSecure.ts
# Ajouter: 2: "NOUVELLE_CLE_PUBLIQUE_HEX"
```

#### 3. Déployer nouvelle version
```powershell
# Build avec nouvelles clés
npm run build:all
npm run pack:usb

# Tester avant production
$env:PACKAGER_PRIVATE_HEX = "NOUVELLE_CLE_PRIVEE"
node scripts/make-license.mjs "test-fingerprint" --kid 2
node scripts/verify-license.mjs "test-vault"
```

### 🚨 Urgence - Clé compromise

#### 1. Désactiver immédiatement
```powershell
# Hot-fix: Retirer kid compromise de PUB_KEYS
# src/main/licenseSecure.ts
# Commenter ou supprimer: 1: "CLE_COMPROMISE"

# Release urgente
npm run build:emergency
npm run deploy:emergency
```

#### 2. Régénération massive
```powershell
# Préparer liste clients
$clients = Get-Content "clients-actifs.txt"

# Régénérer en lot
foreach ($fingerprint in $clients) {
    node scripts/make-license.mjs $fingerprint --kid 3 --exp "2025-12-31T23:59:59Z" --out "urgence-$fingerprint"
}
```

#### 3. Notification clients
```powershell
# Template email automatique
node scripts/send-emergency-licenses.mjs --template "security-update"
```

## 📊 Monitoring & Maintenance

### 🔍 Vérifications quotidiennes
```powershell
# 1. Licences proches expiration (30j)
node scripts/check-expiring-licenses.mjs --days 30

# 2. Échecs validation récents
Get-EventLog -LogName "Yindo-Licenses" -After (Get-Date).AddDays(-1) | Where {$_.EntryType -eq "Error"}

# 3. Sanité système
node scripts/health-check.mjs
```

### 📈 Rapports hebdomadaires
```powershell
# 1. Distribution kids
node scripts/weekly-report.mjs --include-kids

# 2. Volume licences émises
node scripts/license-stats.mjs --period "last-week"

# 3. Support tickets liés licences
node scripts/support-correlation.mjs --period "week"
```

### 🗄️ Archivage mensuel
```powershell
# 1. Sauvegarder licences émises
$date = Get-Date -Format "yyyy-MM"
node scripts/backup-licenses.mjs --output "archive-$date.zip"

# 2. Nettoyer logs anciens
node scripts/cleanup-logs.mjs --older-than "3-months"

# 3. Audit clés actives
node scripts/audit-keys.mjs --report "monthly-audit-$date.json"
```

## 🔧 Commandes de Diagnostic

### 🔍 Analyse approfondie
```powershell
# État complet système
node scripts/system-status.mjs --verbose

# Détails licence spécifique
node scripts/license-details.mjs --fingerprint "ba33ce76..." --include-history

# Validation croisée
node scripts/cross-validate.mjs --vault-path "client-vault" --expected-fingerprint "..."
```

### 🚀 Tests performance
```powershell
# Benchmark validation
node scripts/benchmark-validation.mjs --iterations 1000

# Test charge
node scripts/load-test.mjs --concurrent-validations 50

# Profiling mémoire
node scripts/memory-profile.mjs --duration 300
```

### 🛡️ Audit sécurité
```powershell
# Vérifier intégrité clés
node scripts/verify-key-integrity.mjs

# Scanner vulnérabilités
node scripts/security-scan.mjs --include-dependencies

# Test penetration licence
node scripts/pentest-license.mjs --attack-vectors "replay,tampering,rollback"
```

## 📞 Escalade & Support

### 🆘 Niveau 1 - Support Standard
```
Symptômes: "Licence invalide", "Application ne démarre pas"
Action: Vérifier licence avec verify-license.mjs
Temps: < 2h
```

### 🔥 Niveau 2 - Incident Technique
```
Symptômes: Multiple clients affectés, erreurs système
Action: health-check.mjs + analyse logs + escalade dev
Temps: < 4h
```

### 💥 Niveau 3 - Urgence Sécurité
```
Symptômes: Soupçon compromission, validation bypassée
Action: Protocole urgence + rotation immédiate + audit
Temps: < 1h
Contact: security@yindo.com + DevSecOps on-call
```

## 📋 Checklist Opérationnelle

### ✅ Quotidien
```
□ Check monitoring alerts
□ Vérifier queue support licences
□ Valider backups automatiques
□ Review logs erreurs
```

### ✅ Hebdomadaire  
```
□ Rapport distribution kids
□ Analyse tendances support
□ Test rotation procédure
□ Update documentation
```

### ✅ Mensuel
```
□ Audit sécurité complet
□ Review politique expiration
□ Planification rotations
□ Formation équipe
```

### ✅ Trimestriel
```
□ Penetration testing
□ Review architecture sécurité
□ Mise à jour cryptographie
□ Exercice disaster recovery
```

## 🔐 Variables Secrets (Référence)

### CI/CD Environment
```bash
# Clés privées (Azure Key Vault)
PACKAGER_PRIVATE_HEX_KID_1="[VAULT:licenses/private-1]"
PACKAGER_PRIVATE_HEX_KID_2="[VAULT:licenses/private-2]"
CURRENT_SIGNING_KID="1"

# Alerting
SLACK_WEBHOOK_LICENSES="[VAULT:alerts/slack-licenses]"
EMAIL_ALERTS_LICENSES="licenses-ops@yindo.com"

# Backup
BACKUP_STORAGE_CONNECTION="[VAULT:backup/licenses-storage]"
```

### Accès d'Urgence
```bash
# Break-glass access (2 personnes minimum)
EMERGENCY_KEY_VAULT="[VAULT:emergency/licenses]"
EMERGENCY_CONTACTS="sec-team@yindo.com,ops-lead@yindo.com"
```

---
**Runbook v1.2 - Équipe DevSecOps - Confidentiel**
**Dernière mise à jour: 19 Sep 2024**