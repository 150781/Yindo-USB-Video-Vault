# Post-Install Client - Version Simple
# Deploie license.bin et verifie validation dans les logs

param(
  [string]$VaultPath = $env:VAULT_PATH,
  [string]$LicenseSource = ".\out\license.bin",
  [string]$Exe = "C:\Program Files\USB Video Vault\USB Video Vault.exe"
)

# Configuration par defaut
if (-not $VaultPath) { 
    $VaultPath = Join-Path $env:USERPROFILE "Documents\Yindo-USB-Video-Vault\vault-real" 
}

Write-Host "Post-Install Client USB Video Vault" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# 1. Installer licence
Write-Host "Installation licence..." -ForegroundColor Yellow
$dotVault = Join-Path $VaultPath ".vault"
New-Item -ItemType Directory -Force -Path $dotVault | Out-Null
Copy-Item $LicenseSource (Join-Path $dotVault "license.bin") -Force
Write-Host "OK Licence copiee vers: $(Join-Path $dotVault 'license.bin')" -ForegroundColor Green

# 2. Demarrer application
Write-Host "Demarrage application..." -ForegroundColor Yellow
if (Test-Path $Exe) {
    $proc = Start-Process $Exe -PassThru -WindowStyle Minimized
    Write-Host "OK Application demarree (PID: $($proc.Id))" -ForegroundColor Green
} else {
    Write-Host "WARN Executable non trouve: $Exe" -ForegroundColor Yellow
    Write-Host "   Demarrez manuellement l'application" -ForegroundColor Yellow
}

# 3. Attendre logs
Write-Host "Attente validation (5 secondes)..." -ForegroundColor Yellow
Start-Sleep 5

# 4. Verifier logs
Write-Host "Verification logs..." -ForegroundColor Yellow
$logPaths = @(
    (Join-Path $env:APPDATA "USB Video Vault\logs\main.log"),
    (Join-Path $env:LOCALAPPDATA "USB Video Vault\logs\main.log")
)

$found = $false
foreach ($logPath in $logPaths) {
    if (Test-Path $logPath) {
        $found = $true
        Write-Host "Log: $logPath" -ForegroundColor Cyan
        
        # Rechercher validation
        $validationOK = Select-String -Path $logPath -Pattern "Licence validee" -SimpleMatch -Quiet
        $licenseOK = Select-String -Path $logPath -Pattern "LICENSE.*OK" -SimpleMatch -Quiet
        
        if ($validationOK -or $licenseOK) {
            Write-Host "SUCCESS LICENCE VALIDEE AVEC SUCCES" -ForegroundColor Green
            Write-Host "Installation terminee" -ForegroundColor Green
            exit 0
        } else {
            # Verifier erreurs specifiques
            if (Select-String -Path $logPath -Pattern "Invalid signature" -SimpleMatch -Quiet) {
                Write-Host "ERROR Signature invalide - verifier licence" -ForegroundColor Red
            } elseif (Select-String -Path $logPath -Pattern "Machine binding failed" -SimpleMatch -Quiet) {
                Write-Host "ERROR Machine differente - regenerer licence" -ForegroundColor Red
            } elseif (Select-String -Path $logPath -Pattern "expired" -SimpleMatch -Quiet) {
                Write-Host "ERROR Licence expiree" -ForegroundColor Red
            } else {
                Write-Host "ERROR Verifier signature/binding/expiration" -ForegroundColor Red
            }
            
            Write-Host "" 
            Write-Host "Actions a effectuer:" -ForegroundColor Yellow
            Write-Host "1. Verifier empreinte: node scripts/print-bindings.mjs" -ForegroundColor Yellow
            Write-Host "2. Regenerer si differente machine" -ForegroundColor Yellow
            Write-Host "3. Contacter support si probleme persiste" -ForegroundColor Yellow
            exit 2
        }
        break
    }
}

if (-not $found) {
    Write-Host "WARN Aucun log trouve - application pas demarree?" -ForegroundColor Yellow
    Write-Host "   Demarrer manuellement et verifier" -ForegroundColor Yellow
    exit 1
}