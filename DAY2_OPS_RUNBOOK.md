# 📅 DAY-2 OPS RUNBOOK - USB Video Vault

**Version:** 1.0.0  
**Date:** 17 septembre 2025  
**Type:** Opérations récurrentes post-déploiement

---

## 🎯 **AUJOURD'HUI: PASSAGE RC → GA**

### ✅ **Actions Immédiates (RC.1 → v1.0.0)**

#### 1. Geler la GA
```bash
# Tag version finale
git tag v1.0.0 && git push --tags
```

#### 2. Signer/Notariser les Binaires
```powershell
# Windows Authenticode
.\scripts\signing\sign-windows.ps1 -ExePath "dist\USB-Video-Vault-1.0.0-portable.exe"

# macOS (sur macOS)
./scripts/signing/sign-macos.sh "dist/mac/USB-Video-Vault.app"

# Linux GPG
./scripts/signing/sign-linux.sh "dist/USB-Video-Vault-*.AppImage"
```

#### 3. Publier Release GA
```powershell
# GitHub Release avec notes + binaires + SHA256
.\scripts\automated-release.ps1 -Version "v1.0.0"
```

#### 4. Produire Clés Pilotes (5-10 clients)
```powershell
# Exemple: 3 clés pilotes
foreach ($i in 1..3) {
    $clientId = "PILOT-2025-$(($i).ToString('D3'))"
    
    node tools/create-client-usb.mjs `
        --client "PILOT-CLIENT-$i" `
        --media "./src/assets" `
        --output "./pilot-keys/USB-$clientId" `
        --password "PILOT_KEY_2025" `
        --license-id "$clientId" `
        --expires "2026-03-31T23:59:59Z" `
        --features "playback,watermark,demo" `
        --bind-usb auto --bind-machine off
    
    # Vérification
    node tools/check-enc-header.mjs "pilot-keys/USB-$clientId/vault/media/*.enc"
    Write-Host "✅ Clé pilote $clientId créée et vérifiée"
}
```

---

## 📅 **RUNBOOK DAY-2: OPÉRATIONS RÉCURRENTES**

### 🌅 **QUOTIDIEN** (5-10 min/jour)

#### 📋 Matinée (9h00)
```powershell
# 1. Vérifier emails support
# Inbox: support@usbvideovault.com

# 2. Export diagnostics si tickets ouverts
if (Test-Path "tickets-en-cours.txt") {
    node tools/support-diagnostics.mjs summary
    Write-Host "📊 Diagnostics générés pour équipe support"
}

# 3. Vérifier licences expirées aujourd'hui
node tools/license-management/license-manager.mjs stats
# Alerter si licences expirées dans les 7 jours
```

#### 📦 Émission Licences (sur demande)
```powershell
# Template nomenclature: CLIENT-AAAA-NNNN
# Exemple: ACME-2025-0001, BETA-2025-0002

# 1. Créer clé client
$clientName = Read-Host "Nom client"
$clientId = Read-Host "ID client (ex: ACME-2025-0001)"
$mediaPath = Read-Host "Chemin médias (ex: ./media/client-acme)"
$outputPath = Read-Host "Chemin sortie (ex: G:\USB-Video-Vault)"
$expiry = Read-Host "Date expiration (ex: 2026-12-31T23:59:59Z)"

node tools/create-client-usb.mjs `
    --client "$clientName" `
    --media "$mediaPath" `
    --output "$outputPath" `
    --license-id "$clientId" `
    --expires "$expiry" `
    --features "playback,watermark" `
    --bind-usb auto --bind-machine off

# 2. Validation obligatoire
node tools/check-enc-header.mjs "$outputPath/vault/media/*.enc"

# 3. Archivage licence
node tools/license-management/license-manager.mjs register "{\"id\":\"$clientId\",\"client\":\"$clientName\",\"expires\":\"$expiry\"}"

Write-Host "✅ Licence $clientId émise et archivée"
```

#### 📱 Fin de journée (18h00)
```powershell
# Backup quotidien registre licences
$today = Get-Date -Format "yyyy-MM-dd"
Copy-Item "tools/license-management/registry/issued.json" "backups/issued-$today.json"

Write-Host "✅ Backup quotidien effectué"
```

---

### 📅 **HEBDOMADAIRE** (Lundi 10h00)

#### 🔴 Tests Sécurité Complets
```powershell
Write-Host "🔒 === TESTS SÉCURITÉ HEBDO ===" -ForegroundColor Red

# 1. Tests scénarios rouges
node test-red-scenarios.mjs
if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Tests rouges échoués - INVESTIGATION REQUISE"
    # Alerter équipe sécurité
}

# 2. Scan APIs crypto dépréciées
$deprecated = git grep -r "createCipher\|createDecipher" src/
if ($deprecated) {
    Write-Error "❌ APIs crypto dépréciées détectées:"
    Write-Host $deprecated
}

# 3. Audit dépendances
npm audit --audit-level=high
if ($LASTEXITCODE -ne 0) {
    Write-Warning "⚠️ Vulnérabilités détectées - Review requise"
}

Write-Host "✅ Audit sécurité hebdomadaire terminé"
```

#### 📊 Rapport Licences
```powershell
# Statistiques licences actives
node tools/license-management/license-manager.mjs stats > "reports/weekly-licenses-$(Get-Date -Format 'yyyy-MM-dd').txt"

# Alertes licences expiration proche
$stats = node tools/license-management/license-manager.mjs stats
if ($stats -match "expiring_soon: [1-9]") {
    Write-Warning "⚠️ Licences expirent bientôt - contacter clients"
}
```

---

### 📅 **MENSUEL** (1er du mois 14h00)

#### 🔄 Rotation Sécurité
```powershell
Write-Host "🔐 === ROTATION SÉCURITÉ MENSUELLE ===" -ForegroundColor Cyan

# 1. Vérifier intégrité KEK maître (hors ligne)
# ⚠️ Action manuelle sur poste sécurisé déconnecté
Write-Host "📋 TODO MANUEL: Vérifier KEK maître sur poste offline"

# 2. Rotation mot de passe PFX (si applicable)
Write-Host "📋 TODO MANUEL: Rotation mot de passe certificat code signing"

# 3. Backup chiffré KEK
Write-Host "📋 TODO MANUEL: Backup sécurisé KEK + certificats"
```

#### 🧪 Test Révocation
```powershell
# Créer licence factice pour test
$testId = "TEST-REVOKE-$(Get-Date -Format 'yyyyMM')"

# Émettre licence test
node tools/create-client-usb.mjs `
    --client "TEST-REVOKE" `
    --media "./src/assets" `
    --output "./test-revoke" `
    --license-id "$testId" `
    --expires "2025-12-31T23:59:59Z" `
    --features "test"

# Tester révocation
node tools/license-management/license-manager.mjs revoke "$testId" "test_mensuel"

# Vérifier que licence révoquée bloque l'app
# TODO: Test automatique app avec licence révoquée

# Cleanup
Remove-Item "./test-revoke" -Recurse -Force
Write-Host "✅ Test révocation mensuel terminé"
```

---

## ⚡ **SOP RAPIDES** (Standard Operating Procedures)

### 📦 **SOP-001: Émettre Clé Client**
```powershell
# === PROCÉDURE STANDARD ÉMISSION CLÉ ===
# Durée estimée: 5-10 minutes
# Prérequis: Médias client préparés

# ÉTAPE 1: Préparer environnement
$CLIENT_NAME = Read-Host "Nom client"
$CLIENT_ID = Read-Host "ID unique (format: CLIENT-YYYY-NNNN)"
$MEDIA_PATH = Read-Host "Chemin médias source"
$USB_PATH = Read-Host "Chemin clé USB destination" 
$EXPIRY = Read-Host "Date expiration (YYYY-MM-DDTHH:MM:SSZ)"

# ÉTAPE 2: Générer clé
node tools/create-client-usb.mjs `
    --client "$CLIENT_NAME" `
    --media "$MEDIA_PATH" `
    --output "$USB_PATH" `
    --license-id "$CLIENT_ID" `
    --expires "$EXPIRY" `
    --features "playback,watermark" `
    --bind-usb auto --bind-machine off

# ÉTAPE 3: Validation obligatoire
node tools/check-enc-header.mjs "$USB_PATH/vault/media/*.enc"
if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ ÉCHEC VALIDATION - NE PAS LIVRER"
    exit 1
}

# ÉTAPE 4: Test lecture
Write-Host "🧪 Test lecture requis manuellement sur poste propre"

# ÉTAPE 5: Archivage
node tools/license-management/license-manager.mjs register "{\"id\":\"$CLIENT_ID\",\"client\":\"$CLIENT_NAME\",\"expires\":\"$EXPIRY\"}"

Write-Host "✅ CLÉS CLIENT $CLIENT_ID PRÊTE POUR LIVRAISON"
```

### 🚫 **SOP-002: Révoquer Licence**
```powershell
# === PROCÉDURE RÉVOCATION LICENCE ===
# Durée estimée: 2-5 minutes
# Impact: Licence invalidée immédiatement

$LICENSE_ID = Read-Host "ID licence à révoquer"
$REASON = Read-Host "Raison révocation (security_incident/expiry/other)"

# ÉTAPE 1: Vérifier licence existe
$stats = node tools/license-management/license-manager.mjs stats
if (-not ($stats -match "$LICENSE_ID")) {
    Write-Warning "⚠️ Licence $LICENSE_ID introuvable"
}

# ÉTAPE 2: Créer pack révocation
node tools/license-management/license-manager.mjs revoke "$LICENSE_ID" "$REASON"

# ÉTAPE 3: Distribuer pack (procédure manuelle)
Write-Host "📋 TODO: Distribuer pack révocation aux postes concernés"
Write-Host "📁 Fichier: tools/license-management/revocation/revocation-*.json"

Write-Host "✅ LICENCE $LICENSE_ID RÉVOQUÉE"
```

### 🆘 **SOP-003: Support Niveau 1**
```powershell
# === PROCÉDURE SUPPORT CLIENT ===
# Durée estimée: 10-15 minutes

Write-Host "📞 === SUPPORT NIVEAU 1 ===" -ForegroundColor Green

# ÉTAPE 1: Collecte informations
$CLIENT_ID = Read-Host "ID client/licence"
$OS_VERSION = Read-Host "Système d'exploitation"
$ERROR_MSG = Read-Host "Message d'erreur exact"
$TIMESTAMP = Read-Host "Horodatage problème"

Write-Host "📋 Informations collectées:"
Write-Host "   Client: $CLIENT_ID"
Write-Host "   OS: $OS_VERSION" 
Write-Host "   Erreur: $ERROR_MSG"
Write-Host "   Timestamp: $TIMESTAMP"

# ÉTAPE 2: Diagnostics automatiques
Write-Host "🔍 Demander export diagnostics client:"
Write-Host "   Menu Aide → Exporter Diagnostics"
Write-Host "   Ou: node tools/support-diagnostics.mjs export"

# ÉTAPE 3: Scénarios fréquents
Write-Host "💡 Solutions rapides:"

if ($ERROR_MSG -match "horloge|time|clock") {
    Write-Host "   🕒 HORLOGE INCOHÉRENTE → Corriger heure système + relancer"
}

if ($ERROR_MSG -match "licenc|expir") {
    Write-Host "   🔑 LICENCE EXPIRÉE → Réémettre via SOP-001"
}

if ($ERROR_MSG -match "vault|media|enc") {
    Write-Host "   🗄️ VAULT CORROMPU → Vérifier VAULT_PATH + intégrité .enc"
    Write-Host "   Commande: node tools/check-enc-header.mjs VAULT_PATH/media/*.enc"
}

if ($ERROR_MSG -match "performance|slow|freeze") {
    Write-Host "   ⚡ PERFORMANCE → Fermer autres apps + vérifier USB 3.0+"
}

Write-Host "✅ SUPPORT NIVEAU 1 COMPLÉTÉ"
```

---

## 🛡️ **HYGIÈNE SÉCURITÉ** (Rappels Critiques)

### 🔐 **Gestion Clés & Certificats**
```
✅ KEK maître → Poste offline chiffré + backup externe
✅ Certificats code signing → Coffre-fort physique + HSM si possible  
✅ Mots de passe → Gestionnaire sécurisé (1Password/Bitwarden Enterprise)
✅ Backup KEK → 3-2-1 (3 copies, 2 supports, 1 offsite)
```

### 🖥️ **Poste Packaging Sécurisé**
```
✅ Machine dédiée SANS accès Internet
✅ Antivirus exception pour USB-Video-Vault.exe
✅ Chiffrement disque complet (BitLocker/LUKS)
✅ Sessions utilisateur séparées (admin vs packaging)
```

### 📁 **Gestion Contenus**
```
❌ JAMAIS de médias en clair sur USB
❌ JAMAIS de sauvegarde .enc sans vault complet
❌ JAMAIS de licence test en production
✅ TOUJOURS vérifier .enc avec check-enc-header.mjs
```

### 🔍 **Audit & Traçabilité**
```
✅ SHA256 publiés conservés à côté des binaires
✅ Registre licences sauvé quotidiennement  
✅ Logs support archivés par mois
✅ Tests sécurité hebdomadaires documentés
```

---

## 🚀 **ROADMAP v1.1** (Suggestions Next Iteration)

### 🧪 **Tests E2E Renforcés**
```javascript
// playwright.config.js - Multi-fenêtres + contentProtection
describe('Multi-window contentProtection', () => {
  test('should block screenshot in video window', async ({ page }) => {
    // Test capture d'écran bloquée
    // Test enregistrement écran bloqué
    // Test multi-fenêtre séparée
  });
});
```

### 🔐 **Key-per-File (DEK enveloppée)**
```javascript
// Chaque fichier .enc avec sa propre DEK
// DEK chiffrée par KEK pour tamper-evidence plus forte
const fileStructure = {
  header: "IV(12) + WRAPPED_DEK(48) + CIPHERTEXT + TAG(16)"
};
```

### 📊 **Export Stats Automatique**
```powershell
# CSV local pour audit
node tools/export-stats.mjs --format csv --output "audit/stats-$(Get-Date -Format 'yyyy-MM').csv"
```

### 🔗 **SBOM + Supply Chain**
```yaml
# CI/CD avec attestation supply-chain
- name: Generate SBOM
  run: cyclonedx-bom -o sbom.json
- name: Sign SBOM
  run: cosign sign-blob sbom.json
```

---

## 📊 **MÉTRIQUES DAY-2**

### KPIs Opérationnels
- **📦 Licences émises/jour:** Cible <5, Max 20
- **⏱️ Temps support ticket:** <2h critical, <24h standard  
- **🔴 Tests sécurité:** 100% pass hebdomadaire
- **💾 Backup success rate:** 100% quotidien

### Alertes Automatiques
- **🚨 Licence expire <7j:** Email automatique
- **❌ Test rouge fail:** Slack immédiat équipe sécu
- **📈 >10 tickets/jour:** Escalade niveau 2
- **💾 Backup fail:** SMS responsable ops

---

**📅 RUNBOOK DAY-2 PRÊT POUR OPÉRATIONS RÉCURRENTES**

*🔐 Sécurité Continue • 📦 Packaging Efficace • 🆘 Support Réactif*