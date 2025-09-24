# Script de verification GO/NO-GO pour deploiement public
# Usage: .\check-go-nogo.ps1 -Version "0.1.5" -Detailed

param(
    [string]$Version = "0.1.5",
    [switch]$Detailed,
    [switch]$FixIssues
)

Write-Host "=== GO / NO-GO CHECK v$Version ===" -ForegroundColor Cyan
Write-Host ""

$checks = @()
$issues = @()

# CHECK 1: Certificat Authenticode
Write-Host "1. 🔐 Certificat Authenticode..." -ForegroundColor Yellow

$certCheck = @{
    Name = "Certificat Authenticode"
    Status = "UNKNOWN"
    Details = @()
    Critical = $true
}

# Verifier signature existante si setup disponible
$setupFile = ".\dist\USB Video Vault Setup $Version.exe"
if (Test-Path $setupFile) {
    try {
        $signtoolPath = Get-Command signtool -ErrorAction SilentlyContinue
        if ($signtoolPath) {
            $signtoolOutput = & signtool verify /pa /v $setupFile 2>&1
            $signatureValid = $LASTEXITCODE -eq 0
            
            if ($signatureValid) {
                $certCheck.Status = "OK"
                $certCheck.Details += "Signature Authenticode valide sur $setupFile"
                if ($signtoolOutput -match "timestamp") {
                    $certCheck.Details += "Horodatage present"
                } else {
                    $certCheck.Details += "ATTENTION: Horodatage manquant"
                }
            } else {
                $certCheck.Status = "FAILED"
                $certCheck.Details += "Signature invalide ou manquante sur $setupFile"
            }
        } else {
            $certCheck.Status = "MANUAL_CHECK"
            $certCheck.Details += "signtool non disponible - verification manuelle requise"
            $certCheck.Details += "Verifier manuellement GitHub Secrets:"
            $certCheck.Details += "  - WINDOWS_CERT_BASE64 (certificat .pfx en base64)"  
            $certCheck.Details += "  - WINDOWS_CERT_PASSWORD (mot de passe certificat)"
        }
    } catch {
        $certCheck.Status = "ERROR"
        $certCheck.Details += "Erreur verification signature: $($_.Exception.Message)"
    }
} else {
    $certCheck.Status = "MANUAL_CHECK"
    $certCheck.Details += "Setup file manquant - build requis"
    $certCheck.Details += "Verifier GitHub Secrets avant build final:"
    $certCheck.Details += "  - WINDOWS_CERT_BASE64 (certificat .pfx en base64)"  
    $certCheck.Details += "  - WINDOWS_CERT_PASSWORD (mot de passe certificat)"
    $certCheck.Details += "  - GITHUB_TOKEN (pour releases)"
}

$checks += $certCheck

# CHECK 2: Build local
Write-Host "2. 🔨 Build local..." -ForegroundColor Yellow

$buildCheck = @{
    Name = "Build local"
    Status = "UNKNOWN"  
    Details = @()
    Critical = $true
}

# Verifier artefacts build
$buildFiles = @(
    ".\dist\USB Video Vault Setup $Version.exe",
    ".\dist\USB Video Vault $Version.exe"
)

$missingFiles = @()
foreach ($file in $buildFiles) {
    if (-not (Test-Path $file)) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -eq 0) {
    $buildCheck.Status = "OK"
    $buildCheck.Details += "Tous les artefacts build présents"
    
    # Verifier tailles
    foreach ($file in $buildFiles) {
        $size = [math]::Round((Get-Item $file).Length / 1MB, 1)
        $buildCheck.Details += "  $(Split-Path $file -Leaf): ${size}MB"
    }
} else {
    $buildCheck.Status = "FAILED"
    $buildCheck.Details += "Artefacts manquants:"
    $missingFiles | ForEach-Object { $buildCheck.Details += "  - $_" }
    $issues += "Executer: npm run clean et npm run build et npm run electron:build"
}

$checks += $buildCheck

# CHECK 3: Tests smoke
Write-Host "3. 🧪 Tests smoke..." -ForegroundColor Yellow

$smokeCheck = @{
    Name = "Tests smoke"
    Status = "UNKNOWN"
    Details = @()
    Critical = $true
}

if (Test-Path ".\tools\final-vm-tests.ps1") {
    $smokeCheck.Status = "SCRIPT_READY"
    $smokeCheck.Details += "Script VM tests disponible"
    $smokeCheck.Details += "Executer: .\tools\final-vm-tests.ps1 -SetupPath '.\dist\USB Video Vault Setup $Version.exe' -Automated"
} else {
    $smokeCheck.Status = "SCRIPT_MISSING" 
    $smokeCheck.Details += "Script final-vm-tests.ps1 manquant"
}

$checks += $smokeCheck

# CHECK 4: Manifests distribution
Write-Host "4. 📦 Manifests distribution..." -ForegroundColor Yellow

$manifestCheck = @{
    Name = "Manifests distribution"
    Status = "UNKNOWN"
    Details = @()
    Critical = $true
}

# Winget
$wingetManifest = ".\packaging\winget\Yindo.USBVideoVault.yaml"
if (Test-Path $wingetManifest) {
    $manifestCheck.Details += "✅ Winget manifest présent"
    
    # Verifier contenu
    $wingetContent = Get-Content $wingetManifest -Raw
    if ($wingetContent -match "PackageVersion:\s*$([regex]::Escape($Version))") {
        $manifestCheck.Details += "✅ Version Winget correcte: $Version"
    } else {
        $manifestCheck.Details += "⚠️ Version Winget à mettre à jour"
        $issues += "Mettre à jour PackageVersion dans $wingetManifest"
    }
    
    # Verifier URL/SHA256 placeholder
    if ($wingetContent -match "InstallerUrl:.*github.*releases.*download") {
        $manifestCheck.Details += "✅ URL Winget correcte (direct download)"
    } else {
        $manifestCheck.Details += "❌ URL Winget incorrecte"
        $issues += "Corriger InstallerUrl dans manifests Winget"
    }
} else {
    $manifestCheck.Details += "❌ Winget manifest manquant"
    $issues += "Créer manifests Winget dans $wingetManifest"
}

# Chocolatey
$chocoSpec = ".\packaging\chocolatey\usbvideovault.nuspec"
if (Test-Path $chocoSpec) {
    $manifestCheck.Details += "✅ Chocolatey nuspec présent"
    
    $chocoContent = Get-Content $chocoSpec -Raw
    if ($chocoContent -match "<version>$([regex]::Escape($Version))</version>") {
        $manifestCheck.Details += "✅ Version Chocolatey correcte: $Version"
    } else {
        $manifestCheck.Details += "⚠️ Version Chocolatey à mettre à jour"
        $issues += "Mettre a jour version dans $chocoSpec"
    }
} else {
    $manifestCheck.Details += "❌ Chocolatey nuspec manquant"
    $issues += "Créer Chocolatey nuspec dans $chocoSpec"
}

# Status global manifests
if ($manifestCheck.Details -notcontains "❌") {
    $manifestCheck.Status = "OK"
} else {
    $manifestCheck.Status = "ISSUES"
}

$checks += $manifestCheck

# CHECK 5: Documentation
Write-Host "5. 📚 Documentation..." -ForegroundColor Yellow

$docCheck = @{
    Name = "Documentation"
    Status = "UNKNOWN"
    Details = @()
    Critical = $false
}

$docFiles = @(
    @{Path=".\README.md"; Name="README principal"},
    @{Path=".\CHANGELOG.md"; Name="Changelog"},
    @{Path=".\tools\support\USER_SUPPORT_GUIDE.md"; Name="Guide support utilisateur"}
)

$docMissing = @()
foreach ($doc in $docFiles) {
    if (Test-Path $doc.Path) {
        $docCheck.Details += "✅ $($doc.Name)"
    } else {
        $docCheck.Details += "⚠️ $($doc.Name) manquant"
        $docMissing += $doc.Path
    }
}

if ($docMissing.Count -eq 0) {
    $docCheck.Status = "OK"
} else {
    $docCheck.Status = "INCOMPLETE"
    $issues += "Créer documentation manquante: $($docMissing -join ', ')"
}

$checks += $docCheck

# RAPPORT FINAL
Write-Host "`n=== RÉSULTATS GO/NO-GO ===" -ForegroundColor Cyan

$criticalFailed = 0
$warnings = 0

foreach ($check in $checks) {
    $icon = "?"
    $color = "Gray"
    
    switch ($check.Status) {
        "OK" { $icon = "[OK]"; $color = "Green" }
        "MANUAL_CHECK" { $icon = "[MANUAL]"; $color = "Yellow" }
        "SCRIPT_READY" { $icon = "[READY]"; $color = "Yellow" }
        "ISSUES" { $icon = "[ISSUES]"; $color = "Red" }
        "FAILED" { $icon = "[FAILED]"; $color = "Red" }
        "INCOMPLETE" { $icon = "[INCOMPLETE]"; $color = "Yellow" }
    }
    
    Write-Host "$icon $($check.Name): $($check.Status)" -ForegroundColor $color
    
    if ($Detailed) {
        foreach ($detail in $check.Details) {
            Write-Host "    $detail" -ForegroundColor Gray
        }
    }
    
    if ($check.Critical -and ($check.Status -eq "FAILED" -or $check.Status -eq "ISSUES")) {
        $criticalFailed++
    } elseif ($check.Status -like "*MANUAL*" -or $check.Status -like "*WARNING*" -or $check.Status -eq "INCOMPLETE") {
        $warnings++
    }
}

# DÉCISION GO/NO-GO
Write-Host "`n=== DÉCISION ===" -ForegroundColor Cyan

if ($criticalFailed -eq 0) {
    Write-Host "🚀 GO - Déploiement autorisé" -ForegroundColor Green
    Write-Host "Critiques: $criticalFailed | Warnings: $warnings" -ForegroundColor Green
    
    if ($warnings -gt 0) {
        Write-Host "⚠️ Actions manuelles requises avant déploiement:" -ForegroundColor Yellow
        Write-Host "  1. Vérifier certificat Authenticode dans GitHub Secrets" -ForegroundColor White
        Write-Host "  2. Exécuter tests smoke sur VM propre" -ForegroundColor White
        Write-Host "  3. Mettre à jour SHA256 réels après build signé" -ForegroundColor White
    }
} else {
    Write-Host "❌ NO-GO - Problèmes critiques à résoudre" -ForegroundColor Red
    Write-Host "Critiques: $criticalFailed | Warnings: $warnings" -ForegroundColor Red
}

# ACTIONS CORRECTIVES
if ($issues.Count -gt 0) {
    Write-Host "`n=== ACTIONS CORRECTIVES ===" -ForegroundColor Blue
    for ($i = 0; $i -lt $issues.Count; $i++) {
        Write-Host "$($i+1). $($issues[$i])" -ForegroundColor White
    }
    
    if ($FixIssues) {
        Write-Host ""
        Write-Host "Tentative correction automatique..." -ForegroundColor Yellow
        
        # Correction build si necessaire
        if ($issues -contains "Executer: npm run clean et npm run build et npm run electron:build") {
            Write-Host "  Lancement build..." -ForegroundColor Blue
            & npm run clean
            & npm run build  
            & npm run electron:build
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Build corrige" -ForegroundColor Green
            } else {
                Write-Host "  Build toujours en echec" -ForegroundColor Red
            }
        }
    }
}

# CHECKLIST FINALE
Write-Host ""
Write-Host "=== CHECKLIST DEPLOIEMENT ===" -ForegroundColor Blue
Write-Host "Avant de proceder au deploiement:" -ForegroundColor White
Write-Host "  [ ] Certificat EV/OV configure dans GitHub Secrets" -ForegroundColor White
Write-Host "  [ ] Build local reussi sans erreurs" -ForegroundColor White  
Write-Host "  [ ] Tests smoke VM reussis" -ForegroundColor White
Write-Host "  [ ] Manifests Winget/Chocolatey a jour" -ForegroundColor White
Write-Host "  [ ] Documentation utilisateur complete" -ForegroundColor White
Write-Host "  [ ] Plan rollback documente" -ForegroundColor White
Write-Host ""
Write-Host "Commande deploiement:" -ForegroundColor Yellow
Write-Host "  .\tools\deploy-first-public.ps1 -Version '$Version' -Execute" -ForegroundColor Cyan

$decision = if ($criticalFailed -eq 0) { "GO" } else { "NO-GO" }
$decisionColor = if ($decision -eq "GO") { "Green" } else { "Red" }
Write-Host ""
Write-Host "DECISION FINALE: $decision" -ForegroundColor $decisionColor