# Release Report - USB Video Vault v1.0.3-test

**Date de génération** : 2025-09-20 10:02:26  
**Environnement** : PATOKADI  
**Utilisateur** : patok  

## Fichiers de release

### Archive principale
- **Fichier** : USB-Video-Vault-v1.0.3-test-release.zip
- **Taille** : 224220009 bytes
- **SHA256** : 26c1e2240b53b76e785318026b7e1641d761f8fa2b603252c6a1ee9123f0fcab

### Exécutables inclus
- **dist\win-unpacked\USB Video Vault.exe**
  - Taille : 180849664 bytes
  - SHA256 : 46a45b69553a17d53b6fc84fb83b3fada5eac9eb7b6a5f97df2df7833516b86d
- **C:\Users\patok\Documents\Yindo-USB-Video-Vault\test-usb\USB-Video-Vault-0.1.0-portable.exe**
  - Taille : 692635688 bytes
  - SHA256 : 2cc268d97f4cd81c011fdf7df749d6f9d67fb99bce02b3871396aaeb95176730
- **C:\Users\patok\Documents\Yindo-USB-Video-Vault\usb-package\USB-Video-Vault-0.1.0-portable.exe**
  - Taille : 144597744 bytes
  - SHA256 : bc325ec86f75226ef7daa6dbc09b6a0867c7721da6a0ed4cd6e2411b7162a9d4
## Artefacts de release

- [ ] CHANGELOG.md - Journal des modifications
- [ ] SBOM (sbom-v1.0.3-test.json) - Bill of Materials CycloneDX
- [ ] Hashes SHA256 - Empreintes de vérification
- [ ] Documentation signatures - État de la signature de code
- [ ] Archive complète - Package de distribution

## Validation post-release

### Commandes de vérification

```powershell
# Vérifier l'intégrité de l'archive
CertUtil -hashfile USB-Video-Vault-v1.0.3-test-release.zip SHA256

# Extraire et vérifier les exécutables
Expand-Archive USB-Video-Vault-v1.0.3-test-release.zip -DestinationPath temp-verification
Get-ChildItem temp-verification\executables\*.exe | ForEach-Object {
    Write-Host "Vérification: $(.Name)"
    CertUtil -hashfile $_.FullName SHA256
    Get-AuthenticodeSignature $_.FullName
}
```

### Checklist de déploiement

- [ ] Archive téléchargée et vérifiée
- [ ] Hashes SHA256 validés
- [ ] Signatures Authenticode vérifiées
- [ ] SBOM analysé pour audit sécurité
- [ ] Documentation opérationnelle consultée
- [ ] Tests d'installation effectués

## Métadonnées

- **Tag Git** : v1.0.3-test
- **Commit** : 8b45835bb5bdcb7121ddb1f63141270c1c59a4a4
- **Branch** : master
- **Build timestamp** : 2025-09-20 10:02:26

---

*Ce rapport a été généré automatiquement par le script de release.*
