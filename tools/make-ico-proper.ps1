# Conversion PNG vers ICO compatible Windows
# Utilise une méthode différente pour créer un ICO valide

param(
    [string]$InputPath = "c:\Users\patok\Downloads\Icon Yindo.png",
    [string]$OutputPath = "build\icon.ico"
)

Write-Host "Creation icone ICO compatible Windows..."

if (-not (Test-Path $InputPath)) {
    Write-Host "Erreur: Fichier source non trouve: $InputPath"
    exit 1
}

if (-not (Test-Path "build")) {
    New-Item -Path "build" -ItemType Directory -Force
}

# Supprimer l'ancien ICO défectueux
if (Test-Path $OutputPath) {
    Remove-Item $OutputPath -Force
}

Add-Type -AssemblyName System.Drawing

# Charger l'image PNG
$originalBitmap = New-Object System.Drawing.Bitmap($InputPath)
Write-Host "Image source: $($originalBitmap.Width)x$($originalBitmap.Height)"

# Créer plusieurs tailles pour l'ICO (format multi-résolution)
$sizes = @(16, 32, 48, 64, 128, 256)
$bitmaps = @()

foreach ($size in $sizes) {
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.DrawImage($originalBitmap, 0, 0, $size, $size)
    $graphics.Dispose()
    $bitmaps += $bitmap
    Write-Host "Cree: ${size}x${size}"
}

# Sauvegarder seulement la version 256x256 en ICO
# (simplicité - un seul format évite les problèmes de header)
$iconBitmap = $bitmaps | Where-Object { $_.Width -eq 256 }

# Convertir en format ICO approprié
$ms = New-Object System.IO.MemoryStream

# Créer un ICO simple avec une seule résolution
# Header ICO: 6 bytes + 16 bytes par image + données
$writer = New-Object System.IO.BinaryWriter($ms)

# ICO Header
$writer.Write([uint16]0)    # Reserved (0)
$writer.Write([uint16]1)    # Type (1 = ICO)
$writer.Write([uint16]1)    # Count (1 image)

# Image Directory Entry
$writer.Write([byte]0)      # Width (0 = 256)
$writer.Write([byte]0)      # Height (0 = 256)
$writer.Write([byte]0)      # Colors (0)
$writer.Write([byte]0)      # Reserved
$writer.Write([uint16]1)    # Planes
$writer.Write([uint16]32)   # Bits per pixel
$writer.Write([uint32]0)    # Size (set later)
$writer.Write([uint32]22)   # Offset (after headers)

# Convertir bitmap en PNG pour les données
$pngStream = New-Object System.IO.MemoryStream
$iconBitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
$pngData = $pngStream.ToArray()

# Mettre à jour la taille dans le header
$ms.Seek(14, [System.IO.SeekOrigin]::Begin)
$writer.Write([uint32]$pngData.Length)

# Écrire les données PNG
$ms.Seek(0, [System.IO.SeekOrigin]::End)
$writer.Write($pngData)

# Sauvegarder le fichier ICO
[System.IO.File]::WriteAllBytes($OutputPath, $ms.ToArray())

# Nettoyer
$writer.Dispose()
$ms.Dispose()
$pngStream.Dispose()
$originalBitmap.Dispose()
foreach ($bitmap in $bitmaps) { $bitmap.Dispose() }

if (Test-Path $OutputPath) {
    $size = (Get-Item $OutputPath).Length
    Write-Host "Succes! ICO cree: $OutputPath ($size bytes)"
} else {
    Write-Host "Echec de la creation"
    exit 1
}
