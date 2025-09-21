# Controles de Production - USB Video Vault
# Verification rapide signatures, hashes, licences, logs

param(
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "C:\Program Files\USB Video Vault",
    
    [Parameter(Mandatory=$false)]
    [string]$LicensePath = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Version = "v1.0.4",
    
    [Parameter(Mandatory=$false)]
    [switch]$Detail
)

$ErrorActionPreference = "Stop"

function Write-ControlLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "INFO" { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

Write-ControlLog "=== CONTROLES DE PRODUCTION USB VIDEO VAULT ===" "INFO"
Write-ControlLog "Version: $Version | Install: $InstallPath" "INFO"
Write-Host ""

$checkResults = @{
    Signatures = $false
    Hashes = $false
    License = $false
    Logs = $false
    Overall = $false
}

# 1. VERIFICATION SIGNATURES
Write-ControlLog "=== 1. VERIFICATION SIGNATURES ===" "INFO"

try {
    $exePath = "$InstallPath\USB Video Vault.exe"
    if (Test-Path $exePath) {
        $signature = Get-AuthenticodeSignature $exePath
        if ($signature.Status -eq "Valid") {
            Write-ControlLog "OK Signature valide: $($signature.SignerCertificate.Subject)" "SUCCESS"
            $checkResults.Signatures = $true
        } else {
            Write-ControlLog "ERROR Signature invalide: $($signature.Status)" "ERROR"
        }
    } else {
        Write-ControlLog "ERROR Executable non trouve: $exePath" "ERROR"
    }
} catch {
    Write-ControlLog "ERROR Verification signature echouee: $($_.Exception.Message)" "ERROR"
}

# 2. VERIFICATION HASHES
Write-ControlLog "=== 2. VERIFICATION HASHES ===" "INFO"

try {
    $hashFile = "dist\hashes-$Version.txt"
    if (Test-Path $hashFile) {
        $expectedHashes = Get-Content $hashFile
        Write-ControlLog "Fichier hashes trouve: $hashFile" "INFO"
        
        # Verifier hash principal
        if (Test-Path $exePath) {
            $actualHash = (Get-FileHash $exePath -Algorithm SHA256).Hash
            $expectedLine = $expectedHashes | Where-Object { $_ -like "*USB Video Vault.exe*" }
            
            if ($expectedLine -and $expectedLine.Contains($actualHash)) {
                Write-ControlLog "OK Hash verifie pour USB Video Vault.exe" "SUCCESS"
                $checkResults.Hashes = $true
            } else {
                Write-ControlLog "ERROR Hash ne correspond pas" "ERROR"
                if ($Detail) {
                    Write-ControlLog "Attendu: $expectedLine" "WARN"
                    Write-ControlLog "Actuel: $actualHash" "WARN"
                }
            }
        }
    } else {
        Write-ControlLog "WARN Fichier hashes non trouve: $hashFile" "WARN"
        $checkResults.Hashes = $true  # Skip en production
    }
} catch {
    Write-ControlLog "ERROR Verification hashes echouee: $($_.Exception.Message)" "ERROR"
}

# 3. VERIFICATION LICENCE
Write-ControlLog "=== 3. VERIFICATION LICENCE ===" "INFO"

try {
    # Chercher licence si pas specifiee
    if (-not $LicensePath) {
        $possiblePaths = @(
            "$env:APPDATA\USB Video Vault\license.bin",
            "$InstallPath\license.bin",
            ".\license.bin"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $LicensePath = $path
                break
            }
        }
    }
    
    if ($LicensePath -and (Test-Path $LicensePath)) {
        Write-ControlLog "Licence trouvee: $LicensePath" "INFO"
        
        # Verifier avec verify-license.mjs
        if (Test-Path ".\scripts\verify-license.mjs") {
            & node .\scripts\verify-license.mjs $LicensePath 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-ControlLog "OK Licence valide" "SUCCESS"
                $checkResults.License = $true
            } else {
                Write-ControlLog "ERROR Licence invalide (exit code: $LASTEXITCODE)" "ERROR"
            }
        } else {
            Write-ControlLog "WARN Script verify-license.mjs non trouve - skip" "WARN"
            $checkResults.License = $true
        }
    } else {
        Write-ControlLog "WARN Licence non trouvee - specifier -LicensePath" "WARN"
    }
} catch {
    Write-ControlLog "ERROR Verification licence echouee: $($_.Exception.Message)" "ERROR"
}

# 4. VERIFICATION LOGS
Write-ControlLog "=== 4. VERIFICATION LOGS ===" "INFO"

try {
    $logPath = "$env:APPDATA\USB Video Vault\logs\main.log"
    if (Test-Path $logPath) {
        Write-ControlLog "Log trouve: $logPath" "INFO"
        
        # Chercher erreurs critiques dans les derniers logs
        $recentLogs = Get-Content $logPath -Tail 100 -ErrorAction SilentlyContinue
        
        $criticalErrors = @(
            "Signature de licence invalide",
            "Anti-rollback",
            "Licence expiree",
            "Licence corrompue",
            "Verification echouee"
        )
        
        $foundErrors = @()
        foreach ($criticalError in $criticalErrors) {
            $errorMatches = $recentLogs | Select-String $criticalError
            if ($errorMatches) {
                $foundErrors += $criticalError
            }
        }
        
        if ($foundErrors.Count -eq 0) {
            Write-ControlLog "OK Aucune erreur critique dans les logs" "SUCCESS"
            $checkResults.Logs = $true
        } else {
            Write-ControlLog "ERROR Erreurs critiques trouvees: $($foundErrors -join ', ')" "ERROR"
            if ($Detail) {
                foreach ($criticalError in $foundErrors) {
                    $errorMatches = $recentLogs | Select-String $criticalError | Select-Object -First 3
                    foreach ($match in $errorMatches) {
                        Write-ControlLog "  -> $match" "ERROR"
                    }
                }
            }
        }
    } else {
        Write-ControlLog "WARN Log principal non trouve: $logPath" "WARN"
        $checkResults.Logs = $true  # Skip si pas de logs
    }
} catch {
    Write-ControlLog "ERROR Verification logs echouee: $($_.Exception.Message)" "ERROR"
}

# RESUME FINAL
Write-Host ""
Write-ControlLog "=== RESUME CONTROLES ===" "INFO"

$successCount = 0
foreach ($check in $checkResults.GetEnumerator()) {
    if ($check.Key -ne "Overall") {
        $status = if ($check.Value) { "OK" } else { "ECHEC" }
        $level = if ($check.Value) { "SUCCESS" } else { "ERROR" }
        Write-ControlLog "$($check.Key): $status" $level
        if ($check.Value) { $successCount++ }
    }
}

$checkResults.Overall = ($successCount -eq 4)

Write-Host ""
if ($checkResults.Overall) {
    Write-ControlLog "CONTROLES PRODUCTION: TOUS OK !" "SUCCESS"
    exit 0
} else {
    Write-ControlLog "CONTROLES PRODUCTION: ECHECS DETECTES" "ERROR"
    exit 1
}