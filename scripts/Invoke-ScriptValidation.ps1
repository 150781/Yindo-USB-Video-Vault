# Script de validation PowerShell - Analyse de conformité et bonnes pratiques
# Version: 1.0.0

<#
.SYNOPSIS
Valide les scripts PowerShell contre les règles PSScriptAnalyzer et les bonnes pratiques.

.DESCRIPTION
Ce script analyse tous les scripts PowerShell du projet pour détecter :
- Violations des règles PSScriptAnalyzer
- Problèmes de sécurité (mots de passe en texte brut, etc.)
- Non-conformité aux verbes PowerShell approuvés
- Autres problèmes de qualité du code

.PARAMETER ScriptPath
Chemin vers un script spécifique à analyser. Si non spécifié, analyse tous les .ps1 dans le projet.

.PARAMETER Severity
Niveau de sévérité minimum à rapporter (Error, Warning, Information).

.PARAMETER ExcludeRules
Règles PSScriptAnalyzer à exclure de l'analyse.

.EXAMPLE
.\Invoke-ScriptValidation.ps1

.EXAMPLE
.\Invoke-ScriptValidation.ps1 -ScriptPath "create-release.ps1" -Severity Error
#>

[CmdletBinding()]
param(
    [string]$ScriptPath = "",
    [ValidateSet("Error", "Warning", "Information")]
    [string]$Severity = "Warning",
    [string[]]$ExcludeRules = @()
)

# Vérifier que PSScriptAnalyzer est installé
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host "Installation de PSScriptAnalyzer..." -ForegroundColor Yellow
    try {
        Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
        Write-Host "✅ PSScriptAnalyzer installé avec succès" -ForegroundColor Green
    } catch {
        Write-Error "❌ Impossible d'installer PSScriptAnalyzer: $($_.Exception.Message)"
        exit 1
    }
}

Import-Module PSScriptAnalyzer

function Get-ProjectScripts {
    <#
    .SYNOPSIS
    Récupère tous les scripts PowerShell du projet.
    #>
    $scriptsDir = Join-Path $PSScriptRoot ""
    $projectRoot = Split-Path $scriptsDir -Parent
    
    return Get-ChildItem -Path $projectRoot -Filter "*.ps1" -Recurse | Where-Object {
        $_.FullName -notlike "*node_modules*" -and
        $_.FullName -notlike "*dist*" -and
        $_.FullName -notlike "*.git*"
    }
}

function Test-ScriptCompliance {
    <#
    .SYNOPSIS
    Teste la conformité d'un script PowerShell.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    Write-Host "=== Analyse de: $FilePath ===" -ForegroundColor Cyan
    
    # Analyse PSScriptAnalyzer
    $analysisResults = Invoke-ScriptAnalyzer -Path $FilePath -Severity $Severity -ExcludeRule $ExcludeRules
    
    if ($analysisResults.Count -eq 0) {
        Write-Host "✅ Aucun problème détecté" -ForegroundColor Green
        return $true
    }
    
    $hasErrors = $false
    
    foreach ($result in $analysisResults) {
        $color = switch ($result.Severity) {
            "Error" { "Red"; $hasErrors = $true }
            "Warning" { "Yellow" }
            "Information" { "Cyan" }
            default { "White" }
        }
        
        Write-Host "[$($result.Severity)] $($result.RuleName): $($result.Message)" -ForegroundColor $color
        Write-Host "   Ligne $($result.Line), Colonne $($result.Column)" -ForegroundColor Gray
        
        if ($result.SuggestedCorrections) {
            Write-Host "   Correction suggérée: $($result.SuggestedCorrections[0].Description)" -ForegroundColor Magenta
        }
        Write-Host ""
    }
    
    return -not $hasErrors
}

function Show-ValidationSummary {
    <#
    .SYNOPSIS
    Affiche un résumé de la validation.
    #>
    [CmdletBinding()]
    param(
        [int]$TotalScripts,
        [int]$PassedScripts,
        [int]$FailedScripts
    )
    
    Write-Host "=== RÉSUMÉ DE LA VALIDATION ===" -ForegroundColor Magenta
    Write-Host "Scripts analysés: $TotalScripts" -ForegroundColor White
    Write-Host "Scripts conformes: $PassedScripts" -ForegroundColor Green
    Write-Host "Scripts avec erreurs: $FailedScripts" -ForegroundColor Red
    
    $successRate = [math]::Round(($PassedScripts / $TotalScripts) * 100, 1)
    Write-Host "Taux de réussite: $successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } else { "Yellow" })
    
    if ($FailedScripts -eq 0) {
        Write-Host "🎉 Tous les scripts sont conformes aux bonnes pratiques PowerShell!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Des corrections sont nécessaires pour certains scripts." -ForegroundColor Yellow
    }
}

function Show-CommonFixes {
    <#
    .SYNOPSIS
    Affiche les corrections courantes pour les problèmes détectés.
    #>
    Write-Host "=== CORRECTIONS COURANTES ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Mots de passe en texte brut (PSAvoidUsingPlainTextForPassword):" -ForegroundColor Yellow
    Write-Host "   - Remplacer [string] par [SecureString] pour les paramètres de mot de passe"
    Write-Host "   - Utiliser Read-Host -AsSecureString pour saisir des mots de passe"
    Write-Host ""
    Write-Host "2. Verbes non approuvés (PSUseApprovedVerbs):" -ForegroundColor Yellow
    Write-Host "   - Build-* → Invoke-* ou New-*"
    Write-Host "   - Generate-* → New-*"
    Write-Host "   - Calculate-* → Get-* ou Measure-*"
    Write-Host "   - Create-* → New-*"
    Write-Host ""
    Write-Host "3. Paramètres switch avec valeur par défaut (PSAvoidDefaultValueSwitchParameter):" -ForegroundColor Yellow
    Write-Host "   - Supprimer = $true ou = $false des paramètres [switch]"
    Write-Host ""
    Write-Host "4. Variables non utilisées (PSUseDeclaredVarsMoreThanAssignments):" -ForegroundColor Yellow
    Write-Host "   - Supprimer les variables inutilisées"
    Write-Host "   - Préfixer par `$null = si la valeur de retour n'est pas utilisée"
    Write-Host ""
}

# === EXÉCUTION PRINCIPALE ===

try {
    Write-Host "🔍 Validation des scripts PowerShell - USB Video Vault" -ForegroundColor Magenta
    Write-Host "Sévérité minimum: $Severity" -ForegroundColor Gray
    if ($ExcludeRules.Count -gt 0) {
        Write-Host "Règles exclues: $($ExcludeRules -join ', ')" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Déterminer les scripts à analyser
    if ($ScriptPath) {
        if (-not (Test-Path $ScriptPath)) {
            Write-Error "Script non trouvé: $ScriptPath"
            exit 1
        }
        $scriptsToAnalyze = @(Get-Item $ScriptPath)
    } else {
        $scriptsToAnalyze = Get-ProjectScripts
    }
    
    if ($scriptsToAnalyze.Count -eq 0) {
        Write-Warning "Aucun script PowerShell trouvé à analyser."
        exit 0
    }
    
    Write-Host "Scripts à analyser: $($scriptsToAnalyze.Count)" -ForegroundColor Gray
    Write-Host ""
    
    # Analyser chaque script
    $passedScripts = 0
    $failedScripts = 0
    
    foreach ($script in $scriptsToAnalyze) {
        $isCompliant = Test-ScriptCompliance -FilePath $script.FullName
        
        if ($isCompliant) {
            $passedScripts++
        } else {
            $failedScripts++
        }
    }
    
    Write-Host ""
    Show-ValidationSummary -TotalScripts $scriptsToAnalyze.Count -PassedScripts $passedScripts -FailedScripts $failedScripts
    Write-Host ""
    
    if ($failedScripts -gt 0) {
        Show-CommonFixes
        exit 1
    }
    
} catch {
    Write-Error "Erreur durant la validation: $($_.Exception.Message)"
    exit 1
}