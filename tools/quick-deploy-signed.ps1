# QUICK-DEPLOY-SIGNED.PS1 - Déploiement rapide avec signature
param(
    [Parameter(Mandatory=$true)]
    [string]$CertPath,
    
    [Parameter(Mandatory=$true)]
    [string]$CertPassword,
    
    [switch]$TestMode = $false,
    [string]$Version = "0.1.5"
)

$ErrorActionPreference = "Stop"

Write-Host "=== DÉPLOIEMENT RAPIDE AVEC SIGNATURE DE CODE ===" -ForegroundColor Green

# Étape 1: Générer secrets GitHub
Write-Host "`n1️⃣ GÉNÉRATION SECRETS GITHUB" -ForegroundColor Blue
& ".\tools\generate-github-secrets.ps1" -CertPath $CertPath -CertPassword $CertPassword

Write-Host "`n⏸️  PAUSE: Configurez maintenant les secrets GitHub" -ForegroundColor Yellow
Write-Host "   Allez sur: https://github.com/150781/Yindo-USB-Video-Vault/settings/secrets/actions" -ForegroundColor Cyan
Write-Host "   Ajoutez WINDOWS_CERT_BASE64 et WINDOWS_CERT_PASSWORD" -ForegroundColor Cyan
Write-Host ""
Write-Host "Appuyez sur une touche quand c'est fait..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Étape 2: Commit et tag
Write-Host "`n2️⃣ COMMIT ET TAG" -ForegroundColor Blue

Write-Host "   Ajout des changements..." -ForegroundColor Cyan
git add .
git commit -m "Ready for signed deployment: Optimized workflows, verification scripts, .gitattributes for SHA256SUMS"

# Tag de test ou officiel
if ($TestMode) {
    $tagName = "v$Version-signed-test"
    Write-Host "   Mode TEST: Tag $tagName" -ForegroundColor Yellow
} else {
    $tagName = "v$Version"
    Write-Host "   Mode PRODUCTION: Tag $tagName" -ForegroundColor Green
}

Write-Host "   Création tag $tagName..." -ForegroundColor Cyan
git tag -a $tagName -m "USB Video Vault $tagName - $(if ($TestMode) { 'Signed Test' } else { 'Production' }) Release with Code Signing"

Write-Host "   Push vers GitHub..." -ForegroundColor Cyan
git push origin master
git push origin $tagName

# Étape 3: Monitoring
Write-Host "`n3️⃣ MONITORING WORKFLOW" -ForegroundColor Blue
$actionsUrl = "https://github.com/150781/Yindo-USB-Video-Vault/actions"
Write-Host "   Workflow déclenché pour: $tagName" -ForegroundColor Green
Write-Host "   Surveiller: $actionsUrl" -ForegroundColor Cyan

# Ouvrir GitHub Actions
Start-Process $actionsUrl

Write-Host "`n⏳ Attendre la fin du workflow..." -ForegroundColor Yellow
Write-Host "   Le workflow va:" -ForegroundColor White
Write-Host "   ✅ Builder les EXE" -ForegroundColor White
Write-Host "   ✅ Signer avec votre certificat" -ForegroundColor White
Write-Host "   ✅ Vérifier les signatures" -ForegroundColor White
Write-Host "   ✅ Générer SHA256SUMS (format UNIX)" -ForegroundColor White
Write-Host "   ✅ Créer la Release GitHub" -ForegroundColor White

Write-Host "`n⏸️  Appuyez sur une touche quand le workflow est terminé..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Étape 4: Vérification automatique
Write-Host "`n4️⃣ VÉRIFICATION ARTEFACTS" -ForegroundColor Blue
Write-Host "   Lancement vérification automatique..." -ForegroundColor Cyan

& ".\tools\verify-signed-artifacts.ps1" -Version $Version

# Étape 5: Instructions finales
Write-Host "`n5️⃣ PROCHAINES ÉTAPES" -ForegroundColor Blue

if ($TestMode) {
    Write-Host "   🧪 MODE TEST terminé pour $tagName" -ForegroundColor Yellow
    Write-Host "   Si tout est OK, relancez en mode production:" -ForegroundColor Cyan
    Write-Host "   .\tools\quick-deploy-signed.ps1 -CertPath '$CertPath' -CertPassword '$CertPassword'" -ForegroundColor White
} else {
    Write-Host "   🚀 DÉPLOIEMENT PRODUCTION terminé pour $tagName" -ForegroundColor Green
    Write-Host "   VM Test:" -ForegroundColor Cyan
    Write-Host "   .\tools\test-vm-windows.ps1 -Version '$Version'" -ForegroundColor White
    Write-Host ""
    Write-Host "   Post-release monitoring:" -ForegroundColor Cyan
    Write-Host "   .\tools\post-release-verification.ps1 -Version '$Version'" -ForegroundColor White
    Write-Host ""
    Write-Host "   Release URL:" -ForegroundColor Cyan
    Write-Host "   https://github.com/150781/Yindo-USB-Video-Vault/releases/tag/$tagName" -ForegroundColor White
}

Write-Host "`n✅ DÉPLOIEMENT AVEC SIGNATURE TERMINÉ !" -ForegroundColor Green