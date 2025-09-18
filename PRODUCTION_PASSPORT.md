# 🎯 PASSEPORT PRODUCTION USB VIDEO VAULT
**Date:** 17 septembre 2025  
**Version:** v1.0.0 GA  
**Status:** 🚀 PRÊT POUR GO-LIVE

---

## 🔓 GO-LIVE AUJOURD'HUI (ordre d'exécution)

### 1️⃣ Dry-run (sécurité)
```bash
node go-live-today.mjs --dry-run
# ✅ Vérifie: 0 erreurs, tous les checks OK
```

### 2️⃣ Lancement GA automatisé
```bash
node go-live-today.mjs \
  --tag v1.0.0 \
  --sign win,mac,linux \
  --publish release \
  --make-pilot-keys 10 \
  --report out/release-report.final.md
```

### 3️⃣ Vérifications post-publish (à la minute)
```powershell
# Hash intégrité
certutil -hashfile "dist\USB-Video-Vault-*.exe" SHA256

# Démarrage rapide (poste "neuf")
scripts\smoke.ps1

# Lecture d'un .enc réel depuis clé USB
```

---

## 🧯 ROLLBACK (si pépin)

### Release/tags
```bash
git tag -d v1.0.0 && git push --delete origin v1.0.0
# repasser en RC visible côté release si besoin
```

### Binaire retiré
- Dépublie l'asset, republie rc.1

### Clés déjà remises
```bash
# Émettre un revocation pack
node tools/license-management/revoke.mjs \
  --ids "CLIENT_X-2025-0001,CLIENT_Y-2025-0007" \
  --out revocation-pack.json
```

### Anomalie crypto
- Stop distrib, corrige, regénère, re-signe, republie

---

## 📈 "DAY-2 OPS" (mettre en service maintenant)

### A) Planification auto (Windows + Linux)

#### Windows (Task Scheduler)
```powershell
schtasks /Create /TN "USBVault-Day2" /TR "node C:\path\day2-ops-automation.mjs" /SC DAILY /ST 09:00
schtasks /Create /TN "USBVault-RedTeam" /TR "node C:\path\test-red-scenarios.mjs" /SC WEEKLY /D MON /ST 07:30
```

#### Linux (cron)
```bash
0 9 * * * /usr/bin/node /opt/usbvault/day2-ops-automation.mjs >> /var/log/usbvault/day2.log 2>&1
30 7 * * 1 /usr/bin/node /opt/usbvault/test-red-scenarios.mjs >> /var/log/usbvault/redteam.log 2>&1
```

### B) KPIs & alertes (déjà gérés par day2-ops-automation.mjs)
- ✅ Taux lancement OK (≥ 99%)
- 🚫 Échecs lecture / tag GCM (0 toléré)
- 🚨 Tentatives licence expirée/supprimée
- ⏰ Triggers anti-rollback horloge
- 🛡️ Détection capture écran (contentProtection)
- 🔍 Intégrité vault (manifest signé)

---

## 🛠️ OPÉRATIONS EXPRESS (SOP "copier-coller")

### Émettre une clé client
```bash
node create-client-usb.mjs \
  --input "./media/CLIENT_X" \
  --out "U:\USB-Video-Vault\vault" \
  --licenseId "CLIENT_X-2025-0001" \
  --exp "2026-12-31T23:59:59Z" \
  --features "playback,watermark" \
  --bind-usb auto --bind-machine off

node tools/check-enc-header.mjs U:\USB-Video-Vault\vault\media\*.enc
```

### Révoquer une licence (urgence)
```bash
node tools/license-management/revoke.mjs \
  --ids "CLIENT_X-2025-0001" \
  --out revocation-pack.json
# diffuser le pack selon ta procédure interne
```

### Vérifier signature & notarisation
```powershell
# Windows
signtool verify /pa /v "dist\USB-Video-Vault-*.exe"

# macOS
spctl --assess -vv "dist/mac/USB-Video-Vault.app"
```

---

## 🆘 SUPPORT N1 (macro)

### 📋 Demander
- **ID licence**
- **OS**
- **Horodatage**
- **Journaux.zip** (menu Aide ou support-diagnostics.mjs)

### ⚡ Cas rapides

#### "Horloge incohérente"
→ resynchroniser l'heure, relancer

#### "Licence expirée/supprimée"
→ réémettre via create-client-usb.mjs

#### Lecture KO
→ vérifier VAULT_PATH + intégrité .enc:
```bash
node tools/check-enc-header.mjs "<chemin>\*.enc"
```

---

## 🔐 HYGIÈNE SÉCURITÉ (rappel)

### 🔑 Clés & Signatures
- **KEK / clés de signature** hors ligne + sauvegarde chiffrée
- **Poste "packager"** isolé (pas d'Internet)
- **Jamais de médias en clair** sur les clés distribuées

### 📅 Routine Sécurité
- **npm audit** hebdo
- **test-rouge** hebdo  
- **rotation mots de passe** mensuelle

---

## 🎯 COMMANDES ULTRA-RAPIDES

### Status système
```bash
node day2-ops-automation.mjs health
```

### Tests sécurité express
```bash
node test-red-scenarios.mjs --quick
```

### Support urgent
```bash
node tools/support-diagnostics.mjs emergency --ticket "$TICKET"
```

### Révocation express
```bash
node tools/license-management/revoke.mjs emergency-revoke --license "$LICENSE"
```

---

**🚀 PRODUCTION READY - 17 septembre 2025**  
*Votre contenu. Notre sécurité. Votre tranquillité.*