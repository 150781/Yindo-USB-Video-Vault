# Conversion PNG vers ICO
Write-Host "Conversion icone Yindo..."

$source = "c:\Users\patok\Downloads\Icon Yindo.png"
$target = "build\icon.ico"

if (-not (Test-Path $source)) {
    Write-Host "Erreur: Fichier source non trouve"
    exit 1
}

if (-not (Test-Path "build")) {
    New-Item -Path "build" -ItemType Directory -Force
}

Add-Type -AssemblyName System.Drawing

$img = [System.Drawing.Image]::FromFile($source)
Write-Host "Dimensions: $($img.Width) x $($img.Height)"

$img.Save($target, [System.Drawing.Imaging.ImageFormat]::Icon)
$img.Dispose()

if (Test-Path $target) {
    $size = (Get-Item $target).Length
    Write-Host "Succes! Icone creee: $target ($size bytes)"
} else {
    Write-Host "Echec de la creation"
}