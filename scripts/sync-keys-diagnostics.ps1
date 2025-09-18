# scripts/sync-keys-diagnostics.ps1
# Script de diagnostic complet pour les problèmes de signature de licence

Write-Host "=== DIAGNOSTIC LIC-SIG - Synchronisation des clés publiques ===" -ForegroundColor Yellow
Write-Host ""

$ErrorActionPreference = "Stop"
$workDir = "c:\Users\patok\Documents\Yindo-USB-Video-Vault"
Set-Location $workDir

Write-Host "1. Vérification des empreintes des clés..." -ForegroundColor Cyan
try {
    $fingerprintResult = node scripts/keys/fingerprint.cjs 2>&1
    Write-Host $fingerprintResult
    
    if ($fingerprintResult -like "*✖ MISMATCH*") {
        Write-Host ""
        Write-Host "❌ MISMATCH détecté - Synchronisation nécessaire" -ForegroundColor Red
        
        Write-Host ""
        Write-Host "2. Synchronisation de la clé publique packager → app..." -ForegroundColor Cyan
        $syncResult = node scripts/keys/sync-public-key-to-app.cjs 2>&1
        Write-Host $syncResult
        
        Write-Host ""
        Write-Host "3. Rebuild du main..." -ForegroundColor Cyan
        npm run build:main
        
        Write-Host ""
        Write-Host "4. Vérification après synchronisation..." -ForegroundColor Cyan
        $fingerprintResult2 = node scripts/keys/fingerprint.cjs 2>&1
        Write-Host $fingerprintResult2
        
        if ($fingerprintResult2 -like "*✔ MATCH*") {
            Write-Host "✅ Synchronisation réussie!" -ForegroundColor Green
        } else {
            Write-Host "❌ Problème de synchronisation" -ForegroundColor Red
        }
    } else {
        Write-Host "✅ Clés déjà synchronisées" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Erreur lors du diagnostic des empreintes: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "5. Vérification de la licence vault actuel..." -ForegroundColor Cyan
$vaultPath = $env:VAULT_PATH
if (-not $vaultPath) {
    $vaultPath = "usb-package\vault"
    Write-Host "Utilisation du vault par défaut: $vaultPath"
}

try {
    $licenseResult = node tools/packager/verify-license.cjs $vaultPath 2>&1
    Write-Host $licenseResult
    
    if ($licenseResult -like "*✖ Signature INVALIDE*") {
        Write-Host ""
        Write-Host "6. Régénération de la licence..." -ForegroundColor Cyan
        
        # Obtenir l'ID machine
        Write-Host "Obtention de l'ID machine..."
        $machineId = node -e "console.log(require('node-machine-id').machineIdSync())" 2>&1
        Write-Host "Machine ID: $machineId"
        
        # Régénérer la licence
        Write-Host "Régénération de la licence..."
        $licenseCmd = "node tools/packager/pack.js issue-license --vault `"$vaultPath`" --machine `"$machineId`" --expiry 2026-12-31 --owner `"Test User`" --passphrase `"test123`" --all"
        Invoke-Expression $licenseCmd
        
        Write-Host ""
        Write-Host "7. Vérification après régénération..." -ForegroundColor Cyan
        $licenseResult2 = node tools/packager/verify-license.cjs $vaultPath 2>&1
        Write-Host $licenseResult2
        
        if ($licenseResult2 -like "*✔ Signature VALIDE*") {
            Write-Host "✅ Licence régénérée avec succès!" -ForegroundColor Green
        } else {
            Write-Host "❌ Problème avec la licence régénérée" -ForegroundColor Red
        }
    } else {
        Write-Host "✅ Licence déjà valide" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Erreur lors de la vérification de licence: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "8. Test final de connexion..." -ForegroundColor Cyan
try {
    $env:VAULT_PATH = $vaultPath
    npm run build:main | Out-Null
    
    $testCmd = @"
const license = require('./dist/main/license.js');
(async () => {
  try {
    console.log('Test connexion avec test123...');
    const result = await license.enterLicensePassphrase('test123');
    console.log('Résultat:', result.ok ? '✅ SUCCÈS' : '❌ ÉCHEC');
    if (!result.ok && result.error) {
      console.log('Détail erreur:', result.error);
    }
  } catch (e) {
    console.error('❌ Erreur:', e.message);
  }
})();
"@
    
    $testResult = node -e $testCmd 2>&1
    Write-Host $testResult
} catch {
    Write-Host "❌ Erreur lors du test final: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== DIAGNOSTIC TERMINÉ ===" -ForegroundColor Yellow
