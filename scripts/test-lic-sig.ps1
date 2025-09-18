# Test rapide LIC-SIG
Write-Host "=== Test rapide LIC-SIG ===" -ForegroundColor Yellow

Set-Location "c:\Users\patok\Documents\Yindo-USB-Video-Vault"

Write-Host "1. Empreintes des clés:" -ForegroundColor Cyan
node scripts/keys/fingerprint.cjs

Write-Host "`n2. Vérification licence vault:" -ForegroundColor Cyan
$env:VAULT_PATH = "usb-package\vault"
node tools/packager/verify-license.cjs $env:VAULT_PATH

Write-Host "`n3. Test connexion app:" -ForegroundColor Cyan
npm run build:main | Out-Null
node -e "const license = require('./dist/main/license.js'); (async () => { try { const result = await license.enterLicensePassphrase('test123'); console.log('Résultat:', result.ok ? '✅ SUCCÈS' : '❌ ÉCHEC', result.error || ''); } catch (e) { console.error('❌ Erreur:', e.message); } })();"
