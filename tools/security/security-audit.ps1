# Script d'audit de sécurité - USB Video Vault
# Usage: .\security-audit.ps1 [-Detailed] [-ExportReport path]

param(
    [switch]$Detailed,
    [string]$ExportReport
)

Write-Host "=== Audit de sécurité - USB Video Vault ===" -ForegroundColor Cyan
Write-Host ""

$auditResults = @{
    criticalIssues = @()
    warnings = @()
    recommendations = @()
    passed = @()
}

# Fonction d'audit
function Add-AuditResult {
    param($Type, $Check, $Status, $Message, $Details = "")
    
    $result = @{
        check = $Check
        status = $Status
        message = $Message
        details = $Details
        timestamp = Get-Date
    }
    
    switch ($Status) {
        "CRITICAL" { 
            $auditResults.criticalIssues += $result
            Write-Host "❌ CRITIQUE: $Check - $Message" -ForegroundColor Red
        }
        "WARNING" { 
            $auditResults.warnings += $result
            Write-Host "⚠️  ATTENTION: $Check - $Message" -ForegroundColor Yellow
        }
        "RECOMMENDATION" { 
            $auditResults.recommendations += $result
            Write-Host "💡 RECOMMANDATION: $Check - $Message" -ForegroundColor Blue
        }
        "PASS" { 
            $auditResults.passed += $result
            Write-Host "✅ OK: $Check" -ForegroundColor Green
        }
    }
    
    if ($Detailed -and $Details) {
        Write-Host "   $Details" -ForegroundColor Gray
    }
}

# 1. Audit des dépendances npm
Write-Host "1. Audit des vulnérabilités npm:" -ForegroundColor Yellow
try {
    $npmAuditOutput = npm audit --json 2>$null | ConvertFrom-Json
    
    if ($npmAuditOutput.vulnerabilities) {
        $criticalVulns = ($npmAuditOutput.vulnerabilities.PSObject.Properties | Where-Object { $_.Value.severity -eq "critical" }).Count
        $highVulns = ($npmAuditOutput.vulnerabilities.PSObject.Properties | Where-Object { $_.Value.severity -eq "high" }).Count
        $moderateVulns = ($npmAuditOutput.vulnerabilities.PSObject.Properties | Where-Object { $_.Value.severity -eq "moderate" }).Count
        
        if ($criticalVulns -gt 0) {
            Add-AuditResult "SECURITY" "npm-vulnerabilities" "CRITICAL" "$criticalVulns vulnérabilités critiques détectées" "Exécutez 'npm audit fix' immédiatement"
        } elseif ($highVulns -gt 0) {
            Add-AuditResult "SECURITY" "npm-vulnerabilities" "WARNING" "$highVulns vulnérabilités élevées détectées" "Planifiez une correction sous 48h"
        } elseif ($moderateVulns -gt 0) {
            Add-AuditResult "SECURITY" "npm-vulnerabilities" "RECOMMENDATION" "$moderateVulns vulnérabilités modérées détectées" "Correction recommandée"
        } else {
            Add-AuditResult "SECURITY" "npm-vulnerabilities" "PASS" "Aucune vulnérabilité npm détectée"
        }
    } else {
        Add-AuditResult "SECURITY" "npm-vulnerabilities" "PASS" "Aucune vulnérabilité npm détectée"
    }
} catch {
    Add-AuditResult "SECURITY" "npm-vulnerabilities" "WARNING" "Impossible d'exécuter npm audit" $_.Exception.Message
}

# 2. Vérification des permissions de fichiers
Write-Host "`n2. Audit des permissions de fichiers:" -ForegroundColor Yellow

$sensitiveFiles = @(
    ".\package.json",
    ".\electron-builder.yml",
    ".\scripts\keygen.cjs",
    ".\vault\*"
)

foreach ($pattern in $sensitiveFiles) {
    $files = Get-ChildItem $pattern -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        try {
            $acl = Get-Acl $file.FullName
            $everyone = $acl.Access | Where-Object { $_.IdentityReference -eq "Everyone" -and $_.FileSystemRights -match "FullControl|Write" }
            
            if ($everyone) {
                Add-AuditResult "SECURITY" "file-permissions" "CRITICAL" "Permissions trop larges sur $($file.Name)" "Everyone a des droits d'écriture"
            } else {
                Add-AuditResult "SECURITY" "file-permissions" "PASS" "Permissions OK pour $($file.Name)"
            }
        } catch {
            Add-AuditResult "SECURITY" "file-permissions" "WARNING" "Impossible de vérifier les permissions de $($file.Name)" $_.Exception.Message
        }
    }
}

# 3. Vérification des secrets dans le code
Write-Host "`n3. Recherche de secrets dans le code:" -ForegroundColor Yellow

# Patterns de recherche de secrets (expressions régulières simplifiées)
$secretChecks = @(
    @{Name="API Keys"; Pattern="api.*key.*=.*[a-zA-Z0-9]{20,}"},
    @{Name="Passwords"; Pattern="password.*=.*[a-zA-Z0-9]{6,}"},
    @{Name="Private Keys"; Pattern="-----BEGIN.*PRIVATE KEY-----"},
    @{Name="AWS Keys"; Pattern="AKIA[0-9A-Z]{16}"},
    @{Name="Generic Secrets"; Pattern="secret.*=.*[a-zA-Z0-9]{10,}"}
)

$codeFiles = Get-ChildItem -Path ".\src" -Recurse -Include "*.ts","*.js" -ErrorAction SilentlyContinue

foreach ($check in $secretChecks) {
    $foundSecrets = @()
    
    foreach ($file in $codeFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -and $content -match $check.Pattern) {
            $foundSecrets += $file.FullName
        }
    }
    
    if ($foundSecrets.Count -gt 0) {
        Add-AuditResult "SECURITY" "secrets-in-code" "CRITICAL" "$($check.Name) détecté(s) dans le code" "Fichiers: $($foundSecrets -join ', ')"
    } else {
        Add-AuditResult "SECURITY" "secrets-in-code" "PASS" "Aucun $($check.Name) détecté"
    }
}

# 4. Vérification de la configuration Electron
Write-Host "`n4. Configuration de sécurité Electron:" -ForegroundColor Yellow

# Vérifier le sandbox
$mainFiles = Get-ChildItem -Path ".\src\main" -Recurse -Include "*.ts" -ErrorAction SilentlyContinue
$sandboxEnabled = $false
$contextIsolationEnabled = $false

foreach ($file in $mainFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        if ($content -match "sandbox\s*:\s*true") {
            $sandboxEnabled = $true
        }
        if ($content -match "contextIsolation\s*:\s*true") {
            $contextIsolationEnabled = $true
        }
    }
}

if ($sandboxEnabled) {
    Add-AuditResult "SECURITY" "electron-sandbox" "PASS" "Sandbox Electron activé"
} else {
    Add-AuditResult "SECURITY" "electron-sandbox" "WARNING" "Sandbox Electron désactivé" "Activez le sandbox pour une meilleure sécurité"
}

if ($contextIsolationEnabled) {
    Add-AuditResult "SECURITY" "electron-context-isolation" "PASS" "Context Isolation activé"
} else {
    Add-AuditResult "SECURITY" "electron-context-isolation" "WARNING" "Context Isolation désactivé" "Activez l'isolation de contexte"
}

# 5. Vérification des URLs externes
Write-Host "`n5. URLs externes et CSP:" -ForegroundColor Yellow

$allFiles = Get-ChildItem -Path ".\src" -Recurse -Include "*.ts","*.js","*.html" -ErrorAction SilentlyContinue
$externalUrls = @()

foreach ($file in $allFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        $urlMatches = [regex]::Matches($content, "https?://[^\s]+")  
        foreach ($match in $urlMatches) {
            if ($match.Value -notmatch "localhost|127\.0\.0\.1|example\.com") {
                $externalUrls += @{
                    url = $match.Value
                    file = $file.FullName
                }
            }
        }
    }
}

if ($externalUrls.Count -gt 0) {
    Add-AuditResult "SECURITY" "external-urls" "RECOMMENDATION" "$($externalUrls.Count) URL(s) externe(s) détectée(s)" "Vérifiez la nécessité et la sécurité de ces URLs"
} else {
    Add-AuditResult "SECURITY" "external-urls" "PASS" "Aucune URL externe détectée"
}

# 6. Vérification du build de production
Write-Host "`n6. Configuration de build sécurisée:" -ForegroundColor Yellow

if (Test-Path ".\dist") {
    # Vérifier que les source maps ne sont pas en production
    $sourceMaps = Get-ChildItem -Path ".\dist" -Recurse -Include "*.map" -ErrorAction SilentlyContinue
    if ($sourceMaps.Count -gt 0) {
        Add-AuditResult "SECURITY" "production-build" "WARNING" "Source maps présentes dans le build de production" "Les source maps peuvent exposer le code source"
    } else {
        Add-AuditResult "SECURITY" "production-build" "PASS" "Aucune source map dans le build de production"
    }
    
    # Vérifier la minification
    $jsFiles = Get-ChildItem -Path ".\dist" -Recurse -Include "*.js" -ErrorAction SilentlyContinue
    $unminifiedFiles = @()
    
    foreach ($jsFile in $jsFiles | Select-Object -First 3) {  # Échantillon
        $content = Get-Content $jsFile.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -and $content.Length -gt 1000 -and ($content -match "\n\s+") -and ($content -match "/\*.*\*/")) {
            $unminifiedFiles += $jsFile.Name
        }
    }
    
    if ($unminifiedFiles.Count -gt 0) {
        Add-AuditResult "SECURITY" "code-minification" "RECOMMENDATION" "Fichiers JS potentiellement non minifiés" "La minification réduit la surface d'attaque"
    } else {
        Add-AuditResult "SECURITY" "code-minification" "PASS" "Code JavaScript minifié"
    }
} else {
    Add-AuditResult "SECURITY" "production-build" "WARNING" "Dossier dist/ introuvable" "Exécutez 'npm run build' pour créer le build de production"
}

# Résumé final
Write-Host "`n=== RÉSUMÉ DE L'AUDIT ===" -ForegroundColor Cyan
Write-Host "Problèmes critiques: $($auditResults.criticalIssues.Count)" -ForegroundColor Red
Write-Host "Avertissements: $($auditResults.warnings.Count)" -ForegroundColor Yellow
Write-Host "Recommandations: $($auditResults.recommendations.Count)" -ForegroundColor Blue
Write-Host "Tests réussis: $($auditResults.passed.Count)" -ForegroundColor Green

# Score de sécurité
$totalChecks = $auditResults.criticalIssues.Count + $auditResults.warnings.Count + $auditResults.recommendations.Count + $auditResults.passed.Count
$securityScore = [math]::Round((($auditResults.passed.Count * 100) / $totalChecks), 1)

Write-Host "`nScore de sécurité: $securityScore%" -ForegroundColor $(if ($securityScore -ge 80) { "Green" } elseif ($securityScore -ge 60) { "Yellow" } else { "Red" })

# Export du rapport si demandé
if ($ExportReport) {
    $report = @{
        auditDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        project = "USB Video Vault"
        securityScore = $securityScore
        summary = @{
            criticalIssues = $auditResults.criticalIssues.Count
            warnings = $auditResults.warnings.Count
            recommendations = $auditResults.recommendations.Count
            passed = $auditResults.passed.Count
        }
        results = $auditResults
    }
    
    $reportJson = $report | ConvertTo-Json -Depth 10
    $reportJson | Out-File -FilePath $ExportReport -Encoding UTF8
    Write-Host "`n📄 Rapport exporté : $ExportReport" -ForegroundColor Cyan
}

# Actions recommandées
if ($auditResults.criticalIssues.Count -gt 0) {
    Write-Host "`n🚨 ACTIONS IMMÉDIATES REQUISES:" -ForegroundColor Red
    foreach ($issue in $auditResults.criticalIssues) {
        Write-Host "• $($issue.message)" -ForegroundColor Red
    }
}

Write-Host "`nPour plus de détails, utilisez -Detailed" -ForegroundColor Gray
Write-Host "Pour exporter un rapport, utilisez -ExportReport chemin/vers/rapport.json" -ForegroundColor Gray