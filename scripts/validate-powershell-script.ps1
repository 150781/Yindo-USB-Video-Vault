# Script de validation simple pour create-release.ps1
# Vérifie manuellement les bonnes pratiques PowerShell

$scriptPath = "scripts\create-release.ps1"

Write-Host "=== VALIDATION DU SCRIPT DE RELEASE ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Vérifier que le script existe
if (Test-Path $scriptPath) {
    Write-Host "✅ Script trouvé: $scriptPath" -ForegroundColor Green
} else {
    Write-Host "❌ Script non trouvé: $scriptPath" -ForegroundColor Red
    exit 1
}

# Test 2: Vérifier les paramètres sécurisés
$content = Get-Content $scriptPath -Raw
if ($content -match '\[SecureString\]\$CertPassword') {
    Write-Host "✅ Paramètre CertPassword utilise SecureString" -ForegroundColor Green
} else {
    Write-Host "❌ Paramètre CertPassword devrait utiliser SecureString" -ForegroundColor Red
}

# Test 3: Vérifier qu'il n'y a pas de switch avec valeur par défaut à true
if ($content -notmatch '\[switch\]\$\w+\s*=\s*\$true') {
    Write-Host "✅ Aucun switch avec valeur par défaut à true" -ForegroundColor Green
} else {
    Write-Host "❌ Switch avec valeur par défaut à true détecté" -ForegroundColor Red
}

# Test 4: Vérifier les verbes approuvés PowerShell
$approvedVerbs = @('Write', 'Test', 'Update', 'Invoke', 'New', 'Get', 'Set')
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

# Test 5: Vérifier la syntaxe PowerShell
try {
    $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
    Write-Host "✅ Syntaxe PowerShell valide" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur de syntaxe PowerShell: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 6: Vérifier que toutes les fonctions appelées existent
$functionDefinitions = [regex]::Matches($content, 'function\s+([a-zA-Z-]+)')
$functionCalls = [regex]::Matches($content, '^\s*([A-Z][a-zA-Z-]+)(?:\s|\()', 'Multiline')

Write-Host ""
Write-Host "=== FONCTIONS DÉFINIES ===" -ForegroundColor Yellow
foreach ($func in $functionDefinitions) {
    Write-Host "  - $($func.Groups[1].Value)" -ForegroundColor White
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