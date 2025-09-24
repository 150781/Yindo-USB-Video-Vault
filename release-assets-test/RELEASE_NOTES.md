# USB Video Vault v0.1.4

## Nouvelle version stable

### Fonctionnalites principales
- **Gestion securisee des medias** : Chiffrement AES-256 des fichiers video
- **Systeme de licences** : Licences liees au materiel pour la protection
- **Interface moderne** : Interface utilisateur Electron avec gestion des playlists
- **Installation silencieuse** : Support IT avec switches /S et /D=path

### Securite
- Binaires signes avec certificat Authenticode (si disponible)
- Audit de securite : Score 84.2% 
- SBOM (Software Bill of Materials) inclus pour la compliance
- Checksums SHA256 verifies

### Installation

#### Windows (Recommande)
`powershell
# Installation normale
.\USB Video Vault Setup 0.1.4.exe

# Installation silencieuse (IT/Admin)
.\USB Video Vault Setup 0.1.4.exe /S

# Installation dans un dossier specifique
.\USB Video Vault Setup 0.1.4.exe /S /D=C:\MonDossier\USBVideoVault
`

### Support technique

En cas de probleme, executez le script de diagnostic :
`powershell
.\troubleshoot.ps1 -Detailed -CollectLogs
`

**Canaux de support :**
- GitHub Issues : Signaler un probleme
- Documentation : Guide utilisateur

### Checksums SHA256
Voir fichier SHA256SUMS inclus

---

**Installation testee sur :** Windows 10/11 (x64)  
**Prerequis :** Aucun (runtime inclus)  
**Taille d'installation :** ~200MB  
