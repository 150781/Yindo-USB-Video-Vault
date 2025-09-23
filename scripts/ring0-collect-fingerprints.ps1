# Script de Collecte d'Empreintes Ring 0
# USB Video Vault - Collecte automatisée pour 10 machines internes

param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "ring0-fingerprints.csv",
    
    [Parameter(Mandatory=$false)]
    [string]$MachineListFile = "ring0-machines.txt",
    
    [Parameter(Mandatory=$false)]
    [switch]$LocalOnly = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportFormat = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Continue"

function Write-CollectLog {
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

function Get-LocalFingerprint {
    Write-CollectLog "Collecte empreinte machine locale..." "STEP"
    
    try {
        # Utiliser le script existant
        $scriptPath = "scripts\print-bindings.mjs"
        
        if (-not (Test-Path $scriptPath)) {
            Write-CollectLog "❌ Script print-bindings.mjs non trouvé" "ERROR"
            return $null
        }
        
        # Exécuter le script et capturer la sortie
        $output = node $scriptPath --json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-CollectLog "❌ Erreur exécution print-bindings.mjs: $output" "ERROR"
            return $null
        }
        
        # Parser la sortie JSON
        try {
            $data = $output | ConvertFrom-Json
            
            $result = @{
                Machine = $env:COMPUTERNAME
                Fingerprint = $data.machineFingerprint
                UsbSerial = $null
                Hostname = $data.systemInfo.hostname
                Platform = $data.systemInfo.platform
                TotalMemory = $data.systemInfo.totalMemory
                CpuCount = $data.systemInfo.cpuCount
                CollectedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            
            # Chercher le premier USB avec serial
            if ($data.usbDevices -and $data.usbDevices.Count -gt 0) {
                $firstUsb = $data.usbDevices | Where-Object { $_.serial -and $_.serial -ne "NULL" } | Select-Object -First 1
                if ($firstUsb) {
                    $result.UsbSerial = $firstUsb.serial
                }
            }
            
            Write-CollectLog "✓ Empreinte collectée: $($result.Fingerprint)" "SUCCESS"
            if ($result.UsbSerial) {
                Write-CollectLog "✓ USB détecté: $($result.UsbSerial)" "SUCCESS"
            } else {
                Write-CollectLog "⚠️ Aucun USB avec serial détecté" "WARN"
            }
            
            return $result
            
        }
        catch {
            Write-CollectLog "❌ Erreur parsing JSON: $_" "ERROR"
            Write-CollectLog "Sortie brute: $output" "INFO"
            return $null
        }
        
    }
    catch {
        Write-CollectLog "❌ Erreur collecte locale: $_" "ERROR"
        return $null
    }
}

function Get-RemoteFingerprint {
    param([string]$MachineName)
    
    Write-CollectLog "Collecte empreinte machine distante: $MachineName" "INFO"
    
    try {
        # Vérifier connectivité
        if (-not (Test-Connection -ComputerName $MachineName -Count 1 -Quiet)) {
            Write-CollectLog "❌ Machine non accessible: $MachineName" "ERROR"
            return $null
        }
        
        # Copier le script sur la machine distante
        $remotePath = "\\$MachineName\C$\temp\usb-vault-collect"
        $remoteScript = "$remotePath\print-bindings.mjs"
        
        try {
            if (-not (Test-Path $remotePath)) {
                New-Item -ItemType Directory -Path $remotePath -Force | Out-Null
            }
            
            Copy-Item -Path "scripts\print-bindings.mjs" -Destination $remoteScript -Force
            Write-CollectLog "Script copié sur $MachineName" "INFO"
        }
        catch {
            Write-CollectLog "❌ Impossible de copier script sur $MachineName : $_" "ERROR"
            return $null
        }
        
        # Exécuter à distance
        try {
            $scriptBlock = {
                param($RemoteScriptPath)
                cd C:\temp\usb-vault-collect
                node print-bindings.mjs --json
            }
            
            $session = New-PSSession -ComputerName $MachineName -ErrorAction Stop
            $output = Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $remoteScript
            Remove-PSSession $session
            
            # Parser résultat
            $data = $output | ConvertFrom-Json
            
            $result = @{
                Machine = $MachineName
                Fingerprint = $data.machineFingerprint
                UsbSerial = $null
                Hostname = $data.systemInfo.hostname
                Platform = $data.systemInfo.platform
                TotalMemory = $data.systemInfo.totalMemory
                CpuCount = $data.systemInfo.cpuCount
                CollectedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            
            # USB
            if ($data.usbDevices -and $data.usbDevices.Count -gt 0) {
                $firstUsb = $data.usbDevices | Where-Object { $_.serial -and $_.serial -ne "NULL" } | Select-Object -First 1
                if ($firstUsb) {
                    $result.UsbSerial = $firstUsb.serial
                }
            }
            
            Write-CollectLog "✓ $MachineName : $($result.Fingerprint)" "SUCCESS"
            
            # Nettoyage
            try {
                Remove-Item -Path $remotePath -Recurse -Force
            } catch {
                Write-CollectLog "⚠️ Nettoyage incomplet sur $MachineName" "WARN"
            }
            
            return $result
            
        }
        catch {
            Write-CollectLog "❌ Erreur exécution distante sur $MachineName : $_" "ERROR"
            return $null
        }
        
    }
    catch {
        Write-CollectLog "❌ Erreur collecte $MachineName : $_" "ERROR"
        return $null
    }
}

function Get-MachineList {
    param([string]$ListFile)
    
    if ($LocalOnly) {
        return @($env:COMPUTERNAME)
    }
    
    if (Test-Path $ListFile) {
        Write-CollectLog "Lecture liste machines: $ListFile" "INFO"
        $machines = Get-Content -Path $ListFile | Where-Object { $_ -and $_.Trim() -and -not $_.StartsWith('#') }
        Write-CollectLog "Machines trouvées: $($machines.Count)" "INFO"
        return $machines
    } else {
        Write-CollectLog "⚠️ Fichier liste non trouvé: $ListFile" "WARN"
        Write-CollectLog "Utilisation machine locale uniquement" "INFO"
        return @($env:COMPUTERNAME)
    }
}

function Export-FingerprintsCSV {
    param([array]$Results, [string]$OutputPath)
    
    Write-CollectLog "Export CSV: $OutputPath" "STEP"
    
    try {
        # En-têtes CSV
        $csv = @("machine,fingerprint,usbSerial,hostname,platform,totalMemory,cpuCount,collectedAt")
        
        foreach ($result in $Results) {
            if ($result) {
                $usbSerial = if ($result.UsbSerial) { $result.UsbSerial } else { "" }
                $line = "$($result.Machine),$($result.Fingerprint),$usbSerial,$($result.Hostname),$($result.Platform),$($result.TotalMemory),$($result.CpuCount),$($result.CollectedAt)"
                $csv += $line
            }
        }
        
        $csv | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-CollectLog "✓ CSV exporté: $OutputPath" "SUCCESS"
        Write-CollectLog "Lignes: $($csv.Count - 1)" "INFO"
        
    }
    catch {
        Write-CollectLog "❌ Erreur export CSV: $_" "ERROR"
    }
}

function Export-ForLicenseGeneration {
    param([array]$Results)
    
    Write-CollectLog "Export format émission de licences..." "STEP"
    
    try {
        $licenseFormat = "ring0-for-licenses.csv"
        
        # Format simplifié pour make-license.mjs
        $csv = @("machine,fingerprint,usbSerial")
        
        foreach ($result in $Results) {
            if ($result) {
                $usbSerial = if ($result.UsbSerial) { $result.UsbSerial } else { "" }
                $line = "$($result.Machine),$($result.Fingerprint),$usbSerial"
                $csv += $line
            }
        }
        
        $csv | Out-File -FilePath $licenseFormat -Encoding UTF8
        Write-CollectLog "✓ Format licences exporté: $licenseFormat" "SUCCESS"
        
        # Générer script PowerShell pour émission en lot
        $batchScript = @"
# Script généré automatiquement pour émission Ring 0
# USB Video Vault - Émission en lot

Import-Csv .\ring0-for-licenses.csv | ForEach-Object {
    `$machine = `$_.machine
    `$fingerprint = `$_.fingerprint
    `$usbSerial = if([string]::IsNullOrWhiteSpace(`$_.usbSerial)) { `$null } else { `$_.usbSerial }
    
    Write-Host "Émission licence pour: `$machine (`$fingerprint)" -ForegroundColor Cyan
    
    # Émission
    if (`$usbSerial) {
        node scripts\make-license.mjs `$fingerprint `$usbSerial --kid 1 --exp "2026-12-31T23:59:59Z"
    } else {
        node scripts\make-license.mjs `$fingerprint --kid 1 --exp "2026-12-31T23:59:59Z"
    }
    
    # Vérification
    node scripts\verify-license.mjs .\out\license.bin
    
    # Sauvegarde nommée
    Copy-Item .\out\license.bin ".\deliveries\`$machine-license.bin" -Force
    Write-Host "✓ Licence sauvegardée: deliveries\`$machine-license.bin" -ForegroundColor Green
    
    Start-Sleep -Seconds 1
}

Write-Host "Émission Ring 0 terminée!" -ForegroundColor Green
"@
        
        $batchScript | Out-File -FilePath "ring0-batch-license.ps1" -Encoding UTF8
        Write-CollectLog "✓ Script d'émission généré: ring0-batch-license.ps1" "SUCCESS"
        
    }
    catch {
        Write-CollectLog "❌ Erreur export format licences: $_" "ERROR"
    }
}

function Show-CollectionSummary {
    param([array]$Results)
    
    Write-CollectLog "=== RÉSUMÉ COLLECTE RING 0 ===" "STEP"
    
    $successful = $Results | Where-Object { $_ -ne $null }
    $withUsb = $successful | Where-Object { $_.UsbSerial }
    $withoutUsb = $successful | Where-Object { -not $_.UsbSerial }
    
    Write-CollectLog "Machines collectées: $($successful.Count)" "INFO"
    Write-CollectLog "Avec USB: $($withUsb.Count)" "INFO"
    Write-CollectLog "Sans USB: $($withoutUsb.Count)" "INFO"
    
    if ($Verbose -and $successful.Count -gt 0) {
        Write-CollectLog "Détails:" "INFO"
        foreach ($result in $successful) {
            $usbInfo = if ($result.UsbSerial) { " (USB: $($result.UsbSerial))" } else { " (Pas d'USB)" }
            Write-CollectLog "  $($result.Machine): $($result.Fingerprint)$usbInfo" "INFO"
        }
    }
    
    Write-CollectLog "Prochaines étapes:" "INFO"
    Write-CollectLog "1. Vérifier ring0-for-licenses.csv" "INFO"
    Write-CollectLog "2. Exécuter: .\ring0-batch-license.ps1" "INFO"
    Write-CollectLog "3. Déployer licences dans deliveries\" "INFO"
}

# Fonction principale
function Main {
    Write-CollectLog "=== Collecte d'Empreintes Ring 0 - USB Video Vault ===" "STEP"
    
    try {
        # Obtenir liste des machines
        $machines = Get-MachineList -ListFile $MachineListFile
        
        if ($machines.Count -eq 0) {
            Write-CollectLog "❌ Aucune machine à traiter" "ERROR"
            exit 1
        }
        
        Write-CollectLog "Machines à traiter: $($machines.Count)" "INFO"
        
        # Créer répertoire deliveries si nécessaire
        if (-not (Test-Path "deliveries")) {
            New-Item -ItemType Directory -Path "deliveries" -Force | Out-Null
            Write-CollectLog "Répertoire deliveries créé" "INFO"
        }
        
        # Collecter les empreintes
        $results = @()
        
        foreach ($machine in $machines) {
            Write-CollectLog "--- Traitement: $machine ---" "INFO"
            
            if ($machine -eq $env:COMPUTERNAME -or $LocalOnly) {
                $result = Get-LocalFingerprint
            } else {
                $result = Get-RemoteFingerprint -MachineName $machine
            }
            
            $results += $result
        }
        
        # Exporter résultats
        Export-FingerprintsCSV -Results $results -OutputPath $OutputPath
        
        if ($ExportFormat) {
            Export-ForLicenseGeneration -Results $results
        }
        
        # Résumé
        Show-CollectionSummary -Results $results
        
        Write-CollectLog "🎉 Collecte Ring 0 terminée!" "SUCCESS"
        
    }
    catch {
        Write-CollectLog "❌ Erreur critique: $_" "ERROR"
        exit 1
    }
}

# Exécution
Main