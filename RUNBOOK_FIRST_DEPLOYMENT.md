# RUNBOOK EXPRESS - Premier deploiement public USB Video Vault
# T-60 → T+60 minutes - Processus complet automatise

## 🎯 GO / NO-GO CHECKLIST (5 checks critiques)

### ✅ 1. Certificat Authenticode
- [ ] **EV (Extended Validation)** - Reputation SmartScreen immediate ⭐
- [ ] **OV (Organization Validation)** - Reputation rapide (7-30 jours)
- [ ] Certificat exporte en .pfx avec mot de passe
- [ ] Timestamp authority configure (Sectigo/DigiCert)

### ✅ 2. Secrets GitHub configures
```bash
# GitHub → Settings → Secrets and variables → Actions
WINDOWS_CERT_BASE64     = <base64_du_certificat.pfx>
WINDOWS_CERT_PASSWORD   = <mot_de_passe_cert>
GITHUB_TOKEN           = <token_pour_releases>
```

### ✅ 3. Build local valide
```powershell
npm run clean
npm run build
# ✅ Pas d'erreurs TypeScript/Vite
# ✅ Artefacts generes dans dist/
```

### ✅ 4. Smoke test VM propre
```powershell
.\tools\final-vm-tests.ps1 -SetupPath ".\dist\USB Video Vault Setup X.Y.Z.exe" -Automated
# ✅ Installation/desinstallation OK
# ✅ Lancement application OK
```

### ✅ 5. Manifests distribution prets
```powershell
# Winget: URL directe + SHA256 reel
InstallerUrl: "https://github.com/150781/Yindo-USB-Video-Vault/releases/download/vX.Y.Z/USB Video Vault Setup X.Y.Z.exe"
InstallerSha256: "<SHA256_REEL>"

# Chocolatey: Checksum reel dans chocolateyinstall.ps1
$checksum = '<SHA256_REEL>'
```

---

## ⏰ TIMELINE DEPLOIEMENT

### 🔧 T-60 min: PREPARATION
```powershell
# 1. Bump version dans package.json
npm version patch  # ou minor/major selon changements

# 2. Notes de release
# Editer CHANGELOG.md avec nouvelles fonctionnalites

# 3. Commit de release + tag
git add -A
git commit -m "chore(release): v0.1.5 - Ready for public release"
git tag v0.1.5
git push origin master --tags

# 4. Verifier GitHub Actions
# → Aller sur https://github.com/150781/Yindo-USB-Video-Vault/actions
# → Attendre completion workflow "Release"
# → Verifier artefacts signes publies
```

### 🔍 T-30 min: VERIFICATION ARTEFACTS
```powershell
# 1. Telecharger setup depuis GitHub Release
$setupUrl = "https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v0.1.5/USB Video Vault Setup 0.1.5.exe"
Invoke-WebRequest -Uri $setupUrl -OutFile ".\USB Video Vault Setup 0.1.5.exe"

# 2. Verification signature Authenticode
signtool verify /pa /v ".\USB Video Vault Setup 0.1.5.exe"
# ✅ Status: Valid
# ✅ Signer Certificate: [Votre organisation]
# ✅ Timestamp: Present et valide

# 3. Verification PowerShell
$sig = Get-AuthenticodeSignature ".\USB Video Vault Setup 0.1.5.exe"
Write-Host "Status: $($sig.Status)"          # Valid
Write-Host "Signer: $($sig.SignerCertificate.Subject)"
Write-Host "Timestamp: $($sig.TimeStamperCertificate.NotAfter)"

# 4. Calcul SHA256 REEL (critique!)
$realSha256 = (Get-FileHash ".\USB Video Vault Setup 0.1.5.exe" -Algorithm SHA256).Hash
Write-Host "SHA256 REEL: $realSha256"
# ⚠️ NOTER ce hash pour manifests!
```

### 🔧 T-25 min: MISE A JOUR MANIFESTS AVEC SHA256 REEL
```powershell
# 1. Winget manifest (installer.yaml)
# Remplacer:
# InstallerSha256: <PLACEHOLDER>
# Par:
# InstallerSha256: $realSha256

# 2. Chocolatey install script
# Dans packaging/chocolatey/tools/chocolateyinstall.ps1
# Remplacer:
# $checksum = '<PLACEHOLDER>'
# Par:
# $checksum = '$realSha256'

# 3. Commit manifests mis a jour
git add packaging/
git commit -m "fix: Update manifests with real SHA256 checksums"
git push origin master
```

### 🧪 T-20 min: TESTS INSTALLATION (VM PROPRE)
```powershell
# VM Windows 10/11 "propre" (sans USB Video Vault)

# 1. Test installation silencieuse
Measure-Command {
    Start-Process ".\USB Video Vault Setup 0.1.5.exe" -ArgumentList "/S" -Wait
}
# ✅ Installation < 2 minutes
# ✅ Pas d'erreurs/crashes

# 2. Verification installation
if (Test-Path "$Env:ProgramFiles\USB Video Vault\USB Video Vault.exe") {
    Write-Host "✅ Installation OK"
} else {
    Write-Host "❌ Installation ECHEC - ARRETER DEPLOIEMENT"
    exit 1
}

# 3. Test lancement application
& "$Env:ProgramFiles\USB Video Vault\USB Video Vault.exe"
Start-Sleep 10  # Laisser app se lancer
Get-Process "USB Video Vault" -ErrorAction SilentlyContinue | Stop-Process -Force

# 4. Test desinstallation
Start-Process "$Env:ProgramFiles\USB Video Vault\Uninstall USB Video Vault.exe" -ArgumentList "/S" -Wait
if (-not (Test-Path "$Env:ProgramFiles\USB Video Vault\")) {
    Write-Host "✅ Desinstallation OK"
} else {
    Write-Host "⚠️ Desinstallation incomplete"
}
```

### 📦 T-10 min: PUBLICATION MULTI-CANAUX

#### GitHub Release (finalisation)
```powershell
# 1. Ajouter assets manquants
gh release upload v0.1.5 .\dist\SHA256SUMS
gh release upload v0.1.5 .\dist\SBOM-USBVideoVault-v0.1.5.json

# 2. Finaliser notes de release
gh release edit v0.1.5 --notes-file .\RELEASE_NOTES_FINAL.md

# 3. Marquer comme latest (si pas deja fait)
gh release edit v0.1.5 --latest
```

#### Winget (Pull Request)
```bash
# 1. Fork microsoft/winget-pkgs si pas deja fait
# 2. Creer branche
git checkout -b yindo-usbvideovault-0.1.5

# 3. Copier manifests vers winget-pkgs
# manifests/y/Yindo/USBVideoVault/0.1.5/
#   ├── Yindo.USBVideoVault.yaml
#   ├── Yindo.USBVideoVault.installer.yaml
#   └── Yindo.USBVideoVault.locale.en-US.yaml

# 4. Ouvrir PR
# Titre: "New version: Yindo.USBVideoVault version 0.1.5"
```

#### Chocolatey (Community Feed)
```powershell
# 1. Build package avec checksum reel
choco pack .\packaging\chocolatey\usbvideovault.nuspec

# 2. Test local avant push
choco install usbvideovault -source . --force

# 3. Publication (si API key disponible)
# choco push usbvideovault.0.1.5.nupkg --api-key $env:CHOCO_API_KEY
```

---

### 📊 T+0 → T+60 min: MONITORING INTENSIF

```powershell
# 1. Demarrage monitoring automatique
.\tools\monitor-release.ps1 -Version "0.1.5" -Hours 1

# 2. Surveillance manuelle parallele
# - GitHub Release: Telechargements
# - Issues: Nouveaux rapports install/crash
# - SmartScreen: Feedback utilisateurs warnings
```

#### Metriques a surveiller:
- **Telechargements** : > 10 dans premiere heure = bon signe
- **Issues installation** : 0 ideal, < 2% acceptable
- **SmartScreen warnings** : Normal avec nouveau certificat OV
- **Crashes au demarrage** : 0 tolerance

---

## 🚨 TRIGGERS DE ROLLBACK

### Seuils critiques:
- ✅ **Taux echec installation > 3%** → Rollback immediat
- ✅ **Crashes recurrents au demarrage** → Rollback immediat
- ✅ **Probleme signature/certificat** → Rollback immediat
- ✅ **SmartScreen bloque completement** → Investigation (pas forcement rollback)

### Procedure rollback express:
```powershell
# ROLLBACK AUTOMATIQUE
.\tools\emergency-rollback.ps1 -FromVersion "0.1.5" -ToVersion "0.1.4" -Reason "Critical deployment issue" -Execute

# Actions manuelles post-rollback:
# 1. Update Winget PR (retrait version 0.1.5)
# 2. Chocolatey: Unlist package si deja publie
# 3. GitHub: Marquer release en prerelease
# 4. Communication: Issue transparente post-mortem
```

---

## ⚠️ PIEGES COURANTS & SOLUTIONS

### 🔥 Piege #1: SHA256 mismatch
**Symptome**: Winget/Chocolatey rejette installation
**Solution**:
```powershell
# Recalculer SHA256 du binaire re-telecharge
$correctHash = (Get-FileHash ".\USB Video Vault Setup 0.1.5.exe" -Algorithm SHA256).Hash
# Mettre a jour manifests avec hash correct
```

### 🔥 Piege #2: URL Winget incorrecte
**Symptome**: Winget telecharge HTML au lieu du .exe
**Solution**:
```yaml
# INCORRECT:
InstallerUrl: https://github.com/150781/Yindo-USB-Video-Vault/releases/tag/v0.1.5

# CORRECT:
InstallerUrl: https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v0.1.5/USB Video Vault Setup 0.1.5.exe
```

### 🔥 Piege #3: Signature sans timestamp
**Symptome**: Signature expire avec certificat
**Solution**:
```bash
# Ajouter timestamp dans workflow GitHub Actions
signtool sign /f cert.pfx /p password /t http://timestamp.sectigo.com /fd SHA256 setup.exe
```

### 🔥 Piege #4: SmartScreen panic
**Symptome**: "Tous les utilisateurs ont warnings SmartScreen"
**Solution**:
- ✅ **Normal avec certificat OV nouveau** - Continue installations
- ✅ **Reputation se construit** - 100-500 installs pour amelioration
- ✅ **Communication proactive** - Documenter dans Release Notes

---

## 🎯 COMMUNICATION POST-DEPLOIEMENT

### Template message utilisateurs SmartScreen:
```markdown
**Windows SmartScreen Warning - Normal Behavior**

Windows may display a SmartScreen warning for new releases. This is expected behavior as our application builds its reputation with Microsoft's systems.

✅ **The executable is properly signed** with a valid Authenticode certificate
✅ **Safe to install** - Click "More info" → "Run anyway"
✅ **Reputation improves** automatically with user installations

This warning will disappear as more users install the signed version.
```

---

## ✅ SUCCESS CRITERIA (T+60)

### Deployment reussi si:
- ✅ **0 crashes** reportes
- ✅ **< 2% echecs installation**
- ✅ **> 10 telechargements** premiere heure
- ✅ **Winget PR acceptee** ou en review
- ✅ **Issues support < 3** et traites
- ✅ **SmartScreen warnings** documentes et expliques

### Post-deploiement (24-48h):
- ✅ Monitoring continu actif
- ✅ Support reactif sur issues
- ✅ Communication proactive SmartScreen
- ✅ Reputation building en cours

---

**🚀 READY FOR FIRST PUBLIC DEPLOYMENT!**
