#!/usr/bin/env pwsh
# Script de réparation rapide du vault 404

Write-Host "=== FIX VAULT 404 ===" -ForegroundColor Yellow

$VAULT_DIR = "usb-package\vault"
$MEDIA_DIR = "$VAULT_DIR\media"

Write-Host "1. Vérification structure vault..." -ForegroundColor Cyan
if (!(Test-Path $VAULT_DIR)) {
    Write-Host "❌ Vault introuvable: $VAULT_DIR" -ForegroundColor Red
    exit 1
}

if (!(Test-Path $MEDIA_DIR)) {
    Write-Host "📁 Création dossier media..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $MEDIA_DIR -Force | Out-Null
}

Write-Host "2. Contenu actuel du vault:" -ForegroundColor Cyan
Get-ChildItem $VAULT_DIR -Recurse | ForEach-Object {
    $relativePath = $_.FullName.Replace((Get-Location).Path + "\", "")
    Write-Host "  📁 $relativePath" -ForegroundColor Gray
}

Write-Host "3. Fichiers dans media/:" -ForegroundColor Cyan
$mediaFiles = Get-ChildItem $MEDIA_DIR -ErrorAction SilentlyContinue
if ($mediaFiles) {
    $mediaFiles | ForEach-Object { Write-Host "  🎬 $($_.Name) ($([math]::Round($_.Length/1KB)) KB)" -ForegroundColor Green }
} else {
    Write-Host "  ❌ Aucun fichier média trouvé" -ForegroundColor Red
    
    Write-Host "4. Copie des médias de test..." -ForegroundColor Yellow
    $testFiles = @("src\assets\demo.mp4", "src\assets\Odogwu.mp4")
    foreach ($file in $testFiles) {
        if (Test-Path $file) {
            $dest = Join-Path $MEDIA_DIR (Split-Path $file -Leaf)
            Copy-Item $file $dest -Force
            Write-Host "  ✅ Copié: $file → $dest" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Fichier source introuvable: $file" -ForegroundColor Yellow
        }
    }
}

Write-Host "5. Reconstruction du manifest..." -ForegroundColor Cyan
try {
    # Rebuild manifest et licence
    & node tools/packager/pack.js init --vault $VAULT_DIR
    Write-Host "  ✅ Vault initialisé" -ForegroundColor Green
    
    & node tools/packager/pack.js add-media --vault $VAULT_DIR --auto
    Write-Host "  ✅ Médias ajoutés au manifest" -ForegroundColor Green
    
    & node tools/packager/pack.js issue-license --vault $VAULT_DIR --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine "928fb2e42e9de3a9e7305842ef114ae7ef35cb2e7e8003a37da07fd410e45bc5" --all
    Write-Host "  ✅ Licence générée" -ForegroundColor Green
    
} catch {
    Write-Host "  ❌ Erreur lors de la reconstruction: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "6. Vérification finale..." -ForegroundColor Cyan
$finalMediaFiles = Get-ChildItem $MEDIA_DIR -ErrorAction SilentlyContinue
if ($finalMediaFiles) {
    Write-Host "  ✅ $($finalMediaFiles.Count) fichiers média présents" -ForegroundColor Green
    Write-Host "  🔄 Redémarrez l'app pour tester le vault://" -ForegroundColor Yellow
} else {
    Write-Host "  ❌ Toujours aucun fichier média" -ForegroundColor Red
}

Write-Host "`n=== FIN FIX VAULT 404 ===" -ForegroundColor Yellow
