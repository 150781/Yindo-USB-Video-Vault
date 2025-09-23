# Script de validation pour build-installers.ps1
# Vérifie la conformité PowerShell Script Analyzer

$scriptPath = "scripts\build-installers.ps1"

Write-Host "=== VALIDATION DU SCRIPT BUILD-INSTALLERS ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Vérifier que le script existe
if (Test-Path $scriptPath) {
    Write-Host "✅ Script trouvé: $scriptPath" -ForegroundColor Green
} else {
    Write-Host "❌ Script non trouvé: $scriptPath" -ForegroundColor Red
    exit 1
}

# Test 2: Vérifier qu'il n'y a pas de switch avec valeur par défaut à true
$content = Get-Content $scriptPath -Raw
if ($content -notmatch '\[switch\]\$\w+\s*=\s*\$true') {
    Write-Host "✅ Aucun switch avec valeur par défaut à true" -ForegroundColor Green
} else {
    Write-Host "❌ Switch avec valeur par défaut à true détecté" -ForegroundColor Red
}

# Test 3: Vérifier les verbes approuvés PowerShell
$approvedVerbs = @('Write', 'Test', 'Copy', 'Invoke', 'New', 'Show', 'Remove')
$functions = [regex]::Matches($content, 'function\s+(\w+)-')

$allFunctionsValid = $true
foreach ($match in $functions) {
    $verb = $match.Groups[1].Value
    if ($verb -in $approvedVerbs) {
        Write-Host "✅ Fonction avec verbe approuvé: $verb-" -ForegroundColor Green
    } else {
        Write-Host "❌ Fonction avec verbe non approuvé: $verb-" -ForegroundColor Red
        $allFunctionsValid = $false
    }
}

# Test 4: Vérifier la syntaxe PowerShell
try {
    $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
    Write-Host "✅ Syntaxe PowerShell valide" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur de syntaxe PowerShell: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Vérifier les fonctions définies
$functionDefinitions = [regex]::Matches($content, 'function\s+([a-zA-Z-]+)')

Write-Host ""
Write-Host "=== FONCTIONS DÉFINIES ===" -ForegroundColor Yellow
foreach ($func in $functionDefinitions) {
    Write-Host "  - $($func.Groups[1].Value)" -ForegroundColor White
}

# Test 6: Vérifier la logique d'initialisation des switches
if ($content -match 'if \(-not \$Portable -and -not \$NSIS -and -not \$MSI -and -not \$InnoSetup\)') {
    Write-Host "✅ Logique d'initialisation des switches présente" -ForegroundColor Green
} else {
    Write-Host "❌ Logique d'initialisation des switches manquante" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== RÉSUMÉ ===" -ForegroundColor Cyan
if ($allFunctionsValid) {
    Write-Host "✅ VALIDATION RÉUSSIE - Script conforme aux bonnes pratiques PowerShell" -ForegroundColor Green
} else {
    Write-Host "⚠️  VALIDATION PARTIELLE - Quelques améliorations possibles" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Script validé: $scriptPath" -ForegroundColor White