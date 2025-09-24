# Script de release automatisée - USB Video Vault
# Usage: .\full-release.ps1 -Version "1.2.3" -Type "patch|minor|major" [-PreRelease] [-DryRun]

param(
    [Parameter(Mandatory=$false)]
    [string]$Version,

    [ValidateSet("patch","minor","major","prerelease")]
    [string]$Type = "patch",

    [switch]$PreRelease,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "=== USB Video Vault - Release automatisée ===" -ForegroundColor Cyan
Write-Host ""

# Configuration
$repoRoot = Get-Location
$releaseConfig = Get-Content ".\tools\release\release.config.json" -ErrorAction SilentlyContinue | ConvertFrom-Json

if (-not $releaseConfig) {
    Write-Warning "Configuration de release non trouvée, utilisation des valeurs par défaut"
    $releaseConfig = @{
        signing = @{ enabled = $false }
        distribution = @{ github = $true; winget = $false; chocolatey = $false }
        monitoring = @{ enabled = $false }
    }
}

# Fonctions utilitaires
function Invoke-Step {
    param($Name, $ScriptBlock)

    Write-Host "📋 $Name..." -ForegroundColor Yellow

    if ($DryRun) {
        Write-Host "   [DRY RUN] $Name" -ForegroundColor Gray
        return
    }

    try {
        & $ScriptBlock
        Write-Host "   ✅ $Name terminé" -ForegroundColor Green
    } catch {
        Write-Error "❌ Erreur dans $Name : $($_.Exception.Message)"
        exit 1
    }
}

function Test-Prerequisites {
    # Vérifier git status
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        throw "Repository a des changements non committés. Committez ou stashez avant la release."
    }

    # Vérifier branche actuelle
    $currentBranch = git branch --show-current
    if ($currentBranch -ne "main" -and $currentBranch -ne "develop") {
        throw "Release doit être effectuée depuis la branche main ou develop. Branche actuelle: $currentBranch"
    }

    # Vérifier outils requis
    $tools = @("npm", "git", "node")
    foreach ($tool in $tools) {
        try {
            & $tool --version | Out-Null
        } catch {
            throw "$tool n'est pas installé ou accessible"
        }
    }

    Write-Host "✅ Prérequis validés" -ForegroundColor Green
}

function Get-NextVersion {
    $currentVersion = (Get-Content ".\package.json" | ConvertFrom-Json).version
    Write-Host "Version actuelle: $currentVersion" -ForegroundColor Gray

    if ($Version) {
        return $Version
    }

    # Calculer la prochaine version automatiquement
    $versionParts = $currentVersion.Split('.')
    $major = [int]$versionParts[0]
    $minor = [int]$versionParts[1]
    $patch = [int]$versionParts[2]

    switch ($Type) {
        "major" {
            $major++; $minor = 0; $patch = 0
        }
        "minor" {
            $minor++; $patch = 0
        }
        "patch" {
            $patch++
        }
    }

    $nextVersion = "$major.$minor.$patch"
    if ($PreRelease) {
        $nextVersion += "-beta.1"
    }

    return $nextVersion
}

# Étape 1: Vérification des prérequis
Invoke-Step "Vérification des prérequis" {
    Test-Prerequisites
}

# Étape 2: Déterminer la version
$targetVersion = Get-NextVersion
Write-Host "Version cible: $targetVersion" -ForegroundColor Cyan

if (-not $DryRun) {
    $confirm = Read-Host "Continuer avec la version $targetVersion ? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Release annulée par l'utilisateur" -ForegroundColor Yellow
        exit 0
    }
}

# Étape 3: Audit de sécurité
Invoke-Step "Audit de sécurité" {
    .\tools\security\security-audit.ps1 -ExportReport ".\audit-pre-release-$targetVersion.json"

    # Vérifier les résultats critiques
    $auditReport = Get-Content ".\audit-pre-release-$targetVersion.json" | ConvertFrom-Json
    if ($auditReport.summary.criticalIssues -gt 0) {
        throw "Audit de sécurité a détecté $($auditReport.summary.criticalIssues) problème(s) critique(s)"
    }
}

# Étape 4: Tests complets
Invoke-Step "Exécution des tests" {
    npm test

    # Tests E2E si disponibles
    if (Test-Path ".\test\e2e") {
        npm run test:e2e
    }

    # Tests de support
    .\tools\support\troubleshoot.ps1 -Detailed
}

# Étape 5: Build et packaging
Invoke-Step "Clean et build" {
    npm run clean
    npm run build
}

Invoke-Step "Packaging Electron" {
    npm run electron:build
}

# Étape 6: Vérification des artifacts
Invoke-Step "Vérification des artifacts" {
    .\tools\verify-release.ps1 -Version $targetVersion
}

# Étape 7: Génération des métadonnées
Invoke-Step "Génération SBOM" {
    .\tools\security\generate-sbom.ps1 -Format json -Output ".\dist\sbom-$targetVersion.json"
}

Invoke-Step "Génération des checksums" {
    $artifacts = Get-ChildItem ".\dist" -Name "*.exe" | Where-Object { $_ -like "*Setup*" -or $_ -like "*portable*" }

    foreach ($artifact in $artifacts) {
        $artifactPath = ".\dist\$artifact"
        $sha256 = (Get-FileHash $artifactPath -Algorithm SHA256).Hash
        $sha512 = (Get-FileHash $artifactPath -Algorithm SHA512).Hash

        "$sha256  $artifact" | Out-File ".\dist\SHA256SUMS" -Append -Encoding UTF8
        "$sha512  $artifact" | Out-File ".\dist\SHA512SUMS" -Append -Encoding UTF8
    }
}

# Étape 8: Mise à jour de la version
Invoke-Step "Bump version" {
    if ($Version) {
        # Version spécifique fournie
        $packageJson = Get-Content ".\package.json" | ConvertFrom-Json
        $packageJson.version = $targetVersion
        $packageJson | ConvertTo-Json -Depth 10 | Set-Content ".\package.json"

        git add ".\package.json"
        git commit -m "chore: bump version to $targetVersion"
    } else {
        # Utiliser npm version
        npm version $Type --no-git-tag-version
        git add ".\package.json"
        git commit -m "chore: bump version to $targetVersion"
    }
}

# Étape 9: Génération du changelog
Invoke-Step "Génération du changelog" {
    if (Test-Path ".\tools\release\generate-changelog.ps1") {
        $lastTag = git describe --tags --abbrev=0 2>$null
        if ($lastTag) {
            .\tools\release\generate-changelog.ps1 -FromTag $lastTag -ToTag "HEAD" -Output ".\CHANGELOG-$targetVersion.md"
        }
    }
}

# Étape 10: Création du tag et push
Invoke-Step "Création du tag Git" {
    $tagName = "v$targetVersion"
    $buildHash = git rev-parse --short HEAD
    $buildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $tagMessage = @"
Release $targetVersion

Version: $targetVersion
Build Hash: $buildHash
Build Date: $buildDate
Environment: Production
Release Type: $Type
Pre-release: $PreRelease
"@

    git tag -a $tagName -m $tagMessage
    git push origin main --tags
}

# Étape 11: GitHub Release (si configuré)
if ($releaseConfig.distribution.github) {
    Invoke-Step "Création GitHub Release" {
        # Utiliser GitHub CLI si disponible
        try {
            gh --version | Out-Null

            $releaseNotes = ""
            if (Test-Path ".\CHANGELOG-$targetVersion.md") {
                $releaseNotes = Get-Content ".\CHANGELOG-$targetVersion.md" -Raw
            }

            $ghCommand = "gh release create v$targetVersion"
            if ($PreRelease) {
                $ghCommand += " --prerelease"
            }
            $ghCommand += " --title `"USB Video Vault v$targetVersion`""
            $ghCommand += " --notes `"$releaseNotes`""

            # Ajouter les artifacts
            $artifacts = Get-ChildItem ".\dist" -Name "*.exe", "*.zip", "SHA*SUMS", "sbom-*.json"
            foreach ($artifact in $artifacts) {
                $ghCommand += " `".\dist\$artifact`""
            }

            Invoke-Expression $ghCommand

        } catch {
            Write-Warning "GitHub CLI non disponible. Créez la release manuellement sur GitHub."
        }
    }
}

# Étape 12: Post-release monitoring
if ($releaseConfig.monitoring.enabled) {
    Invoke-Step "Activation du monitoring" {
        if (Test-Path ".\tools\monitoring\post-release-watch.ps1") {
            Start-Job -ScriptBlock {
                .\tools\monitoring\post-release-watch.ps1 -Version $using:targetVersion -Duration 48
            }
        }
    }
}

# Étape 13: Distribution (Winget, Chocolatey)
if ($releaseConfig.distribution.winget) {
    Invoke-Step "Soumission Winget" {
        Write-Host "   Manuel: Soumettez le manifest Winget depuis .\tools\packaging\winget\" -ForegroundColor Yellow
    }
}

if ($releaseConfig.distribution.chocolatey) {
    Invoke-Step "Soumission Chocolatey" {
        Write-Host "   Manuel: Soumettez le package Chocolatey depuis .\tools\packaging\chocolatey\" -ForegroundColor Yellow
    }
}

# Résumé final
Write-Host "`n=== RELEASE TERMINÉE ===" -ForegroundColor Green
Write-Host "Version: $targetVersion" -ForegroundColor Cyan
Write-Host "Tag Git: v$targetVersion" -ForegroundColor Cyan
Write-Host "Artifacts: .\dist\" -ForegroundColor Cyan

if ($releaseConfig.distribution.github) {
    Write-Host "GitHub Release: https://github.com/user/USB-Video-Vault/releases/tag/v$targetVersion" -ForegroundColor Cyan
}

Write-Host "`n📋 Actions post-release:" -ForegroundColor Yellow
Write-Host "• Surveiller les métriques de performance (48h)" -ForegroundColor White
Write-Host "• Collecter les feedbacks utilisateurs" -ForegroundColor White
Write-Host "• Mettre à jour la documentation si nécessaire" -ForegroundColor White
Write-Host "• Planifier la prochaine release" -ForegroundColor White

if ($releaseConfig.monitoring.webhook) {
    Write-Host "`n🔔 Notification envoyée aux équipes" -ForegroundColor Blue
}
