# Conversion PNG vers ICO - Version simplifiée
Write-Host "🎨 Conversion icône Yindo"

$sourcePath = "c:\Users\patok\Downloads\Icon Yindo.png"
$targetPath = "build\icon.ico"

if (-not (Test-Path $sourcePath)) {
    Write-Host "❌ Fichier source non trouvé: $sourcePath"
    Write-Host "💡 Copiez d'abord l'icône Yindo.png dans Downloads"
    exit 1
}

if (-not (Test-Path "build")) {
    New-Item -Path "build" -ItemType Directory -Force
}

# Utilisation simple de .NET
Add-Type -AssemblyName System.Drawing

$img = [System.Drawing.Image]::FromFile($sourcePath)
Write-Host "📏 Dimensions: $($img.Width) x $($img.Height)"

# Sauvegarder directement (pas de redimensionnement sophistiqué)
$img.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Icon)
$img.Dispose()

if (Test-Path $targetPath) {
    $size = (Get-Item $targetPath).Length
    Write-Host "✅ Icône créée: $targetPath ($([math]::Round($size/1KB, 1)) KB)"
} else {
    Write-Host "❌ Échec de la création"
}
