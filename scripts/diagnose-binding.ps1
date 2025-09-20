#!/usr/bin/env pwsh
# Diagnostic Binding - USB Video Vault

Write-Host "DIAGNOSTIC BINDING - USB Video Vault" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Vérifier Node.js disponible
try {
    $nodeVersion = & node --version 2>$null
    Write-Host "Node.js: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "ERREUR: Node.js non trouvé" -ForegroundColor Red
    exit 1
}

# Vérifier scripts disponibles
$scriptsToCheck = @(
    "scripts/print-bindings.mjs",
    "scripts/verify-license.mjs"
)

foreach ($script in $scriptsToCheck) {
    if (Test-Path $script) {
        Write-Host "Script OK: $script" -ForegroundColor Green
    } else {
        Write-Host "Script MANQUANT: $script" -ForegroundColor Red
    }
}

Write-Host "`nEMPREINTE MACHINE ACTUELLE:" -ForegroundColor Yellow
Write-Host "============================" -ForegroundColor Yellow

try {
    & node scripts/print-bindings.mjs
} catch {
    Write-Host "ERREUR: Impossible de récupérer l'empreinte" -ForegroundColor Red
    Write-Host "Vérifier que les scripts sont présents et fonctionnels" -ForegroundColor Yellow
}

Write-Host "`nLICENCE ACTUELLE:" -ForegroundColor Yellow
Write-Host "==================" -ForegroundColor Yellow

# Chercher licence dans différents emplacements possibles
$possiblePaths = @(
    "$env:USERPROFILE\Documents\vault\.vault\license.bin",
    "vault\.vault\license.bin",
    ".vault\license.bin",
    "license.bin"
)

$licenseFound = $false
foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        Write-Host "Licence trouvée: $path" -ForegroundColor Green
        try {
            & node scripts/verify-license.mjs $path
            $licenseFound = $true
            break
        } catch {
            Write-Host "ERREUR: Impossible de vérifier la licence" -ForegroundColor Red
        }
    }
}

if (-not $licenseFound) {
    Write-Host "AUCUNE LICENCE TROUVEE dans les emplacements standard:" -ForegroundColor Red
    foreach ($path in $possiblePaths) {
        Write-Host "  - $path" -ForegroundColor Gray
    }
}

Write-Host "`nSTATE LICENSE:" -ForegroundColor Yellow
Write-Host "===============" -ForegroundColor Yellow

$statePath = "$env:APPDATA\USB Video Vault\.license_state.json"
if (Test-Path $statePath) {
    Write-Host "State trouvé: $statePath" -ForegroundColor Green
    try {
        $stateContent = Get-Content $statePath | ConvertFrom-Json
        Write-Host "MaxSeenTime: $(Get-Date $stateContent.maxSeenTime -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    } catch {
        Write-Host "State illisible ou corrompu" -ForegroundColor Yellow
    }
} else {
    Write-Host "Aucun state trouvé (première exécution?)" -ForegroundColor Yellow
}

Write-Host "`nHORLOGE SYSTÈME:" -ForegroundColor Yellow
Write-Host "=================" -ForegroundColor Yellow

$currentTime = Get-Date
Write-Host "Heure actuelle: $($currentTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
Write-Host "Fuseau horaire: $(Get-TimeZone | Select-Object -ExpandProperty DisplayName)" -ForegroundColor Gray

# Vérifier sync NTP
try {
    $ntpStatus = w32tm /query /status 2>$null | Select-String "Last Successful Sync Time"
    if ($ntpStatus) {
        Write-Host "NTP: $ntpStatus" -ForegroundColor Green
    } else {
        Write-Host "NTP: Statut indisponible" -ForegroundColor Yellow
    }
} catch {
    Write-Host "NTP: Non configuré" -ForegroundColor Yellow
}

Write-Host "`nRESUME DIAGNOSTIC:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

if ($licenseFound) {
    Write-Host "✅ Licence détectée et analysée" -ForegroundColor Green
} else {
    Write-Host "❌ Aucune licence trouvée" -ForegroundColor Red
}

Write-Host "📊 Pour aide supplémentaire:" -ForegroundColor Cyan
Write-Host "  1. Envoyer sortie de ce diagnostic à l'administrateur" -ForegroundColor White
Write-Host "  2. Inclure fichiers logs si disponibles" -ForegroundColor White
Write-Host "  3. Préciser contexte (changement matériel, migration, etc.)" -ForegroundColor White

Write-Host "`nDiagnostic terminé" -ForegroundColor Green