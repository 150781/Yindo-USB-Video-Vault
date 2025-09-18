# 🏷️ Git Release Automation Scripts

## Manual Tagging Script

### Windows PowerShell
```powershell
# scripts/create-release-tag.ps1

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [switch]$Push = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$Message = ""
)

Write-Host "🏷️ === GIT RELEASE TAGGING ===" -ForegroundColor Cyan

# Validation format version
if ($Version -notmatch '^v\d+\.\d+\.\d+(-rc\.\d+|-beta\.\d+)?$') {
    Write-Error "❌ Format version invalide. Utilisez: v1.0.0, v1.0.0-rc.1, v1.0.0-beta.1"
    exit 1
}

# Vérifier repo git
if (!(Test-Path ".git")) {
    Write-Error "❌ Pas dans un repo git"
    exit 1
}

# Status git propre
$status = git status --porcelain
if ($status) {
    Write-Warning "⚠️ Modifications non commitées détectées:"
    Write-Host $status
    $confirm = Read-Host "Continuer quand même? (y/N)"
    if ($confirm -ne 'y') {
        Write-Host "❌ Annulé"
        exit 1
    }
}

# Message par défaut
if (!$Message) {
    if ($Version -like "*-rc.*") {
        $Message = "Release Candidate $Version"
    } elseif ($Version -like "*-beta.*") {
        $Message = "Beta Release $Version"
    } else {
        $Message = "Release $Version"
    }
}

Write-Host "🔖 Création du tag: $Version" -ForegroundColor Yellow
Write-Host "💬 Message: $Message" -ForegroundColor Gray

# Créer tag annoté
try {
    git tag -a $Version -m $Message
    Write-Host "✅ Tag créé localement" -ForegroundColor Green
} catch {
    Write-Error "❌ Erreur création tag: $_"
    exit 1
}

# Push si demandé
if ($Push) {
    Write-Host "📤 Push du tag vers origin..." -ForegroundColor Yellow
    try {
        git push origin $Version
        Write-Host "✅ Tag pushé vers origin" -ForegroundColor Green
        
        # Déclencher GitHub Actions
        Write-Host "🤖 GitHub Actions devrait se déclencher automatiquement" -ForegroundColor Magenta
        Write-Host "🔗 Vérifiez: https://github.com/YOUR_ORG/usb-video-vault/actions" -ForegroundColor Blue
        
    } catch {
        Write-Error "❌ Erreur push tag: $_"
        Write-Host "💡 Tag créé localement, pushable manuellement avec: git push origin $Version"
        exit 1
    }
} else {
    Write-Host "📋 Tag créé localement uniquement" -ForegroundColor Yellow
    Write-Host "💡 Pour pousser: git push origin $Version" -ForegroundColor Blue
}

Write-Host "🎉 Tag $Version créé avec succès !" -ForegroundColor Green
```

### Usage Examples
```powershell
# Release Candidate
.\scripts\create-release-tag.ps1 -Version "v1.0.0-rc.1" -Push

# Production Release
.\scripts\create-release-tag.ps1 -Version "v1.0.0" -Message "First stable release" -Push

# Beta Release
.\scripts\create-release-tag.ps1 -Version "v1.1.0-beta.1"
```

---

## Automated Release Script

### Complete Release Pipeline
```powershell
# scripts/automated-release.ps1

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false
)

Write-Host "🚀 === AUTOMATED RELEASE PIPELINE ===" -ForegroundColor Cyan

$ErrorActionPreference = "Stop"

function Test-Prerequisites {
    Write-Host "🔍 Vérification prérequis..." -ForegroundColor Yellow
    
    # Git repo
    if (!(Test-Path ".git")) {
        throw "Pas dans un repo git"
    }
    
    # Node.js
    if (!(Get-Command node -ErrorAction SilentlyContinue)) {
        throw "Node.js non installé"
    }
    
    # NPM dependencies
    if (!(Test-Path "node_modules")) {
        throw "Dependencies non installées (npm ci)"
    }
    
    Write-Host "✅ Prérequis OK" -ForegroundColor Green
}

function Test-Quality {
    Write-Host "🧪 Tests qualité..." -ForegroundColor Yellow
    
    # TypeScript
    npm run test:typecheck
    if ($LASTEXITCODE -ne 0) { throw "TypeScript check failed" }
    
    # Go/No-Go
    node checklist-go-nogo.mjs
    if ($LASTEXITCODE -ne 0) { throw "Go/No-Go checklist failed" }
    
    # Red team
    node test-red-scenarios.mjs
    if ($LASTEXITCODE -ne 0) { throw "Red team tests failed" }
    
    Write-Host "✅ Tests qualité OK" -ForegroundColor Green
}

function Build-Artifacts {
    Write-Host "🏗️ Build des artefacts..." -ForegroundColor Yellow
    
    # Clean previous build
    if (Test-Path "dist") {
        Remove-Item "dist" -Recurse -Force
    }
    
    # Build
    npm run build
    npm run build:main
    npm run electron:build
    
    # Vérifier artefacts
    if (!(Test-Path "dist\USB-Video-Vault-*.exe")) {
        throw "Build Windows manquant"
    }
    
    Write-Host "✅ Build terminé" -ForegroundColor Green
}

function Sign-Binaries {
    param([switch]$DryRun)
    
    Write-Host "🖊️ Signature des binaires..." -ForegroundColor Yellow
    
    if ($DryRun) {
        Write-Host "🔄 DRY RUN - Signature simulée" -ForegroundColor Magenta
        return
    }
    
    # Windows Authenticode
    if ($env:WINDOWS_CERT_PATH -and $env:WINDOWS_CERT_PASSWORD) {
        .\scripts\signing\sign-windows.ps1 -ExePath "dist\USB-Video-Vault-*.exe"
    } else {
        Write-Warning "⚠️ Certificat Windows non configuré - signature ignorée"
    }
    
    Write-Host "✅ Signature terminée" -ForegroundColor Green
}

function Create-Packages {
    Write-Host "📦 Création packages..." -ForegroundColor Yellow
    
    # Demo USB package
    node tools/create-client-usb.mjs `
        --client "DEMO-RELEASE" `
        --media "./src/assets" `
        --output "./usb-demo-release" `
        --password "DEMO_RELEASE_2025" `
        --license-id "DEMO-RELEASE-2025" `
        --expires "2026-12-31T23:59:59Z"
    
    # Final ZIP
    Compress-Archive -Path "usb-demo-release\*" -DestinationPath "USB-Video-Vault-$Version-Demo.zip"
    
    Write-Host "✅ Packages créés" -ForegroundColor Green
}

function Generate-Hashes {
    Write-Host "🔢 Génération hashes..." -ForegroundColor Yellow
    
    $hashFile = "SHA256SUMS-$Version.txt"
    
    # Clear file
    "" | Out-File $hashFile
    
    # Windows
    $windowsExe = Get-ChildItem "dist\USB-Video-Vault-*.exe" | Select-Object -First 1
    if ($windowsExe) {
        $hash = (certutil -hashfile $windowsExe.FullName SHA256 | Select-String -Pattern "^[0-9a-f]{64}$").Line
        "$hash  $($windowsExe.Name)" | Out-File $hashFile -Append
    }
    
    # Demo package
    $demoZip = "USB-Video-Vault-$Version-Demo.zip"
    if (Test-Path $demoZip) {
        $hash = (certutil -hashfile $demoZip SHA256 | Select-String -Pattern "^[0-9a-f]{64}$").Line
        "$hash  $demoZip" | Out-File $hashFile -Append
    }
    
    Write-Host "✅ Hashes générés: $hashFile" -ForegroundColor Green
}

function Create-Release-Tag {
    param([string]$Version, [switch]$DryRun)
    
    Write-Host "🏷️ Création tag release..." -ForegroundColor Yellow
    
    if ($DryRun) {
        Write-Host "🔄 DRY RUN - Tag non créé" -ForegroundColor Magenta
        return
    }
    
    $message = "Release $Version - Automated pipeline"
    git tag -a $Version -m $message
    git push origin $Version
    
    Write-Host "✅ Tag $Version créé et pushé" -ForegroundColor Green
}

# ===== EXECUTION PIPELINE =====

try {
    Write-Host "🎯 Version: $Version" -ForegroundColor Cyan
    
    if ($DryRun) {
        Write-Host "🔄 MODE DRY RUN - Aucune modification permanente" -ForegroundColor Magenta
    }
    
    # 1. Prérequis
    Test-Prerequisites
    
    # 2. Qualité
    Test-Quality
    
    # 3. Build
    Build-Artifacts
    
    # 4. Signature
    Sign-Binaries -DryRun:$DryRun
    
    # 5. Packages
    Create-Packages
    
    # 6. Hashes
    Generate-Hashes
    
    # 7. Tag (déclenche CI)
    Create-Release-Tag -Version $Version -DryRun:$DryRun
    
    Write-Host ""
    Write-Host "🎉 === RELEASE COMPLETED ===" -ForegroundColor Green
    Write-Host "🏷️ Version: $Version" -ForegroundColor White
    Write-Host "📁 Artefacts: dist\, USB-Video-Vault-$Version-Demo.zip" -ForegroundColor White
    Write-Host "🔢 Hashes: SHA256SUMS-$Version.txt" -ForegroundColor White
    
    if (!$DryRun) {
        Write-Host "🤖 GitHub Actions déclenchées automatiquement" -ForegroundColor Magenta
        Write-Host "🔗 https://github.com/YOUR_ORG/usb-video-vault/actions" -ForegroundColor Blue
    }
    
} catch {
    Write-Host ""
    Write-Error "❌ === RELEASE FAILED ==="
    Write-Error "Erreur: $($_.Exception.Message)"
    Write-Host "🛠️ Actions manuelles requises" -ForegroundColor Yellow
    exit 1
}
```

### Usage Examples
```powershell
# Test complet sans modifications
.\scripts\automated-release.ps1 -Version "v1.0.0-rc.2" -DryRun

# Release candidate automatique
.\scripts\automated-release.ps1 -Version "v1.0.0-rc.2"

# Release production
.\scripts\automated-release.ps1 -Version "v1.0.0"
```

---

## CI/CD Configuration Files

### GitHub Secrets Required
```yaml
# Repository Secrets (Settings → Secrets and variables → Actions)

# Windows Code Signing
WINDOWS_CERT_BASE64: "MIIKpAIBAzCCCl4G..." # Base64 encoded .pfx
WINDOWS_CERT_PASSWORD: "your_certificate_password"

# macOS Code Signing
MACOS_CERT_BASE64: "MIIKpAIBAzCCCl4G..." # Base64 encoded .p12
MACOS_CERT_PASSWORD: "your_certificate_password"
MACOS_DEVELOPER_ID: "Developer ID Application: Your Company (TEAMID)"
APPLE_ID: "your-apple-id@example.com"
APPLE_TEAM_ID: "YOUR_TEAM_ID"
APPLE_APP_PASSWORD: "app-specific-password"

# Linux GPG Signing
GPG_PRIVATE_KEY: "-----BEGIN PGP PRIVATE KEY BLOCK-----..."
GPG_KEY_ID: "YOUR_GPG_KEY_ID"

# Demo Package
DEMO_PASSWORD: "secure_demo_password_2025"
```

### Repository Variables
```yaml
# Repository Variables (Settings → Secrets and variables → Actions)

COMPANY_NAME: "USB Video Vault"
SUPPORT_EMAIL: "support@usbvideovault.com"
DOCS_URL: "https://docs.usbvideovault.com"
GITHUB_REPO: "YOUR_ORG/usb-video-vault"
```

---

## Manual Backup Commands

### Emergency Manual Release
```bash
#!/bin/bash
# scripts/emergency-release.sh

VERSION="$1"
if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 v1.0.0"
    exit 1
fi

echo "🚨 Emergency Release $VERSION"

# Quick validation
npm run test:typecheck || exit 1
node checklist-go-nogo.mjs || exit 1

# Quick build
npm run build
npm run electron:build

# Create tag
git tag -a "$VERSION" -m "Emergency release $VERSION"
git push origin "$VERSION"

echo "✅ Emergency release tagged and pushed"
echo "🤖 CI/CD pipeline should trigger automatically"
```

### Rollback Commands
```bash
#!/bin/bash
# scripts/rollback-release.sh

VERSION="$1"
if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 v1.0.0"
    exit 1
fi

echo "⚠️ Rolling back release $VERSION"

# Delete remote tag
git push --delete origin "$VERSION"

# Delete local tag
git tag -d "$VERSION"

echo "✅ Release $VERSION rolled back"
echo "🛠️ Manual cleanup of GitHub release may be required"
```

---

**🎯 All CI/CD automation ready for production deployment!**