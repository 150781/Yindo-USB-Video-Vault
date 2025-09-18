# 🔄 OPÉRATIONS POST-GA LIVE
Automatisation complète Day-2 Ops depuis les runbooks

## 🚀 Lancement Ops

### Ops Quotidiennes (8h30)
```powershell
# Routine automatique complète
.\scripts\day2-ops\daily-ops.ps1

# Ou étapes manuelles
.\scripts\day2-ops\daily-ops.ps1 -Step support        # Traiter support
.\scripts\day2-ops\daily-ops.ps1 -Step licenses      # Stats licences
.\scripts\day2-ops\daily-ops.ps1 -Step backups       # Backups vault
.\scripts\day2-ops\daily-ops.ps1 -Step integrity     # Intégrité files
```

### Ops Hebdomadaires (Vendredi 17h)
```powershell
# Routine sécurité complète  
.\scripts\day2-ops\weekly-ops.ps1

# Ou tests ciblés
.\scripts\day2-ops\weekly-ops.ps1 -Test red-team     # Tests rouges
.\scripts\day2-ops\weekly-ops.ps1 -Test deps         # Audit deps
.\scripts\day2-ops\weekly-ops.ps1 -Test apis         # APIs deprecated
.\scripts\day2-ops\weekly-ops.ps1 -Test reports      # Rapports sécu
```

## 📋 SOPs Prêtes à Usage

### 🔑 Émission Clé Client
```powershell
# Clé standard (90j)
node tools/create-client-usb.mjs --client "CLIENT-2025-001" --media "./client-media" --output "./USB-CLIENT-001" --features "playback,watermark"

# Clé démo (30j)  
node tools/create-client-usb.mjs --client "DEMO-2025-001" --media "./demo-media" --output "./USB-DEMO-001" --features "demo" --expires "+30d"

# Validation post-création
node tools/check-enc-header.mjs "./USB-*/vault/media/*.enc"
```

### 🚫 Révocation Urgente
```powershell
# Révoquer licence
node tools/license-management/license-manager.mjs revoke --license-id "CLIENT-2025-001" --reason "Compromission suspectée"

# Générer pack révocation
node tools/license-management/license-manager.mjs generate-revocation-pack --output "./revocation-pack-$(Get-Date -Format 'yyyy-MM-dd').zip"

# Distribuer aux clients (email/CDN)
# Test validation
node test-red-scenarios.mjs --license-id "CLIENT-2025-001"  # Doit échouer
```

### 🛠️ Support Client
```powershell
# Diagnostics client
node tools/support-diagnostics.mjs export --ticket "TICKET-2025-001" --output "./diagnostics-TICKET-2025-001.zip"

# Test clé client  
node tools/check-enc-header.mjs "C:\ClientUSB\vault\media\*.enc"
node checklist-go-nogo.mjs --vault "C:\ClientUSB\vault"

# Collecte logs détaillés
node tools/support-diagnostics.mjs export --verbose --include-keys --output "./full-diag-$(Get-Date -Format 'yyyy-MM-dd-HHmm').zip"
```

## 🛡️ Hygiène Sécurité

### 🔍 Tests Red Team (Weekly)
```bash
# Scénarios complets
node test-red-scenarios.mjs --full

# Tests spécifiques
node test-red-scenarios.mjs --test expired-license
node test-red-scenarios.mjs --test tampered-files  
node test-red-scenarios.mjs --test license-forgery

# Validation intégrité système
node tools/check-enc-header.mjs "vault/**/*.enc" --deep-check
node tools/corrupt-file.mjs --test-only "vault/media/sample.enc"
```

### 📊 Métriques Sécurité
```powershell
# Dashboard quotidien
.\scripts\day2-ops\daily-ops.ps1 -Step metrics

# Métriques complètes
node tools/license-management/license-manager.mjs stats --export "./stats-$(Get-Date -Format 'yyyy-MM-dd').json"

# Alertes automatiques (si configuré)
.\scripts\day2-ops\security-alerts.ps1  # À créer si besoin
```

## 🔄 Rotation Clés

### 📅 Mensuelle (1er du mois)
```powershell
# Rotation KEK master
node tools/license-management/license-manager.mjs rotate-kek --backup-old

# Audit permissions
node tools/license-management/license-manager.mjs audit-permissions

# Régénération clés révoquées expirées
node tools/license-management/license-manager.mjs cleanup-expired --older-than "90d"
```

### 🆘 Urgence (Compromission)
```powershell
# 1. Stopper émissions
node tools/license-management/license-manager.mjs emergency-stop

# 2. Audit complet
node tools/license-management/license-manager.mjs audit-all --export-suspicious

# 3. Nouvelle KEK emergency
node tools/license-management/license-manager.mjs emergency-rekey

# 4. Révoquer suspectes
node tools/license-management/license-manager.mjs revoke-batch --list "./suspicious-licenses.json"
```

## 📈 Monitoring & Alertes

### 📊 KPIs Quotidiens
- **Support tickets**: `.\scripts\day2-ops\daily-ops.ps1 -Step support`
- **Licences actives**: Check activations vs émissions
- **Échecs auth**: Logs authentication failures
- **Intégrité**: Hash vérification média vault

### 🚨 Alertes Critiques
- **License compromise** → Révocation immédiate
- **Vault corruption** → Restore backup + investigation  
- **Multiple failed auth** → Analyse forensic
- **Dependency vuln** → Patch emergency

## 🔧 Maintenance Proactive

### 🛠️ Actions Préventives
```powershell
# Backup hebdomadaire
.\scripts\day2-ops\weekly-ops.ps1 -Task backup-full

# Update dependencies
npm audit fix
npm outdated
.\scripts\day2-ops\weekly-ops.ps1 -Task deps-update

# Nettoyage logs anciens
.\scripts\day2-ops\cleanup-logs.ps1 -OlderThan "30d"
```

### 📅 Planning Mensuel
- **Semaine 1**: Audit sécurité complet + pénétration test
- **Semaine 2**: Mise à jour dépendances + tests régression
- **Semaine 3**: Review processus ops + amélioration outils
- **Semaine 4**: Formation équipe + documentation update

---

## ⚡ Commandes Express

**Support urgent**:
```powershell
node tools/support-diagnostics.mjs emergency --ticket "$TICKET"
```

**Révocation express**:
```powershell
node tools/license-management/license-manager.mjs emergency-revoke --license "$LICENSE"
```

**Status système**:  
```powershell
.\scripts\day2-ops\daily-ops.ps1 -Quick
```

**Tests sécurité rapides**:
```bash
node test-red-scenarios.mjs --quick
```

---

*🎯 **Objectif**: Sécurité maximale, effort minimal, processus répétables*