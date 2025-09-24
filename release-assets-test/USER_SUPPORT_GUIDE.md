# Guide de support utilisateur - USB Video Vault

## 🚨 Problèmes fréquents et solutions

### 1. L'application ne démarre pas

**Symptômes :**
- Double-clic sans effet
- Erreur "L'application a cessé de fonctionner"
- Écran noir au démarrage

**Solutions :**

```powershell
# 1. Diagnostic automatique
.\tools\support\troubleshoot.ps1 -Detailed

# 2. Redémarrage en mode sans échec
"USB Video Vault.exe" --safe-mode

# 3. Réinitialisation des préférences
Remove-Item "$env:APPDATA\USB Video Vault\config.json" -Force
```

### 2. Vidéos qui ne se lisent pas

**Symptômes :**
- Écran noir lors de la lecture
- Message "Format non supporté"
- Audio sans image

**Solutions :**

```powershell
# Vérifier les codecs installés
ffmpeg -codecs | findstr h264

# Tester avec une vidéo de référence
.\tools\support\test-playback.ps1 -TestFile ".\test-media\sample.mp4"

# Convertir la vidéo au format supporté
ffmpeg -i input.mp4 -c:v libx264 -c:a aac output.mp4
```

### 3. Problèmes de performances

**Symptômes :**
- Interface lente/saccadée
- Consommation mémoire élevée
- Ventilateur qui s'emballe

**Solutions :**

```powershell
# Monitorer les ressources
Get-Process "USB Video Vault" | Select-Object CPU,WorkingSet64

# Nettoyer le cache
Remove-Item "$env:APPDATA\USB Video Vault\cache" -Recurse -Force

# Réduire la qualité de rendu
# Dans l'app : Paramètres > Qualité > "Performance"
```

### 4. Synchronisation vault USB

**Symptômes :**
- "Vault non trouvé" sur clé USB
- Fichiers corrompus après copie
- Lenteur de synchronisation

**Solutions :**

```powershell
# Vérifier l'intégrité du vault
.\tools\packager\pack.js verify --vault "E:\vault"

# Reconstruire la clé USB
.\rebuild-vault.cmd

# Tester la clé USB
chkdsk E: /f /r
```

## 🔧 Outils de diagnostic

### Script principal
```powershell
# Diagnostic complet
.\tools\support\troubleshoot.ps1 -Detailed -CollectLogs -FixPermissions

# Vérification rapide
.\tools\support\troubleshoot.ps1
```

### Tests spécifiques
```powershell
# Test de lecture vidéo
.\tools\support\test-playback.ps1

# Test des formats supportés
.\tools\support\test-formats.ps1

# Test de performance
.\tools\support\benchmark.ps1
```

## 📋 Informations système

### Via l'interface
1. Menu **Aide** > **Informations système**
2. Bouton **Copier** pour le support
3. **Ouvrir logs** pour les détails

### Via PowerShell
```powershell
# Informations complètes
Get-ComputerInfo | Select-Object WindowsProductName,TotalPhysicalMemory,CsProcessors

# Versions installées
node --version
npm --version
```

## 🎯 Scénarios de test utilisateur

### Test 1 : Installation propre
```powershell
# 1. Désinstaller via Windows
# 2. Nettoyer les restes
Remove-Item "$env:APPDATA\USB Video Vault" -Recurse -Force
Remove-Item "$env:LOCALAPPDATA\USB Video Vault" -Recurse -Force

# 3. Réinstaller
.\USB-Video-Vault-Setup-*.exe

# 4. Premier lancement
Start-Process "USB Video Vault"
```

### Test 2 : Migration de données
```powershell
# Sauvegarder la config utilisateur
Copy-Item "$env:APPDATA\USB Video Vault" ".\backup-config" -Recurse

# Après réinstallation
Copy-Item ".\backup-config\*" "$env:APPDATA\USB Video Vault" -Recurse
```

### Test 3 : Utilisation multi-utilisateur
```powershell
# Créer un utilisateur de test
net user testuser /add
# Tester l'installation par utilisateur
```

## 🚀 Optimisations recommandées

### Performances système
- **RAM :** Minimum 4GB, recommandé 8GB+
- **Stockage :** SSD pour les performances de lecture
- **Codecs :** K-Lite Codec Pack ou LAV Filters

### Configuration Windows
```powershell
# Désactiver l'économie d'énergie pour USB
Get-WmiObject Win32_USBHub | ForEach-Object {
    $_.SetPowerManagementEnabled($false)
}

# Optimiser les performances multimédia
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio" /v "GPU Priority" /t REG_DWORD /d 8 /f
```

## 📞 Escalade vers le support technique

### Informations à fournir
1. **Version exact :** Menu Aide > À propos
2. **Système :** Sortie de `troubleshoot.ps1 -Detailed`
3. **Logs :** Dossier généré par `-CollectLogs`
4. **Reproduction :** Étapes exactes du problème

### Canaux de support
- **GitHub Issues :** https://github.com/user/USB-Video-Vault/issues
- **Documentation :** https://github.com/user/USB-Video-Vault/wiki
- **FAQ :** https://github.com/user/USB-Video-Vault/discussions

### Informations sensibles
⚠️ **Ne jamais partager :**
- Clés de chiffrement
- Noms de fichiers personnels
- Chemins complets vers données utilisateur
