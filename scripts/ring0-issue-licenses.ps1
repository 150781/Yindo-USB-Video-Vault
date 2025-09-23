# Script d'Émission de Licences Ring 0
# USB Video Vault - Émission en lot pour Ring 0

param(
    [Parameter(Mandatory=$false)]
    [string]$InputCSV = "ring0-for-licenses.csv",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "deliveries",
    
    [Parameter(Mandatory=$false)]
    [string]$KID = "1",
    
    [Parameter(Mandatory=$false)]
    [string]$ExpirationDate = "2026-12-31T23:59:59Z",
    
    [Parameter(Mandatory=$false)]
    [string]$AuditFile = "ring0-audit.csv",
    
    [Parameter(Mandatory=$false)]
    [switch]$VerifyOnly = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

function Write-LicenseLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "STEP" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-LicenseLog "Vérification des prérequis..." "STEP"
    
    # Node.js
    try {
        $nodeVersion = node --version
        Write-LicenseLog "✓ Node.js: $nodeVersion" "SUCCESS"
    }
    catch {
        Write-LicenseLog "❌ Node.js requis" "ERROR"
        throw
    }
    
    # Scripts nécessaires
    $requiredScripts = @(
        "scripts\make-license.mjs",
        "scripts\verify-license.mjs"
    )
    
    foreach ($script in $requiredScripts) {
        if (-not (Test-Path $script)) {
            Write-LicenseLog "❌ Script manquant: $script" "ERROR"
            throw "Scripts manquants"
        }
    }
    
    Write-LicenseLog "✓ Scripts disponibles" "SUCCESS"
    
    # Répertoire de sortie
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-LicenseLog "✓ Répertoire créé: $OutputDir" "SUCCESS"
    }
    
    # Fichier CSV d'entrée
    if (-not (Test-Path $InputCSV)) {
        Write-LicenseLog "❌ Fichier CSV non trouvé: $InputCSV" "ERROR"
        throw "CSV manquant"
    }
    
    Write-LicenseLog "Prérequis validés" "SUCCESS"
}

function Get-MachineData {
    param([string]$CSVPath)
    
    Write-LicenseLog "Lecture données machines: $CSVPath" "INFO"
    
    try {
        $machines = Import-Csv -Path $CSVPath
        
        if (-not $machines -or $machines.Count -eq 0) {
            Write-LicenseLog "❌ Aucune machine dans le CSV" "ERROR"
            throw "CSV vide"
        }
        
        # Valider colonnes requises
        $firstMachine = $machines[0]
        if (-not $firstMachine.machine -or -not $firstMachine.fingerprint) {
            Write-LicenseLog "❌ Colonnes requises manquantes: machine, fingerprint" "ERROR"
            throw "Format CSV invalide"
        }
        
        Write-LicenseLog "✓ Machines trouvées: $($machines.Count)" "SUCCESS"
        
        return $machines
        
    }
    catch {
        Write-LicenseLog "❌ Erreur lecture CSV: $_" "ERROR"
        throw
    }
}

function New-LicenseForMachine {
    param(
        [PSCustomObject]$Machine,
        [string]$KID,
        [string]$ExpirationDate,
        [string]$OutputDir
    )
    
    $machineName = $Machine.machine
    $fingerprint = $Machine.fingerprint
    $usbSerial = $Machine.usbSerial
    
    Write-LicenseLog "Émission licence: $machineName" "STEP"
    
    try {
        # Construire commande make-license
        $makeArgs = @($fingerprint)
        
        if (-not [string]::IsNullOrWhiteSpace($usbSerial)) {
            $makeArgs += $usbSerial
            Write-LicenseLog "  USB: $usbSerial" "INFO"
        } else {
            Write-LicenseLog "  Pas d'USB associé" "INFO"
        }
        
        $makeArgs += @("--kid", $KID, "--exp", $ExpirationDate)
        
        if ($Verbose) {
            Write-LicenseLog "Commande: node scripts\make-license.mjs $($makeArgs -join ' ')" "INFO"
        }
        
        # Émission
        $makeOutput = & node "scripts\make-license.mjs" @makeArgs 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-LicenseLog "❌ Échec émission pour $machineName : $makeOutput" "ERROR"
            return $null
        }
        
        # Vérification
        if (Test-Path "out\license.bin") {
            $verifyOutput = & node "scripts\verify-license.mjs" "out\license.bin" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-LicenseLog "✓ Licence vérifiée" "SUCCESS"
            } else {
                Write-LicenseLog "❌ Échec vérification: $verifyOutput" "ERROR"
                return $null
            }
        } else {
            Write-LicenseLog "❌ Fichier licence non créé" "ERROR"
            return $null
        }
        
        # Sauvegarde nommée
        $outputFile = Join-Path $OutputDir "$machineName-license.bin"
        Copy-Item -Path "out\license.bin" -Destination $outputFile -Force
        
        Write-LicenseLog "✓ Licence sauvegardée: $outputFile" "SUCCESS"
        
        # Informations pour audit
        $licenseInfo = @{
            Machine = $machineName
            Fingerprint = $fingerprint
            UsbSerial = $usbSerial
            KID = $KID
            ExpirationDate = $ExpirationDate
            OutputFile = $outputFile
            IssuedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            IssuedBy = $env:USERNAME
            Success = $true
        }
        
        # Calculer hash du fichier
        if (Test-Path $outputFile) {
            $hash = Get-FileHash -Path $outputFile -Algorithm SHA256
            $licenseInfo.SHA256 = $hash.Hash
            $licenseInfo.FileSize = (Get-Item $outputFile).Length
        }
        
        return $licenseInfo
        
    }
    catch {
        Write-LicenseLog "❌ Erreur émission $machineName : $_" "ERROR"
        
        return @{
            Machine = $machineName
            Fingerprint = $fingerprint
            UsbSerial = $usbSerial
            KID = $KID
            ExpirationDate = $ExpirationDate
            OutputFile = $null
            IssuedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            IssuedBy = $env:USERNAME
            Success = $false
            Error = $_.ToString()
        }
    }
}

function Test-ExistingLicense {
    param([string]$LicenseFile)
    
    if (-not (Test-Path $LicenseFile)) {
        return $false
    }
    
    try {
        $verifyOutput = & node "scripts\verify-license.mjs" $LicenseFile 2>&1
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

function Export-AuditTrail {
    param([array]$Results, [string]$AuditFile)
    
    Write-LicenseLog "Export audit trail: $AuditFile" "STEP"
    
    try {
        # En-têtes audit
        $auditHeaders = @(
            "machine",
            "fingerprint", 
            "usbSerial",
            "kid",
            "expirationDate",
            "outputFile",
            "issuedAt",
            "issuedBy",
            "success",
            "sha256",
            "fileSize",
            "error"
        )
        
        $auditLines = @($auditHeaders -join ",")
        
        foreach ($result in $Results) {
            if ($result) {
                $line = @(
                    $result.Machine,
                    $result.Fingerprint,
                    $(if ($result.UsbSerial) { $result.UsbSerial } else { "" }),
                    $result.KID,
                    $result.ExpirationDate,
                    $(if ($result.OutputFile) { $result.OutputFile } else { "" }),
                    $result.IssuedAt,
                    $result.IssuedBy,
                    $result.Success,
                    $(if ($result.SHA256) { $result.SHA256 } else { "" }),
                    $(if ($result.FileSize) { $result.FileSize } else { "" }),
                    $(if ($result.Error) { $result.Error -replace '"', '""' } else { "" })
                ) -join ","
                
                $auditLines += $line
            }
        }
        
        $auditLines | Out-File -FilePath $AuditFile -Encoding UTF8
        Write-LicenseLog "✓ Audit exporté: $AuditFile" "SUCCESS"
        
    }
    catch {
        Write-LicenseLog "❌ Erreur export audit: $_" "ERROR"
    }
}

function Show-IssuanceSummary {
    param([array]$Results)
    
    Write-LicenseLog "=== RÉSUMÉ ÉMISSION RING 0 ===" "STEP"
    
    $successful = $Results | Where-Object { $_.Success -eq $true }
    $failed = $Results | Where-Object { $_.Success -eq $false }
    $withUsb = $successful | Where-Object { $_.UsbSerial }
    
    Write-LicenseLog "Total traité: $($Results.Count)" "INFO"
    Write-LicenseLog "Succès: $($successful.Count)" "SUCCESS"
    Write-LicenseLog "Échecs: $($failed.Count)" "$(if ($failed.Count -gt 0) { 'ERROR' } else { 'INFO' })"
    Write-LicenseLog "Avec USB: $($withUsb.Count)" "INFO"
    
    if ($failed.Count -gt 0) {
        Write-LicenseLog "Machines en échec:" "ERROR"
        foreach ($failure in $failed) {
            Write-LicenseLog "  - $($failure.Machine): $($failure.Error)" "ERROR"
        }
    }
    
    if ($successful.Count -gt 0) {
        Write-LicenseLog "Prochaines étapes:" "INFO"
        Write-LicenseLog "1. Vérifier licences dans: $OutputDir" "INFO"
        Write-LicenseLog "2. Déployer sur machines Ring 0" "INFO"
        Write-LicenseLog "3. Exécuter smoke tests" "INFO"
        Write-LicenseLog "4. Commencer monitoring" "INFO"
    }
}

function Invoke-LicenseVerification {
    param([string]$OutputDir)
    
    Write-LicenseLog "Vérification des licences générées..." "STEP"
    
    try {
        $licenseFiles = Get-ChildItem -Path $OutputDir -Filter "*-license.bin"
        
        if ($licenseFiles.Count -eq 0) {
            Write-LicenseLog "❌ Aucune licence trouvée dans $OutputDir" "ERROR"
            return
        }
        
        $verifiedCount = 0
        
        foreach ($licenseFile in $licenseFiles) {
            $machineName = $licenseFile.BaseName -replace "-license$", ""
            
            if (Test-ExistingLicense -LicenseFile $licenseFile.FullName) {
                Write-LicenseLog "✓ $machineName : Licence valide" "SUCCESS"
                $verifiedCount++
            } else {
                Write-LicenseLog "❌ $machineName : Licence invalide" "ERROR"
            }
        }
        
        Write-LicenseLog "Vérifiées: $verifiedCount / $($licenseFiles.Count)" "INFO"
        
    }
    catch {
        Write-LicenseLog "❌ Erreur vérification: $_" "ERROR"
    }
}

# Fonction principale
function Main {
    Write-LicenseLog "=== Émission de Licences Ring 0 - USB Video Vault ===" "STEP"
    
    try {
        Test-Prerequisites
        
        # Mode vérification seule
        if ($VerifyOnly) {
            Invoke-LicenseVerification -OutputDir $OutputDir
            return
        }
        
        # Lecture données machines
        $machines = Get-MachineData -CSVPath $InputCSV
        
        Write-LicenseLog "Paramètres émission:" "INFO"
        Write-LicenseLog "  KID: $KID" "INFO"
        Write-LicenseLog "  Expiration: $ExpirationDate" "INFO"
        Write-LicenseLog "  Machines: $($machines.Count)" "INFO"
        
        # Émission des licences
        $results = @()
        $current = 0
        
        foreach ($machine in $machines) {
            $current++
            Write-LicenseLog "--- [$current/$($machines.Count)] $($machine.machine) ---" "INFO"
            
            $result = New-LicenseForMachine -Machine $machine -KID $KID -ExpirationDate $ExpirationDate -OutputDir $OutputDir
            $results += $result
            
            # Pause entre émissions
            Start-Sleep -Milliseconds 500
        }
        
        # Export audit
        Export-AuditTrail -Results $results -AuditFile $AuditFile
        
        # Vérification finale
        Invoke-LicenseVerification -OutputDir $OutputDir
        
        # Résumé
        Show-IssuanceSummary -Results $results
        
        Write-LicenseLog "🎉 Émission Ring 0 terminée!" "SUCCESS"
        
    }
    catch {
        Write-LicenseLog "❌ Erreur critique: $_" "ERROR"
        exit 1
    }
}

# Exécution
Main