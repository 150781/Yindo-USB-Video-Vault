# 🚀 GO-LIVE PLAN - USB Video Vault v1.0.0

**Release Target:** v1.0.0  
**Timeline:** 7 étapes sur 72h  
**Date:** 17 septembre 2025

---

## 📋 **ÉTAPE 1: GELER LA VERSION** 🔒

### Git Tagging Strategy
```bash
# Tag release candidate
git tag v1.0.0-rc.1
git push origin v1.0.0-rc.1

# Soak test 48-72h, puis si OK:
git tag v1.0.0
git push --tags
```

### Validation Checklist Pre-Tag
- [x] Go/No-Go 100% ✅
- [x] Red team scenarios bloqués ✅
- [x] Build portable validé ✅
- [x] Package USB testé ✅
- [ ] **Pilot user tests (5-10 clés)**
- [ ] **48h soak test complet**

---

## 📋 **ÉTAPE 2: SIGNATURE BINAIRES** ✍️

### Windows (Authenticode)
```powershell
# scripts/sign-windows.ps1
signtool sign /fd SHA256 /f ".\certs\code-signing.pfx" /p "$env:PFX_PASSWORD" `
  /tr http://timestamp.sectigo.com /td SHA256 `
  "dist\USB-Video-Vault-*.exe"

# Vérification
signtool verify /pa /v "dist\USB-Video-Vault-*.exe"
```

### macOS (codesign + notarize)
```bash
# scripts/sign-macos.sh
codesign --deep --force --options runtime --timestamp \
  --sign "Developer ID Application: USB VIDEO VAULT (TEAMID)" \
  "dist/mac/USB-Video-Vault.app"

xcrun notarytool submit "dist/mac/USB-Video-Vault.zip" \
  --apple-id "support@usbvideovault.com" --team-id TEAMID \
  --password "$NOTARY_PASSWORD" --wait

xcrun stapler staple "dist/mac/USB-Video-Vault.app"
```

### Linux (GPG)
```bash
# scripts/sign-linux.sh
gpg --detach-sign --armor dist/USB-Video-Vault-*.AppImage
```

---

## 📋 **ÉTAPE 3: ARTEFACTS & INTÉGRITÉ** 📦

### Hash Generation
```powershell
# scripts/generate-hashes.ps1
certutil -hashfile "dist\USB-Video-Vault-1.0.0-portable.exe" SHA256 > releases\v1.0.0\SHA256SUMS
shasum -a 256 dist/mac/USB-Video-Vault.dmg >> releases\v1.0.0\SHA256SUMS
shasum -a 256 dist/USB-Video-Vault-*.AppImage >> releases\v1.0.0\SHA256SUMS
```

### Release Structure
```
releases/v1.0.0/
├── USB-Video-Vault-1.0.0-win-portable.exe      # Windows signé
├── USB-Video-Vault-1.0.0-mac.dmg               # macOS notarisé
├── USB-Video-Vault-1.0.0-linux.AppImage        # Linux + .sig
├── SHA256SUMS                                   # Hashes vérifiés
├── RELEASE_NOTES.md                             # Notes de version
└── signatures/
    ├── windows.sig                              # Authenticode
    ├── macos.sig                                # Apple notarization
    └── linux.sig                               # GPG signature
```

---

## 📋 **ÉTAPE 4: EMPAQUETAGE CLIENT (CLÉ USB "OR")** 💿

### Script Automatisé
```bash
# tools/create-client-usb.mjs
node tools/create-client-usb.mjs \
  --client "CLIENT-ACME-2025" \
  --media "./media-client-ACME" \
  --output "G:\USB-Video-Vault" \
  --password "CLIENT_MASTER_KEY" \
  --license-id "ACME-2025-0001" \
  --expires "2026-12-31T23:59:59Z" \
  --features "playback,watermark,analytics" \
  --bind-usb auto \
  --bind-machine optional
```

### Vérification Clé Client
```bash
# Validation automatique
node tools/check-enc-header.mjs "G:\USB-Video-Vault\vault\media\*.enc"
node tools/validate-client-usb.mjs "G:\"
```

### Template Client Package
```
CLIENT-ACME-USB/
├── USB-Video-Vault.exe                          # App signée
├── Launch-Client.bat                            # Lancement rapide
├── vault/
│   ├── .vault/
│   │   ├── manifest.bin                         # Métadonnées signées
│   │   ├── license.bin                          # Licence client
│   │   └── device.tag                           # Binding USB
│   ├── license.json                             # Licence publique
│   └── media/                                   # Médias chiffrés client
├── docs/
│   ├── GUIDE_UTILISATEUR.pdf                    # 1 page démarrage
│   └── SUPPORT.md                               # Contact + diagnostics
└── tools/
    └── export-logs.bat                          # Diagnostics client
```

---

## 📋 **ÉTAPE 5: REVOCATION & ROTATION** 🔄

### KEK Maître (Offline)
```json
// secrets/kek-master.json (OFFLINE STORAGE)
{
  "version": "1.0.0",
  "kek": "base64_encoded_master_key",
  "created": "2025-09-17T00:00:00Z",
  "algorithm": "AES-256-GCM",
  "salt": "random_salt_256bit"
}
```

### Registre Licences
```json
// licenses/issued.json
{
  "version": "1.0.0",
  "licenses": [
    {
      "id": "ACME-2025-0001",
      "client": "ACME Corporation",
      "issued": "2025-09-17T10:00:00Z",
      "expires": "2026-12-31T23:59:59Z",
      "features": ["playback", "watermark"],
      "binding": { "usb": "auto", "machine": "optional" },
      "hash": "sha256_of_license_file",
      "status": "active"
    }
  ]
}
```

### Revocation Pack
```bash
# tools/create-revocation-pack.mjs
node tools/create-revocation-pack.mjs \
  --revoke "ACME-2025-0001,BETA-2025-0002" \
  --reason "security_incident" \
  --output "revocation-pack-2025-09-20.bin"
```

---

## 📋 **ÉTAPE 6: SUPPORT & DIAGNOSTICS** 🛠️

### Export Logs Automatique
```javascript
// Dans l'app: Menu Aide → Exporter Diagnostics
{
  "version": "1.0.0",
  "license_id": "ACME-2025-0001",
  "timestamp": "2025-09-17T15:30:00Z",
  "system": {
    "os": "Windows 11 Pro",
    "version": "22H2",
    "memory": "16GB",
    "gpu": "NVIDIA RTX 3080"
  },
  "vault": {
    "path": "G:\\USB-Video-Vault\\vault",
    "media_count": 15,
    "total_size": "2.3GB",
    "integrity": "OK"
  },
  "logs": [
    // Derniers 100 logs critiques
  ],
  "errors": [
    // Erreurs récentes
  ]
}
```

### Template Support Ticket
```markdown
## Support Ticket Template

**Client:** ________________
**Licence ID:** ________________
**Version App:** v1.0.0
**OS:** ________________
**Date/Heure:** ________________

**Problème:**
[ ] Licence expirée/rejetée
[ ] Vidéo ne démarre pas
[ ] Performance dégradée
[ ] Autre: ________________

**Message d'erreur exact:**
```
[Copier/coller ici]
```

**Fichiers joints:**
[ ] Export diagnostics (Menu Aide → Exporter)
[ ] Screenshot si applicable

**Email support:** support@usbvideovault.com
```

---

## 📋 **ÉTAPE 7: PUBLICATION & RELEASE** 📢

### GitHub Release Template
```markdown
# 🚀 USB Video Vault v1.0.0 (2025-09-17)

## 🔐 Sécurité Industrielle
- **AES-256-GCM** streaming encryption (tag 16o, nonce 12o/fichier)
- **Licence Ed25519** signée, binding USB/Machine configurable
- **Anti-rollback** protection horloge système
- **CSP + Sandbox** Electron durci

## 🎥 Fonctionnalités Vidéo
- **Double fenêtre** (contrôles / vidéo séparés)
- **Content Protection** + watermark dynamique
- **Multi-écran** support (F2: 2ème écran, F11: plein écran)
- **Playlist** sécurisée avec navigation fluide

## 📦 Outils Professionnels
- **CLI Packager** pour création clés client
- **Manifest chiffré** avec intégrité signée
- **Analytics locales** (stats.json)
- **Support diagnostics** intégré

## 💻 Compatibilité
- **Windows:** Portable .exe (signé Authenticode)
- **macOS:** App notarisée (.dmg)
- **Linux:** AppImage (signé GPG)

## 📁 Artefacts

| Fichier | Taille | SHA256 |
|---------|--------|--------|
| [USB-Video-Vault-1.0.0-win-portable.exe](releases/v1.0.0/USB-Video-Vault-1.0.0-win-portable.exe) | 120MB | `c1ec950...` |
| [USB-Video-Vault-1.0.0-mac.dmg](releases/v1.0.0/USB-Video-Vault-1.0.0-mac.dmg) | 125MB | `a2f4e81...` |
| [USB-Video-Vault-1.0.0-linux.AppImage](releases/v1.0.0/USB-Video-Vault-1.0.0-linux.AppImage) | 135MB | `b9c7d22...` |

**Vérification intégrité:** [SHA256SUMS](releases/v1.0.0/SHA256SUMS)
```

### Guide Utilisateur 1 Page
```markdown
# 🎥 USB Video Vault - Démarrage Rapide

## 🚀 Installation
1. **Branchez votre clé USB** sécurisée
2. **Lancez** `USB-Video-Vault.exe` (Windows) / `.app` (macOS) / `.AppImage` (Linux)
3. **Entrez le mot de passe** si demandé

## ▶️ Lecture Vidéo
1. **Choisissez une vidéo** dans la playlist
2. **Cliquez Lecture** ou double-clic
3. **Raccourcis utiles:**
   - `F2` : Envoyer sur 2ème écran
   - `F11` : Mode plein écran
   - `Espace` : Pause/Play
   - `←/→` : Navigation

## 🔒 Sécurité
- ✅ **Vidéos protégées** - lecture uniquement dans l'app
- ✅ **Licence liée** à votre matériel
- ✅ **Pas de copie possible** - protection totale

## ⚠️ Problèmes Courants

| Problème | Solution |
|----------|----------|
| "Licence expirée" | Contactez le support avec votre ID licence |
| "Horloge incohérente" | Corrigez l'heure de votre ordinateur |
| Vidéo ne démarre pas | Vérifiez que la clé USB est bien branchée |
| Performance lente | Vérifiez l'espace disque et fermer autres apps |

## 📞 Support
**Email:** support@usbvideovault.com  
**Export diagnostics:** Menu Aide → Exporter les journaux  
**Documentation:** [docs.usbvideovault.com](https://docs.usbvideovault.com)

---
*USB Video Vault v1.0.0 - Sécurité industrielle pour vos contenus vidéo*
```

---

## ⏱️ **TIMELINE GO-LIVE (72H)**

### Jour J-2 (Préparation)
- ✅ Checklist Go/No-Go 100%
- ✅ Build portable signé
- ✅ Package USB validé
- [ ] **Pilot users (5-10 clés)**

### Jour J-1 (Validation)
- [ ] **Soak test 48h complet**
- [ ] **Feedback pilot users**
- [ ] **Scripts signature prêts**
- [ ] **Release notes finalisées**

### Jour J (Release)
- [ ] **Tag v1.0.0 final**
- [ ] **Signature tous binaires**
- [ ] **GitHub Release publique**
- [ ] **Communication clients**

---

**🎯 GO-LIVE SUCCESS CRITERIA:**
- ✅ Zero critical bugs in pilot
- ✅ All signature scripts working
- ✅ Client USB packages validated
- ✅ Support process documented

**🚀 READY FOR PRODUCTION DEPLOYMENT**