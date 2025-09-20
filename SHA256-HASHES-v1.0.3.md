# Empreintes SHA256 - Release v1.0.3

## Exécutables principaux

| Fichier | Taille | SHA256 | Usage |
|---------|---------|---------|-------|
| `USB Video Vault.exe` | 180,849,664 bytes | `46a45b69553a17d53b6fc84fb83b3fada5eac9eb7b6a5f97df2df7833516b86d` | Exécutable principal (unpacked) |
| `USB-Video-Vault-0.1.0-portable.exe` | 144,596,261 bytes | `c1ec9506dfff58eaad11a4cbabab286a81c863b7d73ce0f63049de4eb216fb00` | Version portable (distribution) |

## SBOM (Software Bill of Materials)

| Fichier | Taille | Format | Générateur |
|---------|---------|---------|-----------|
| `sbom-v1.0.3.json` | 25,048 bytes | CycloneDX JSON | @cyclonedx/cyclonedx-npm@4.0.2 |

## Vérification d'intégrité

### PowerShell
```powershell
# Vérifier l'exécutable principal
CertUtil -hashfile "dist\win-unpacked\USB Video Vault.exe" SHA256

# Vérifier la version portable  
CertUtil -hashfile "usb-package\USB-Video-Vault-0.1.0-portable.exe" SHA256

# Vérifier le SBOM
CertUtil -hashfile "sbom-v1.0.3.json" SHA256
```

### Script de validation automatique
```powershell
# validate-hashes.ps1
$expectedHashes = @{
    "dist\win-unpacked\USB Video Vault.exe" = "46a45b69553a17d53b6fc84fb83b3fada5eac9eb7b6a5f97df2df7833516b86d"
    "usb-package\USB-Video-Vault-0.1.0-portable.exe" = "c1ec9506dfff58eaad11a4cbabab286a81c863b7d73ce0f63049de4eb216fb00"
}

foreach ($file in $expectedHashes.Keys) {
    if (Test-Path $file) {
        $actualHash = (CertUtil -hashfile $file SHA256 | Select-String "^\w{64}$").Matches[0].Value
        if ($actualHash -eq $expectedHashes[$file]) {
            Write-Host "✅ $file : Hash valide" -ForegroundColor Green
        } else {
            Write-Host "❌ $file : Hash invalide!" -ForegroundColor Red
            Write-Host "   Attendu: $($expectedHashes[$file])"
            Write-Host "   Actuel:  $actualHash"
        }
    } else {
        Write-Host "⚠️ $file : Fichier introuvable" -ForegroundColor Yellow
    }
}
```

## Métadonnées de release

- **Date de génération** : 2025-01-19
- **Tag Git** : v1.0.3  
- **Environnement** : Windows 11, Node.js, Electron, npm
- **Outil SBOM** : CycloneDX npm v4.0.2
- **Outil hash** : CertUtil (Windows builtin)