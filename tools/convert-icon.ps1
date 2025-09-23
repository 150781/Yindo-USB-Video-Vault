# Convertir l'icône PNG en ICO avec PowerShell
# Nécessite Windows 10+ avec .NET Framework

param(
    [string]$InputPath = "c:\Users\patok\Downloads\Icon Yindo.png",
    [string]$OutputPath = "build\icon.ico",
    [int]$Size = 512
)

Write-Host "🎨 Conversion icône Yindo : PNG → ICO" -ForegroundColor Cyan
Write-Host "📁 Source: $InputPath"
Write-Host "📁 Destination: $OutputPath"

# Vérifier que le fichier source existe
if (-not (Test-Path $InputPath)) {
    Write-Error "❌ Fichier source introuvable: $InputPath"
    Write-Host "💡 Assurez-vous que l'icône Yindo.png est dans Downloads"
    exit 1
}

# Créer le dossier build s'il n'existe pas
$buildDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $buildDir)) {
    New-Item -Path $buildDir -ItemType Directory -Force | Out-Null
    Write-Host "📁 Dossier build créé"
}

try {
    # Charger l'image PNG
    Add-Type -AssemblyName System.Drawing
    $bitmap = New-Object System.Drawing.Bitmap($InputPath)
    
    Write-Host "📏 Image source: $($bitmap.Width)x$($bitmap.Height)"
    
    # Redimensionner si nécessaire
    if ($bitmap.Width -ne $Size -or $bitmap.Height -ne $Size) {
        Write-Host "🔄 Redimensionnement vers ${Size}x${Size}..."
        $resized = New-Object System.Drawing.Bitmap($Size, $Size)
        $graphics = [System.Drawing.Graphics]::FromImage($resized)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($bitmap, 0, 0, $Size, $Size)
        $graphics.Dispose()
        $bitmap.Dispose()
        $bitmap = $resized
    }
    
    # Sauvegarder en ICO
    $iconStream = New-Object System.IO.MemoryStream
    $bitmap.Save($iconStream, [System.Drawing.Imaging.ImageFormat]::Icon)
    [System.IO.File]::WriteAllBytes($OutputPath, $iconStream.ToArray())
    
    $bitmap.Dispose()
    $iconStream.Dispose()
    
    Write-Host "✅ Icône convertie avec succès !" -ForegroundColor Green
    Write-Host "📦 Prêt pour Electron Builder"
    
    # Vérifier la taille du fichier généré
    $fileSize = (Get-Item $OutputPath).Length
    Write-Host "📊 Taille fichier ICO: $([math]::Round($fileSize/1KB, 2)) KB"
    
}
catch {
    Write-Error "❌ Erreur lors de la conversion: $($_.Exception.Message)"
    Write-Host "💡 Alternative: utilisez un convertisseur en ligne PNG → ICO"
    Write-Host "💡 Ou installez ImageMagick: magick Icon.png -resize 512x512 build/icon.ico"
    exit 1
}