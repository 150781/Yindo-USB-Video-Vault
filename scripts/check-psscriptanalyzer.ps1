# PSScriptAnalyzer Check - Build Scripts
# Version améliorée avec support des bonnes pratiques

param(
    [switch]$Fix,
    [string[]]$Severity = @("Error", "Warning"),
    [string]$Path = "scripts",
    [switch]$Detailed,
    [string[]]$ExcludeRule = @()
)

Write-Host "VERIFICATION PSSCRIPTANALYZER" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# Vérifier PSScriptAnalyzer disponible
try {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Write-Host "✅ PSScriptAnalyzer disponible" -ForegroundColor Green
} catch {
    Write-Host "❌ PSScriptAnalyzer non disponible" -ForegroundColor Red
    Write-Host "Installation: Install-Module -Name PSScriptAnalyzer -Force" -ForegroundColor Yellow
    exit 1
}

# Chercher tous les scripts PowerShell
$scriptFiles = Get-ChildItem -Path $Path -Recurse -Filter "*.ps1" | Where-Object {
    $_.FullName -notmatch "node_modules|\.git|bin|obj"
}

Write-Host "Scripts à analyser: $($scriptFiles.Count)" -ForegroundColor White
Write-Host ""

$totalIssues = 0
$fixedIssues = 0

foreach ($script in $buildScripts) {
    $scriptPath = Join-Path $scriptsPath $script
    
    if (-not (Test-Path $scriptPath)) {
        Write-Host "SKIP $script (non trouve)" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "`nANALYSE: $script" -ForegroundColor White
    Write-Host "----------------------------------------" -ForegroundColor Gray
    
    # Analyse
    $issues = Invoke-ScriptAnalyzer -Path $scriptPath -Severity $Severity
    
    if ($issues) {
        $totalIssues += $issues.Count
        
        foreach ($issue in $issues) {
            $color = switch ($issue.Severity) {
                "Error" { "Red" }
                "Warning" { "Yellow" }
                "Information" { "Cyan" }
                default { "Gray" }
            }
            
            Write-Host "  [$($issue.Severity)] $($issue.RuleName)" -ForegroundColor $color
            Write-Host "    Ligne $($issue.Line): $($issue.Message)" -ForegroundColor Gray
            
            if ($issue.ScriptName) {
                Write-Host "    Context: $($issue.ScriptName)" -ForegroundColor DarkGray
            }
        }
        
        if ($Fix) {
            Write-Host "  Tentative correction automatique..." -ForegroundColor Yellow
            try {
                $fixResult = Invoke-Formatter -ScriptDefinition (Get-Content $scriptPath -Raw)
                if ($fixResult) {
                    Set-Content $scriptPath $fixResult -Encoding UTF8
                    $fixedIssues++
                    Write-Host "  CORRIGE automatiquement" -ForegroundColor Green
                }
            } catch {
                Write-Host "  Correction automatique echouee: $_" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  CLEAN - Aucun probleme detecte" -ForegroundColor Green
    }
}

# Résumé
Write-Host "`nRESUME ANALYSE" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Scripts analyses: $($buildScripts.Count)" -ForegroundColor White
Write-Host "Problemes detectes: $totalIssues" -ForegroundColor $(if($totalIssues -eq 0) {'Green'} else {'Yellow'})

if ($Fix -and $fixedIssues -gt 0) {
    Write-Host "Corrections automatiques: $fixedIssues" -ForegroundColor Green
}

if ($totalIssues -eq 0) {
    Write-Host "`nTOUS LES SCRIPTS SONT CONFORMES PSScriptAnalyzer" -ForegroundColor Green
} else {
    Write-Host "`nRecommandations:" -ForegroundColor Yellow
    Write-Host "  • Corriger les erreurs manuellement" -ForegroundColor White
    Write-Host "  • Utiliser -Fix pour corrections automatiques" -ForegroundColor White
    Write-Host "  • Relancer l'analyse apres corrections" -ForegroundColor White
}

Write-Host "`nAnalyse terminee" -ForegroundColor Green