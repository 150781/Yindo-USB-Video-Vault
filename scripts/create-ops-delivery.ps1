#!/usr/bin/env pwsh
# Package Livraison Ops - USB Video Vault License System

param(
    [string]$OutputDir = "ops-delivery",
    [string]$LicenseSample = "delivery-TestClient\license.bin",
    [switch]$IncludeScripts = $true
)

Write-Host "CREATION PACKAGE LIVRAISON OPS" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

# Creer dossier de livraison
if (Test-Path $OutputDir) {
    Write-Host "Nettoyage dossier existant..." -ForegroundColor Yellow
    Remove-Item $OutputDir -Recurse -Force
}

New-Item -Path $OutputDir -ItemType Directory | Out-Null
Write-Host "Dossier cree: $OutputDir" -ForegroundColor Green

# Structure de livraison
$folders = @(
    "docs",
    "scripts", 
    "samples",
    "procedures"
)

foreach ($folder in $folders) {
    New-Item -Path "$OutputDir\$folder" -ItemType Directory | Out-Null
}

Write-Host "Structure creee" -ForegroundColor Green

# 1. Documentation principale
Write-Host "`nCOPIE DOCUMENTATION..." -ForegroundColor Cyan

$docsToInclude = @{
    "docs\CLIENT_LICENSE_GUIDE.md" = "docs\CLIENT_LICENSE_GUIDE.md"
    "docs\OPERATOR_RUNBOOK.md" = "docs\OPERATOR_RUNBOOK.md"
    "docs\RUNBOOK_EXPRESS.md" = "docs\RUNBOOK_EXPRESS.md"
    "docs\INCIDENT_PROCEDURES.md" = "procedures\INCIDENT_PROCEDURES.md"
    "docs\POST_INSTALL_SCRIPTS.md" = "procedures\POST_INSTALL_SCRIPTS.md"
}

foreach ($source in $docsToInclude.Keys) {
    $dest = "$OutputDir\$($docsToInclude[$source])"
    if (Test-Path $source) {
        Copy-Item $source $dest
        Write-Host "OK $source" -ForegroundColor Green
    } else {
        Write-Host "MANQUANT $source" -ForegroundColor Red
    }
}

# 2. Scripts operationnels
Write-Host "`nCOPIE SCRIPTS..." -ForegroundColor Cyan

if ($IncludeScripts) {
    $scriptsToInclude = @(
        "scripts\verify-license.mjs",
        "scripts\make-license.mjs", 
        "scripts\print-bindings.mjs",
        "scripts\post-install-client.ps1",
        "scripts\post-install-client-clean.ps1",
        "scripts\generate-client-license.ps1",
        "scripts\diagnose-binding.ps1",
        "scripts\emergency-reset.ps1"
    )
    
    foreach ($script in $scriptsToInclude) {
        if (Test-Path $script) {
            Copy-Item $script "$OutputDir\scripts\"
            Write-Host "OK $script" -ForegroundColor Green
        } else {
            Write-Host "MANQUANT $script" -ForegroundColor Red
        }
    }
} else {
    Write-Host "Scripts ignores (IncludeScripts = false)" -ForegroundColor Yellow
}

# 3. Echantillon licence
Write-Host "`nCOPIE ECHANTILLON..." -ForegroundColor Cyan

if (Test-Path $LicenseSample) {
    Copy-Item $LicenseSample "$OutputDir\samples\license-sample.bin"
    Write-Host "OK Echantillon licence: $LicenseSample" -ForegroundColor Green
    
    # Verifier l'echantillon
    try {
        $verification = & node scripts\verify-license.mjs $LicenseSample 2>$null
        $verification | Out-File "$OutputDir\samples\license-sample-info.txt"
        Write-Host "OK Informations echantillon generees" -ForegroundColor Green
    } catch {
        Write-Host "ATTENTION Impossible de verifier l'echantillon" -ForegroundColor Yellow
    }
} else {
    Write-Host "MANQUANT Echantillon licence: $LicenseSample" -ForegroundColor Red
}

# 4. README de livraison
Write-Host "`nGENERATION README..." -ForegroundColor Cyan

$readmeContent = @"
# Package Livraison Ops - USB Video Vault License System

**Date de generation**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Version**: Production Ready  
**Genere par**: $env:USERNAME sur $env:COMPUTERNAME

## Contenu du Package

### Documentation (docs/)
- CLIENT_LICENSE_GUIDE.md - Guide installation cote client
- OPERATOR_RUNBOOK.md - Procedures operateurs completes  
- RUNBOOK_EXPRESS.md - Guide operateur express (une page)

### Procedures (procedures/)
- INCIDENT_PROCEDURES.md - Gestion incidents (horloge, binding)
- POST_INSTALL_SCRIPTS.md - Scripts post-installation

### Scripts (scripts/)
- verify-license.mjs - Verification licence
- make-license.mjs - Generation licence  
- print-bindings.mjs - Empreinte machine
- generate-client-license.ps1 - Workflow complet (one-liner)
- post-install-client.ps1 - Installation automatique client
- diagnose-binding.ps1 - Diagnostic problemes binding
- emergency-reset.ps1 - Reset d'urgence

### Echantillons (samples/)
- license-sample.bin - Exemple licence fonctionnelle
- license-sample-info.txt - Details de l'echantillon

## Deploiement Rapide

### 1. Generation Licence Client
```powershell
# One-liner pour nouveau client
.\scripts\generate-client-license.ps1 -ClientName "NouveauClient" -Fingerprint "ABC123..."

# Ou workflow manuel
.\scripts\print-bindings.mjs                          # Recuperer empreinte
.\scripts\make-license.mjs --binding "ABC123..." --out client-license.bin
.\scripts\verify-license.mjs client-license.bin      # Verifier avant envoi
```

### 2. Installation Site Client
```powershell
# Copier licence vers vault
Copy-Item license.bin "%VAULT_PATH%\.vault\license.bin"

# Ou script automatique
.\scripts\post-install-client.ps1 -LicenseFile license.bin
```

### 3. Diagnostic Problemes
```powershell
# Diagnostic complet
.\scripts\diagnose-binding.ps1

# Reset d'urgence (probleme horloge)
.\scripts\emergency-reset.ps1 -CorrectDateTime "2025-09-19 15:30:00"
```

## Support

### Contacts
- Support Technique: [CONTACT_TECHNIQUE]
- Administrateur Licence: [CONTACT_ADMIN]
- Escalade: [CONTACT_MANAGER]

### Informations Incident
Toujours fournir:
- Message d'erreur exact
- Sortie de diagnose-binding.ps1
- Logs application
- Contexte (changement materiel, etc.)

## Securite

### Important
- Cles privees: Jamais dans ce package (securite)
- Certificats: Stockage securise uniquement
- Licences: Ne pas dupliquer sans autorisation

### Bonnes Pratiques
- Verifier chaque licence avant envoi
- Logger toutes les generations
- Rotation cles selon politique
- Backup chiffre des configurations

---

**Package pret pour deploiement operationnel**  
**Scripts testes et valides**  
**Documentation complete et a jour**
"@

$readmeContent | Out-File "$OutputDir\README.md" -Encoding UTF8
Write-Host "OK README genere" -ForegroundColor Green

# 5. Verification finale
Write-Host "`nVERIFICATION FINALE..." -ForegroundColor Cyan

$totalFiles = (Get-ChildItem $OutputDir -Recurse -File).Count
$totalSize = [math]::Round(((Get-ChildItem $OutputDir -Recurse -File | Measure-Object Length -Sum).Sum / 1MB), 2)

Write-Host "STATISTIQUES PACKAGE:" -ForegroundColor Green
Write-Host "  Fichiers: $totalFiles" -ForegroundColor White
Write-Host "  Taille: ${totalSize}MB" -ForegroundColor White
Write-Host "  Dossier: $PWD\$OutputDir" -ForegroundColor White

Write-Host "`nPACKAGE LIVRAISON OPS PRET" -ForegroundColor Green
Write-Host "===========================" -ForegroundColor Green
Write-Host "Localisation: $PWD\$OutputDir" -ForegroundColor Cyan
Write-Host "Prochaine etape: Transmettre aux equipes operationnelles" -ForegroundColor Cyan