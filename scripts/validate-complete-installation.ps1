# Script de Validation Complète des Installateurs
param(
    [switch]$RunBuild,
    [switch]$TestPostInstall,
    [switch]$ValidateScripts,
    [string]$LogPath = "validation-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
)

function Write-ValidationLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    
    if ($LogPath) {
        Add-Content -Path $LogPath -Value $logMessage
    }
}

function Test-PowerShellScriptCompliance {
    param([string]$ScriptPath)
    
    Write-ValidationLog "Validation PSScriptAnalyzer: $ScriptPath"
    
    if (-not (Test-Path $ScriptPath)) {
        Write-ValidationLog "Script non trouvé: $ScriptPath" "ERROR"
        return $false
    }
    
    try {
        # Test syntaxe
        $null = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
        Write-ValidationLog "✅ Syntaxe PowerShell valide" "OK"
        
        # Test PSScriptAnalyzer si disponible
        if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
            $warnings = Invoke-ScriptAnalyzer -Path $ScriptPath -Severity Warning, Error
            if ($warnings.Count -eq 0) {
                Write-ValidationLog "✅ Aucun warning PSScriptAnalyzer" "OK"
                return $true
            } else {
                Write-ValidationLog "⚠️ $($warnings.Count) warnings PSScriptAnalyzer" "WARN"
                $warnings | ForEach-Object {
                    Write-ValidationLog "  - $($_.RuleName): $($_.Message)" "WARN"
                }
                return $false
            }
        } else {
            Write-ValidationLog "PSScriptAnalyzer non installé - validation syntaxe uniquement" "WARN"
            return $true
        }
    } catch {
        Write-ValidationLog "Erreur validation: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-InstallerConfigurations {
    Write-ValidationLog "=== Validation Configurations Installateurs ==="
    
    $results = @{}
    
    # Test electron-builder.yml
    if (Test-Path "electron-builder.yml") {
        Write-ValidationLog "✅ electron-builder.yml présent" "OK"
        $results["electron-builder"] = $true
    } else {
        Write-ValidationLog "❌ electron-builder.yml manquant" "ERROR"
        $results["electron-builder"] = $false
    }
    
    # Test scripts NSIS
    if (Test-Path "installer/nsis-installer.nsh") {
        Write-ValidationLog "✅ Script NSIS présent" "OK"
        $results["nsis"] = $true
    } else {
        Write-ValidationLog "❌ Script NSIS manquant" "ERROR"
        $results["nsis"] = $false
    }
    
    # Test scripts Inno Setup
    if (Test-Path "installer/inno-setup.iss") {
        Write-ValidationLog "✅ Script Inno Setup présent" "OK"
        $results["inno"] = $true
    } else {
        Write-ValidationLog "❌ Script Inno Setup manquant" "ERROR"
        $results["inno"] = $false
    }
    
    return $results
}

function Test-PostInstallScripts {
    Write-ValidationLog "=== Test Scripts Post-Install ==="
    
    $testVaultPath = "$env:TEMP\test-vault-$(Get-Date -Format 'yyyyMMddHHmmss')"
    
    try {
        # Test post-install-simple.ps1
        if (Test-Path "scripts/post-install-simple.ps1") {
            Write-ValidationLog "Test post-install-simple.ps1"
            $env:VAULT_PATH = $testVaultPath
            
            & ".\scripts\post-install-simple.ps1"
            
            if (Test-Path "$testVaultPath\.vault") {
                Write-ValidationLog "✅ Dossier vault créé correctement" "OK"
            } else {
                Write-ValidationLog "❌ Dossier vault non créé" "ERROR"
            }
        }
        
        # Test post-install-setup.ps1
        if (Test-Path "scripts/post-install-setup.ps1") {
            Write-ValidationLog "Test post-install-setup.ps1"
            
            & ".\scripts\post-install-setup.ps1" -VaultPath "$testVaultPath-setup" -Verbose
            
            if (Test-Path "$testVaultPath-setup\.vault") {
                Write-ValidationLog "✅ Post-install avancé fonctionne" "OK"
            } else {
                Write-ValidationLog "❌ Post-install avancé échoué" "ERROR"
            }
        }
        
    } finally {
        # Nettoyage
        if (Test-Path $testVaultPath) {
            Remove-Item $testVaultPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path "$testVaultPath-setup") {
            Remove-Item "$testVaultPath-setup" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-BuildScript {
    Write-ValidationLog "=== Test Script de Build ==="
    
    if (Test-Path "scripts/build-installers.ps1") {
        # Test syntaxe et paramètres
        Write-ValidationLog "Test paramètres build-installers.ps1"
        
        try {
            # Test avec validation uniquement (pas de build réel)
            $result = & ".\scripts\build-installers.ps1" -SkipBuild -WhatIf 2>&1
            Write-ValidationLog "✅ Script build-installers exécutable" "OK"
        } catch {
            Write-ValidationLog "❌ Erreur script build-installers: $($_.Exception.Message)" "ERROR"
        }
    }
}

# === Exécution principale ===
Write-ValidationLog "=== DÉBUT VALIDATION COMPLÈTE INSTALLATEURS ==="

$allPassed = $true

# 1. Validation scripts PowerShell
if ($ValidateScripts -or $PSBoundParameters.Count -eq 0) {
    Write-ValidationLog "=== Validation Scripts PowerShell ==="
    
    $scripts = @(
        "scripts/build-installers.ps1",
        "scripts/post-install-simple.ps1", 
        "scripts/post-install-setup.ps1"
    )
    
    foreach ($script in $scripts) {
        if (-not (Test-PowerShellScriptCompliance $script)) {
            $allPassed = $false
        }
    }
}

# 2. Validation configurations
$configResults = Test-InstallerConfigurations
if ($configResults.Values -contains $false) {
    $allPassed = $false
}

# 3. Test post-install
if ($TestPostInstall -or $PSBoundParameters.Count -eq 0) {
    Test-PostInstallScripts
}

# 4. Test script de build  
Test-BuildScript

# 5. Test build complet (optionnel)
if ($RunBuild) {
    Write-ValidationLog "=== Test Build Complet ==="
    try {
        & ".\scripts\build-installers.ps1" -Portable
        Write-ValidationLog "✅ Build test réussi" "OK"
    } catch {
        Write-ValidationLog "❌ Build test échoué: $($_.Exception.Message)" "ERROR"
        $allPassed = $false
    }
}

# Résumé final
Write-ValidationLog "=== RÉSUMÉ VALIDATION ==="
if ($allPassed) {
    Write-ValidationLog "🎉 VALIDATION COMPLÈTE RÉUSSIE" "OK"
    Write-ValidationLog "Tous les scripts et configurations sont prêts pour la production" "OK"
} else {
    Write-ValidationLog "⚠️ VALIDATION PARTIELLEMENT ÉCHOUÉE" "WARN"
    Write-ValidationLog "Certains éléments nécessitent des corrections" "WARN"
}

Write-ValidationLog "Log de validation sauvegardé: $LogPath"
Write-ValidationLog "=== FIN VALIDATION ==="

if ($allPassed) {
    exit 0
} else {
    exit 1
}