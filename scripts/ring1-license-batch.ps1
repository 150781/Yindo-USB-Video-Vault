# Generateur de licences Ring 1 en lot
# Usage: .\scripts\ring1-license-batch.ps1 -FingerprintDir ".\fingerprints"

param(
    [Parameter(Mandatory=$true)]
    [string]$FingerprintDir,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "deliveries\ring1",
    
    [Parameter(Mandatory=$false)]
    [switch]$Verify
)

$ErrorActionPreference = "Stop"

function Write-LicenseLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "INFO" { "White" }
        "STEP" { "Cyan" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

Write-LicenseLog "=== GENERATEUR LICENCES RING 1 ===" "STEP"
Write-LicenseLog "Fingerprints: $FingerprintDir | Output: $OutputDir" "INFO"
Write-Host ""

# Creer repertoire output
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-LicenseLog "Repertoire cree: $OutputDir" "INFO"
}

# Chercher fichiers fingerprint.json
$fingerprintFiles = Get-ChildItem -Path $FingerprintDir -Filter "*.json" -Recurse

if ($fingerprintFiles.Count -eq 0) {
    Write-LicenseLog "ERROR Aucun fichier fingerprint.json trouve dans $FingerprintDir" "ERROR"
    exit 1
}

Write-LicenseLog "Fichiers fingerprint trouves: $($fingerprintFiles.Count)" "INFO"

$successCount = 0
$results = @()

foreach ($file in $fingerprintFiles) {
    try {
        Write-LicenseLog "Traitement: $($file.Name)" "STEP"
        
        # Lire fingerprint
        $fingerprintData = Get-Content $file.FullName | ConvertFrom-Json
        $fingerprint = $fingerprintData.fingerprint
        $hostname = $fingerprintData.hostname
        $usbSerial = if ($fingerprintData.usbSerial) { $fingerprintData.usbSerial } else { "" }
        
        Write-LicenseLog "  Machine: $hostname" "INFO"
        Write-LicenseLog "  Fingerprint: $fingerprint" "INFO"
        
        # Generer licence
        & node .\scripts\make-license.mjs $fingerprint $usbSerial 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            # Deplacer licence depuis vault-real\.vault\license.bin
            $licenseFileName = "$hostname-$fingerprint-license.bin"
            $licensePath = "$OutputDir\$licenseFileName"
            $sourceLicense = "vault-real\.vault\license.bin"
            
            if (Test-Path $sourceLicense) {
                Copy-Item $sourceLicense $licensePath -Force
                Write-LicenseLog "  OK Licence creee: $licenseFileName" "SUCCESS"
                
                # Verifier si demande
                if ($Verify) {
                    & node .\scripts\verify-license.mjs $licensePath 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-LicenseLog "  OK Licence verifiee" "SUCCESS"
                    } else {
                        Write-LicenseLog "  WARN Licence non verifiable" "WARN"
                    }
                }
                
                $results += @{
                    Hostname = $hostname
                    Fingerprint = $fingerprint
                    LicenseFile = $licenseFileName
                    Status = "SUCCESS"
                    Source = $file.Name
                }
                $successCount++
                
            } else {
                Write-LicenseLog "  ERROR Fichier licence non genere" "ERROR"
                $results += @{
                    Hostname = $hostname
                    Fingerprint = $fingerprint
                    Status = "ERROR"
                    Error = "Fichier licence non genere"
                    Source = $file.Name
                }
            }
        } else {
            Write-LicenseLog "  ERROR Generation licence echouee (exit code: $LASTEXITCODE)" "ERROR"
            $results += @{
                Hostname = $hostname
                Fingerprint = $fingerprint
                Status = "ERROR"
                Error = "Generation echouee"
                Source = $file.Name
            }
        }
        
    } catch {
        Write-LicenseLog "  ERROR Exception: $($_.Exception.Message)" "ERROR"
        $results += @{
            Status = "ERROR"
            Error = $_.Exception.Message
            Source = $file.Name
        }
    }
    
    Write-Host ""
}

# Generer rapport
$report = @{
    Timestamp = Get-Date
    FingerprintDir = $FingerprintDir
    OutputDir = $OutputDir
    TotalFiles = $fingerprintFiles.Count
    SuccessCount = $successCount
    Results = $results
}

$reportPath = "$OutputDir\ring1-license-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$report | ConvertTo-Json -Depth 3 | Out-File $reportPath -Encoding UTF8

# Resume final
Write-LicenseLog "=== RESUME GENERATION RING 1 ===" "STEP"
Write-LicenseLog "Licences generees: $successCount/$($fingerprintFiles.Count)" "INFO"
Write-LicenseLog "Rapport sauvegarde: $reportPath" "INFO"

# Instructions livraison
if ($successCount -gt 0) {
    Write-Host ""
    Write-LicenseLog "=== INSTRUCTIONS LIVRAISON ===" "STEP"
    Write-LicenseLog "1. Verifier les licences:" "INFO"
    Write-LicenseLog "   Get-ChildItem $OutputDir -Filter '*license.bin'" "INFO"
    Write-Host ""
    Write-LicenseLog "2. Envoyer aux clients avec instructions:" "INFO"
    Write-LicenseLog "   - Copier licence dans: C:\ProgramData\USB Video Vault\" "INFO"
    Write-LicenseLog "   - Redemarrer l'application" "INFO"
    Write-Host ""
    Write-LicenseLog "3. Controler apres installation:" "INFO"
    Write-LicenseLog "   .\scripts\production-controls.ps1 -LicensePath <chemin>" "INFO"
}

if ($successCount -eq $fingerprintFiles.Count) {
    Write-LicenseLog "GENERATION RING 1: SUCCES COMPLET !" "SUCCESS"
    exit 0
} else {
    Write-LicenseLog "GENERATION RING 1: ECHECS PARTIELS" "WARN"
    exit 1
}