# Script simple de conversion PNG vers ICO
param(
    [string]$InputPath = "c:\Users\patok\Downloads\Icon Yindo.png",
    [string]$OutputPath = "build\icon.ico"
)

Write-Host "🎨 Conversion icône Yindo : PNG → ICO" -ForegroundColor Cyan

# Vérifier fichier source
if (-not (Test-Path $InputPath)) {
    Write-Error "❌ Fichier introuvable: $InputPath"
    Write-Host "💡 Vérifiez le chemin vers Icon Yindo.png"
    exit 1
}

# Créer dossier build
$buildDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $buildDir)) {
    New-Item -Path $buildDir -ItemType Directory -Force | Out-Null
}

# Utiliser .NET pour la conversion
Add-Type -AssemblyName System.Drawing

$bitmap = $null
$iconStream = $null

try {
    $bitmap = New-Object System.Drawing.Bitmap($InputPath)
    Write-Host "📏 Image source: $($bitmap.Width)x$($bitmap.Height)"
    
    # Redimensionner à 512x512 si nécessaire
    if ($bitmap.Width -ne 512 -or $bitmap.Height -ne 512) {
        Write-Host "🔄 Redimensionnement vers 512x512..."
        $resized = New-Object System.Drawing.Bitmap(512, 512)
        $graphics = [System.Drawing.Graphics]::FromImage($resized)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($bitmap, 0, 0, 512, 512)
        $graphics.Dispose()
        $bitmap.Dispose()
        $bitmap = $resized
    }
    
    # Conversion vers ICO
    $iconStream = New-Object System.IO.MemoryStream
    $bitmap.Save($iconStream, [System.Drawing.Imaging.ImageFormat]::Icon)
    [System.IO.File]::WriteAllBytes($OutputPath, $iconStream.ToArray())
    
    Write-Host "✅ Icône convertie avec succès !" -ForegroundColor Green
    
    $fileSize = (Get-Item $OutputPath).Length
    Write-Host "📊 Fichier ICO: $([math]::Round($fileSize/1KB, 2)) KB"
}
finally {
    if ($bitmap) { $bitmap.Dispose() }
    if ($iconStream) { $iconStream.Dispose() }
}