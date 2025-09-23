# Script de signature locale Windows
# Usage: .\tools\sign-local.ps1 -CertPath "C:\path\to\cert.pfx" -Password "password"

param(
    [Parameter(Mandatory=$true)]
    [string]$CertPath,
    
    [Parameter(Mandatory=$true)]
    [string]$Password,
    
    [string]$DistFolder = "dist"
)

Write-Host "=== Signature de code Windows ===" -ForegroundColor Cyan
Write-Host "Certificat: $CertPath"
Write-Host "Dossier dist: $DistFolder"

# Vérifier que le certificat existe
if (-not (Test-Path $CertPath)) {
    Write-Error "Certificat introuvable: $CertPath"
    exit 1
}

# Vérifier que le dossier dist existe
if (-not (Test-Path $DistFolder)) {
    Write-Error "Dossier dist introuvable: $DistFolder"
    Write-Host "Exécutez d'abord: npm run build && npx electron-builder"
    exit 1
}

# Trouver signtool.exe
Write-Host "Recherche de signtool.exe..."
$signtool = $null

# Chemins possibles pour signtool
$possiblePaths = @(
    "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe",
    "C:\Program Files\Microsoft SDKs\Windows\*\bin\signtool.exe",
    "C:\Program Files (x86)\Microsoft SDKs\Windows\*\bin\signtool.exe"
)

foreach ($path in $possiblePaths) {
    $found = Get-ChildItem $path -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
    if ($found) {
        $signtool = $found.FullName
        break
    }
}

if (-not $signtool) {
    Write-Error "signtool.exe introuvable!"
    Write-Host "Installez Windows SDK depuis: https://developer.microsoft.com/windows/downloads/windows-10-sdk/"
    exit 1
}

Write-Host "signtool trouve: $signtool" -ForegroundColor Green

# Chercher tous les fichiers .exe dans dist
$executableFiles = Get-ChildItem $DistFolder -Filter "*.exe" -Recurse

if ($executableFiles.Count -eq 0) {
    Write-Error "Aucun fichier .exe trouve dans $DistFolder"
    exit 1
}

Write-Host "Fichiers a signer:" -ForegroundColor Yellow
$executableFiles | ForEach-Object { Write-Host "  - $($_.FullName)" }

# Signer chaque fichier
$signedCount = 0
foreach ($file in $executableFiles) {
    Write-Host "`nSignature: $($file.Name)..." -ForegroundColor Cyan
    
    $args = @(
        "sign",
        "/fd", "SHA256",
        "/f", $CertPath,
        "/p", $Password,
        "/tr", "http://timestamp.sectigo.com",
        "/td", "SHA256",
        "/d", "USB Video Vault",
        $file.FullName
    )
    
    try {
        & $signtool @args
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Signe avec succes: $($file.Name)" -ForegroundColor Green
            $signedCount++
            
            # Vérification
            & $signtool "verify" "/pa" "/v" $file.FullName | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ Verification OK: $($file.Name)" -ForegroundColor Green
            } else {
                Write-Warning "Probleme de verification pour: $($file.Name)"
            }
        } else {
            Write-Error "Echec signature: $($file.Name)"
        }
    } catch {
        Write-Error "Erreur lors de la signature: $($_.Exception.Message)"
    }
}

Write-Host "`n=== Résumé ===" -ForegroundColor Cyan
Write-Host "Fichiers signes: $signedCount / $($executableFiles.Count)"

if ($signedCount -gt 0) {
    Write-Host "✓ Signature terminee avec succes!" -ForegroundColor Green
    Write-Host "Les fichiers sont maintenant signes et peuvent etre distribues sans alertes SmartScreen."
} else {
    Write-Host "✗ Aucun fichier n'a pu etre signe." -ForegroundColor Red
    exit 1
}