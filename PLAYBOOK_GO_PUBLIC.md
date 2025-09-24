# MINI PLAYBOOK GO-PUBLIC - USB Video Vault
# Guide pratique pour lancement public propre et professionnel

## 1. 🔐 CERTIFICAT & SIGNATURE (SmartScreen-ready)

### A. Acquisition certificat
```bash
# Recommandations par ordre de preference:
# 1. EV (Extended Validation) - Reputation immediate SmartScreen
# 2. OV (Organization Validation) - Reputation rapide (quelques jours)
# 3. Code Signing standard - Reputation plus lente

# Fournisseurs recommandes:
# - DigiCert (premium, reputation excellente)
# - Sectigo/Comodo (bon rapport qualite/prix)
# - GlobalSign (alternatif serieux)
```

### B. Configuration GitHub Actions
```powershell
# Exporter certificat au format PFX
# Encoder en Base64
$certBytes = [System.IO.File]::ReadAllBytes(".\path\to\cert.pfx")
$certBase64 = [System.Convert]::ToBase64String($certBytes)
Write-Output $certBase64 # → Copier dans GitHub Secrets

# GitHub → Settings → Secrets and variables → Actions:
# WINDOWS_CERT_BASE64 = <base64_du_pfx>
# WINDOWS_CERT_PASSWORD = <mot_de_passe_cert>
```

### C. Release avec signature
```bash
# Creer et pousser tag pour declencher build signe
git tag v0.1.5
git push origin v0.1.5

# Verifier workflow GitHub Actions
# Telecharger assets signes une fois prets
```

### D. Verification signature locale
```powershell
# Test 1: Verification signature Authenticode
signtool verify /pa /v ".\USB Video Vault Setup 0.1.5.exe"

# Test 2: Verification PowerShell
$sig = Get-AuthenticodeSignature ".\USB Video Vault Setup 0.1.5.exe"
Write-Host "Status: $($sig.Status)"
Write-Host "Signer: $($sig.SignerCertificate.Subject)"
Write-Host "Timestamp: $($sig.TimeStamperCertificate.NotAfter)"

# Test 3: Verification dans l'Explorateur Windows
# Clic droit > Proprietes > Signatures numeriques
```

### E. Astuces SmartScreen
- ✅ Signer SETUP + PORTABLE avec même certificat
- ✅ Utiliser timestamp authority (Sectigo/DigiCert)
- ✅ Publisher name stable (pas de changement)
- ✅ Schema nommage coherent (USB Video Vault vX.Y.Z)
- 📊 Reputation: ~100-500 installations pour reputation positive

---

## 2. 📦 WINGET (Publication Microsoft Store)

### A. Preparation manifest final
```yaml
# packaging/winget/Yindo.USBVideoVault.yaml
PackageIdentifier: Yindo.USBVideoVault
PackageVersion: 0.1.5
InstallerType: nullsoft
Scope: machine
InstallerSwitches:
  Silent: "/S"
  SilentWithProgress: "/S"
  InstallLocation: "/D={InstallLocation}"
InstallerUrl: https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v0.1.5/USB Video Vault Setup 0.1.5.exe
InstallerSha256: <SHA256_REEL_APRES_BUILD>
```

### B. Test local avant soumission
```powershell
# Test installation via manifest local
winget install --manifest .\packaging\winget\ --accept-source-agreements

# Test desinstallation
winget uninstall Yindo.USBVideoVault

# Validation manifest
winget validate .\packaging\winget\Yindo.USBVideoVault.yaml
```

### C. Soumission via PR
```bash
# Fork microsoft/winget-pkgs
# Creer branch: yindo-usbvideovault-0.1.5
# Copier manifests dans manifests/y/Yindo/USBVideoVault/0.1.5/
# Ouvrir PR avec titre: "New version: Yindo.USBVideoVault version 0.1.5"
```

---

## 3. 🍫 CHOCOLATEY (Publication Community)

### A. Mise à jour package avec checksum reel
```powershell
# Calculer checksum apres build signe
$hash = (Get-FileHash "USB Video Vault Setup 0.1.5.exe" -Algorithm SHA256).Hash
Write-Host "SHA256: $hash"

# Mettre a jour chocolateyinstall.ps1
$checksum = $hash
$url = "https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v0.1.5/USB Video Vault Setup 0.1.5.exe"
```

### B. Build et test package
```powershell
# Build package Chocolatey
choco pack .\packaging\chocolatey\usbvideovault.nuspec

# Test installation locale
choco install usbvideovault -source .

# Test desinstallation
choco uninstall usbvideovault
```

### C. Publication (apres moderation)
```powershell
# Publication sur community feed
choco push usbvideovault.0.1.5.nupkg --api-key <CHOCO_API_KEY>

# Suivi moderation: https://community.chocolatey.org/packages/usbvideovault
```

---

## 4. 🚀 GITHUB RELEASE - Assets optimaux

### Assets à joindre obligatoirement:
- ✅ `USB Video Vault Setup 0.1.5.exe` (SIGNE)
- ✅ `USB Video Vault 0.1.5.exe` (portable, SIGNE)
- ✅ `SHA256SUMS` (checksums)
- ✅ `SHA256SUMS.asc` (signature GPG si disponible)
- ✅ `SBOM.json` (Software Bill of Materials)
- ✅ `RELEASE_NOTES.md` (notes de version)
- ✅ `troubleshoot.ps1` (support utilisateur)

### Script de publication automatique:
```powershell
# Utiliser notre script prepare-release-assets.ps1
.\tools\prepare-release-assets.ps1 -Version "0.1.5"

# Publication GitHub CLI
gh release create v0.1.5 \
    --title "USB Video Vault v0.1.5" \
    --notes-file ".\release-assets\RELEASE_NOTES.md" \
    .\release-assets\*
```

---

## 5. 🖥️ SMOKE TESTS FINAUX (VM propre)

### Tests installation silencieuse:
```powershell
# Test 1: Installation silencieuse
Start-Process ".\USB Video Vault Setup 0.1.5.exe" -ArgumentList "/S" -Wait
if (Test-Path "$Env:ProgramFiles\USB Video Vault\USB Video Vault.exe") {
    Write-Host "✅ Installation OK"
} else {
    Write-Host "❌ Installation echec"
}

# Test 2: Lancement application
& "$Env:ProgramFiles\USB Video Vault\USB Video Vault.exe"
Start-Sleep 5

# Test 3: Fermeture propre
Get-Process "USB Video Vault" -ErrorAction SilentlyContinue | Stop-Process -Force

# Test 4: Desinstallation silencieuse
Start-Process "$Env:ProgramFiles\USB Video Vault\Uninstall USB Video Vault.exe" -ArgumentList "/S" -Wait
if (-not (Test-Path "$Env:ProgramFiles\USB Video Vault\")) {
    Write-Host "✅ Desinstallation OK"
}
```

### Script automatise VM tests:
```powershell
# Utiliser notre script final-vm-tests.ps1
.\tools\final-vm-tests.ps1 -SetupPath ".\USB Video Vault Setup 0.1.5.exe" -Automated
```

---

## 6. 📊 POST-RELEASE (48h critiques)

### Monitoring automatique:
```powershell
# Demarrer surveillance 48h
.\tools\monitor-release.ps1 -Version "0.1.5" -Hours 48
```

### Points de surveillance:
- 📈 **Telechargements**: GitHub Insights/Releases
- 🚨 **Issues utilisateur**: "Install", "SmartScreen", "Crash"
- 🛡️ **SmartScreen reputation**: Feedback utilisateurs
- 📊 **Metriques**: Taux installation/echec

### Support utilisateur reactif:
```powershell
# Script diagnostic pour utilisateurs
.\tools\support\troubleshoot.ps1 -Detailed -CollectLogs

# Reponse type issue SmartScreen:
"Windows SmartScreen peut alerter car l'application n'a pas encore
etabli sa reputation. Ceci est normal pour une nouvelle release.
L'executable est signe avec certificat Authenticode valide.
La reputation se construira automatiquement avec les installations."
```

---

## 7. 🔄 PLAN DE ROLLBACK (si urgence)

### Actions d'urgence:
```bash
# 1. Depublier GitHub Release
gh release edit v0.1.5 --prerelease

# 2. Restaurer version stable precedente
gh release edit v0.1.4 --latest

# 3. Rollback Winget (si deja merge)
# → Ouvrir issue microsoft/winget-pkgs pour retrait

# 4. Communication transparente
# → GitHub Issue: "Post-mortem v0.1.5 + rollback v0.1.4"
```

### Hotfix rapide:
```bash
# Patch critique sans changer major/minor
git tag v0.1.5-hotfix.1
# → Meme certificat, meme Publisher
# → Pipeline identique, juste version patch
```

### Post-mortem systematique:
```powershell
# Audit securite post-incident
.\tools\security\security-audit.ps1 -Detailed -Output "post-mortem-v0.1.5.json"

# Analyse causes racines + actions preventives
# Documentation lessons learned
```

---

## 🎯 CHECKLIST FINALE PRE-PUBLICATION

- [ ] Certificat Authenticode configure (EV/OV)
- [ ] GitHub Secrets configures (CERT_BASE64 + PASSWORD)
- [ ] Manifests Winget/Chocolatey avec SHA256 reels
- [ ] VM propre preparee pour smoke tests
- [ ] Monitoring post-release configure
- [ ] Plan rollback documente
- [ ] Canaux support actifs (GitHub Issues)

**🚀 Ready for public launch!**
