# Guide d'installation pour utilisateurs finaux
# Ce fichier sera inclus dans les releases GitHub

# 🚀 Guide d'installation USB Video Vault

## Installation rapide (recommandée)

### Option 1: Gestionnaire de packages Windows
```powershell
# Windows Package Manager (Windows 10 1809+)
winget install Yindo.USBVideoVault

# Chocolatey (si installé)
choco install usbvideovault
```

### Option 2: Téléchargement direct
1. **Télécharger** le fichier `USB Video Vault Setup 0.1.5.exe` depuis [GitHub Releases](https://github.com/150781/Yindo-USB-Video-Vault/releases/latest)
2. **Vérifier l'intégrité** (recommandé) :
   ```powershell
   certutil -hashfile "USB Video Vault Setup 0.1.5.exe" SHA256
   # Comparer avec le hash dans SHA256SUMS
   ```
3. **Exécuter l'installateur** en double-cliquant
4. **Suivre l'assistant** d'installation (2-3 clics)

## Configuration système requise

| Composant | Minimum | Recommandé |
|-----------|---------|-------------|
| **OS** | Windows 10 (1909) | Windows 11 |
| **Processeur** | x64 compatible | Intel Core i3 / AMD Ryzen 3 |
| **RAM** | 4 GB | 8 GB+ |
| **Espace disque** | 500 MB | 2 GB+ |
| **Résolution** | 1280x720 | 1920x1080+ |
| **.NET Framework** | 4.8+ | Dernière version |

## Installation entreprise/IT

### Installation silencieuse
```powershell
# Installation automatique (pas d'interface)
.\USB_Video_Vault_Setup_0.1.5.exe /S

# Vérification post-installation
Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*USB Video Vault*" }
```

### Déploiement en masse
```powershell
# Script pour déploiement sur plusieurs postes
$computers = @("PC001", "PC002", "PC003")
$installer = "\\server\share\USB_Video_Vault_Setup_0.1.5.exe"

foreach ($computer in $computers) {
    Invoke-Command -ComputerName $computer -ScriptBlock {
        Start-Process -FilePath $using:installer -ArgumentList "/S" -Wait
    }
}
```

## Problèmes fréquents

### 🛡️ Windows SmartScreen bloque l'installation
**Symptôme** : Message "Windows a protégé votre PC"
**Solution** :
1. Cliquer sur "Informations complémentaires"
2. Cliquer sur "Exécuter quand même"
3. **Alternative** : Télécharger depuis GitHub officiel uniquement

### 🔐 L'antivirus bloque l'installation
**Symptôme** : Installation interrompue, fichier supprimé
**Solution** :
1. Ajouter une exception antivirus pour le fichier setup
2. Télécharger depuis GitHub officiel (signature Authenticode valide)
3. Vérifier SHA256 avant installation

### ❌ "Application ne peut pas démarrer"
**Symptôme** : Erreur au lancement après installation
**Solution** :
```powershell
# Diagnostic automatique
curl -O https://raw.githubusercontent.com/150781/Yindo-USB-Video-Vault/main/tools/diagnose-user-issue.ps1
.\diagnose-user-issue.ps1
```

### 🔧 Installation corrompue
**Symptôme** : App partiellement fonctionnelle
**Solution** : Réinstallation propre
```powershell
# Désinstallation complète
.\USB_Video_Vault_Setup_0.1.5.exe /S /UNINSTALL

# Attendre 30 secondes puis réinstaller
Start-Sleep 30
.\USB_Video_Vault_Setup_0.1.5.exe /S
```

## Mise à jour

### Mise à jour automatique (Winget)
```powershell
# Vérifier mise à jour disponible
winget list --upgrade-available | findstr "USB Video Vault"

# Mettre à jour
winget upgrade Yindo.USBVideoVault
```

### Mise à jour manuelle
1. Télécharger la nouvelle version depuis GitHub
2. Lancer le nouvel installateur (upgrade automatique)
3. Redémarrer l'application

## Désinstallation

### Méthode standard
1. **Panneau de configuration** → Programmes → USB Video Vault → Désinstaller
2. **Ou via Paramètres** → Applications → USB Video Vault → Désinstaller

### Désinstallation en ligne de commande
```powershell
# Désinstallation silencieuse
$uninstaller = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
    Where-Object { $_.DisplayName -like "*USB Video Vault*" } |
    Select-Object -ExpandProperty UninstallString

if ($uninstaller) {
    & $uninstaller.Replace('"', '') /S
}
```

## Support

### Diagnostic automatique
```powershell
# Télécharger script diagnostic
curl -O https://raw.githubusercontent.com/150781/Yindo-USB-Video-Vault/main/tools/diagnose-user-issue.ps1

# Exécuter diagnostic complet
.\diagnose-user-issue.ps1 -Issue "Description du problème" -ExportReport

# Joindre le fichier diagnostic-report-*.json au rapport de bug
```

### Canaux de support
- **🐛 Bugs** : [GitHub Issues](https://github.com/150781/Yindo-USB-Video-Vault/issues)
- **❓ Questions** : [GitHub Discussions](https://github.com/150781/Yindo-USB-Video-Vault/discussions)
- **📧 Sécurité** : security@yindo.com
- **📞 Enterprise** : support@yindo.com

### Informations à fournir
Lors d'un rapport de bug, inclure :
1. **Version OS** : `winver`
2. **Version app** : Menu → À propos
3. **Rapport diagnostic** : `.\diagnose-user-issue.ps1 -ExportReport`
4. **Description détaillée** du problème
5. **Étapes de reproduction**

## Sécurité

### Vérification authenticité
```powershell
# Vérifier signature Authenticode
Get-AuthenticodeSignature ".\USB Video Vault Setup 0.1.5.exe"
# Status doit être "Valid"

# Vérifier hash SHA256
certutil -hashfile "USB Video Vault Setup 0.1.5.exe" SHA256
# Comparer avec SHA256SUMS officiel
```

### Bonnes pratiques
- ✅ Télécharger uniquement depuis GitHub officiel
- ✅ Vérifier signatures Authenticode
- ✅ Maintenir Windows à jour
- ✅ Utiliser antivirus moderne
- ❌ Ne pas télécharger depuis sites tiers
- ❌ Ne pas désactiver signature verification

---

**Questions fréquentes** : [FAQ](https://github.com/150781/Yindo-USB-Video-Vault/wiki/FAQ)
**Documentation complète** : [Wiki](https://github.com/150781/Yindo-USB-Video-Vault/wiki)
**Changelog** : [Releases](https://github.com/150781/Yindo-USB-Video-Vault/releases)
