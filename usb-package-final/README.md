# Yindo USB Video Vault

## 🚀 Lancement rapide

### Windows
Double-cliquez sur **Launch-USB-Video-Vault.bat**

### PowerShell
```powershell
.\Launch-USB-Video-Vault.ps1
```

### Manuel
```bash
USB-Video-Vault.exe --no-sandbox
```

## 📁 Structure

- **USB-Video-Vault.exe** : Application portable
- **vault/** : Coffre-fort chiffré avec médias
- **tools/** : Outils CLI pour packaging
- **docs/** : Documentation complète
- **Launch-*.*** : Scripts de lancement

## 🔒 Sécurité

✅ **AES-256-GCM** : Chiffrement streaming des médias
✅ **Ed25519** : Signatures cryptographiques
✅ **Device binding** : Liaison sécurisée USB
✅ **Anti-tamper** : Protection contre modification
✅ **Sandbox** : Isolation processus Electron

## ⚙️ Outils CLI

### Ajouter des médias
```bash
cd tools/packager
node pack.js add-media --vault ../../vault --file video.mp4
```

### Sceller le vault
```bash
node pack.js seal --vault ../../vault --pass "motdepasse"
```

### Lister le contenu
```bash
node pack.js list --vault ../../vault --pass "motdepasse"
```

## 📊 Licence

Licence valide jusqu'au : **2025-12-31**
Features : **playback, watermark, stats**

---
**Yindo USB Video Vault v0.1.0** - Lecture sécurisée portable
