# Script de Monitoring Ring 0
# USB Video Vault - Surveillance temps réel des machines Ring 0

param(
    [Parameter(Mandatory=$false)]
    [string]$MachineListFile = "ring0-machines.txt",
    
    [Parameter(Mandatory=$false)]
    [string]$LogPattern = "*USB*Video*Vault*",
    
    [Parameter(Mandatory=$false)]
    [int]$CheckIntervalSeconds = 30,
    
    [Parameter(Mandatory=$false)]
    [string]$AlertWebhook,
    
    [Parameter(Mandatory=$false)]
    [switch]$LocalOnly = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$ContinuousMode = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Continue"

# Configuration des patterns d'erreur
$CriticalPatterns = @(
    "Signature de licence invalide",
    "Licence expirée",
    "Horloge incohérente", 
    "Anti-rollback",
    "Erreur validation",
    "Signature invalide",
    "License validation failed",
    "CRL check failed",
    "Fingerprint mismatch"
)

$WarningPatterns = @(
    "License expires in",
    "Performance warning",
    "Memory usage high",
    "Startup slow",
    "Connection timeout"
)

function Write-MonitorLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "CRITICAL" { "Red" }
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "ALERT" { "Magenta" }
        default { "Cyan" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-MachinesForMonitoring {
    if ($LocalOnly) {
        return @($env:COMPUTERNAME)
    }
    
    if (Test-Path $MachineListFile) {
        $machines = Get-Content -Path $MachineListFile | Where-Object { $_ -and $_.Trim() -and -not $_.StartsWith('#') }
        Write-MonitorLog "Machines à surveiller: $($machines.Count)" "INFO"
        return $machines
    } else {
        Write-MonitorLog "⚠️ Liste machines non trouvée, surveillance locale uniquement" "WARN"
        return @($env:COMPUTERNAME)
    }
}

function Get-ApplicationLogs {
    param([string]$MachineName)
    
    try {
        $logPaths = @()
        
        if ($MachineName -eq $env:COMPUTERNAME) {
            # Local
            $localPaths = @(
                "$env:APPDATA\USB Video Vault\logs\main.log",
                "$env:APPDATA\USB Video Vault\logs\renderer.log",
                "$env:USERPROFILE\Documents\Yindo-USB-Video-Vault\logs\*.log"
            )
            
            foreach ($path in $localPaths) {
                $files = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                $logPaths += $files.FullName
            }
        } else {
            # Remote
            $remotePaths = @(
                "\\$MachineName\C$\Users\*\AppData\Roaming\USB Video Vault\logs\main.log",
                "\\$MachineName\C$\Users\*\AppData\Roaming\USB Video Vault\logs\renderer.log"
            )
            
            foreach ($path in $remotePaths) {
                try {
                    $files = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                    $logPaths += $files.FullName
                } catch {
                    # Accès distant échoué
                }
            }
        }
        
        return $logPaths | Where-Object { Test-Path $_ }
        
    } catch {
        Write-MonitorLog "❌ Erreur accès logs $MachineName : $_" "ERROR"
        return @()
    }
}

function Test-LogForPatterns {
    param(
        [string]$LogFile,
        [string]$MachineName,
        [DateTime]$SinceTime
    )
    
    try {
        if (-not (Test-Path $LogFile)) {
            return @()
        }
        
        # Lire nouvelles lignes depuis dernière vérification
        $content = Get-Content -Path $LogFile -ErrorAction SilentlyContinue
        if (-not $content) {
            return @()
        }
        
        $alerts = @()
        $lineNumber = 0
        
        foreach ($line in $content) {
            $lineNumber++
            
            # Chercher timestamp dans la ligne
            $lineTime = $null
            if ($line -match '(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})') {
                try {
                    $lineTime = [DateTime]::ParseExact($matches[1], "yyyy-MM-dd HH:mm:ss", $null)
                } catch {
                    # Parsing timestamp échoué, continuer
                }
            }
            
            # Ignorer lignes trop anciennes
            if ($lineTime -and $lineTime -lt $SinceTime) {
                continue
            }
            
            # Vérifier patterns critiques
            foreach ($pattern in $CriticalPatterns) {
                if ($line -match $pattern) {
                    $alerts += @{
                        Type = "CRITICAL"
                        Machine = $MachineName
                        LogFile = $LogFile
                        Line = $lineNumber
                        Pattern = $pattern
                        Content = $line.Trim()
                        Timestamp = if ($lineTime) { $lineTime } else { Get-Date }
                    }
                }
            }
            
            # Vérifier patterns warning
            foreach ($pattern in $WarningPatterns) {
                if ($line -match $pattern) {
                    $alerts += @{
                        Type = "WARNING"
                        Machine = $MachineName
                        LogFile = $LogFile
                        Line = $lineNumber
                        Pattern = $pattern
                        Content = $line.Trim()
                        Timestamp = if ($lineTime) { $lineTime } else { Get-Date }
                    }
                }
            }
        }
        
        return $alerts
        
    } catch {
        Write-MonitorLog "❌ Erreur analyse $LogFile : $_" "ERROR"
        return @()
    }
}

function Send-Alert {
    param([hashtable]$Alert)
    
    $emoji = if ($Alert.Type -eq "CRITICAL") { "🚨" } else { "⚠️" }
    $color = if ($Alert.Type -eq "CRITICAL") { "CRITICAL" } else { "WARN" }
    
    Write-MonitorLog "$emoji [$($Alert.Machine)] $($Alert.Pattern): $($Alert.Content)" $color
    
    # Webhook si configuré
    if ($AlertWebhook) {
        try {
            $payload = @{
                text = "$emoji USB Video Vault Alert - $($Alert.Machine)"
                attachments = @(
                    @{
                        color = if ($Alert.Type -eq "CRITICAL") { "danger" } else { "warning" }
                        title = "$($Alert.Type): $($Alert.Pattern)"
                        text = $Alert.Content
                        fields = @(
                            @{ title = "Machine"; value = $Alert.Machine; short = $true },
                            @{ title = "Log"; value = Split-Path $Alert.LogFile -Leaf; short = $true },
                            @{ title = "Timestamp"; value = $Alert.Timestamp.ToString("yyyy-MM-dd HH:mm:ss"); short = $true }
                        )
                    }
                )
            } | ConvertTo-Json -Depth 10
            
            Invoke-RestMethod -Uri $AlertWebhook -Method Post -Body $payload -ContentType "application/json" -ErrorAction SilentlyContinue
        } catch {
            Write-MonitorLog "⚠️ Erreur envoi webhook: $_" "WARN"
        }
    }
}

function Get-SystemHealth {
    param([string]$MachineName)
    
    try {
        if ($MachineName -eq $env:COMPUTERNAME) {
            # Local
            $processes = Get-Process | Where-Object { $_.ProcessName -like "*USB*Video*Vault*" }
            $diskSpace = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
            $memory = Get-WmiObject -Class Win32_OperatingSystem
        } else {
            # Remote
            $processes = Get-WmiObject -Class Win32_Process -ComputerName $MachineName | Where-Object { $_.Name -like "*USB*Video*Vault*" }
            $diskSpace = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $MachineName | Where-Object { $_.DriveType -eq 3 }
            $memory = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $MachineName
        }
        
        $health = @{
            Machine = $MachineName
            ProcessCount = $processes.Count
            MemoryUsageMB = if ($processes) { ($processes | Measure-Object WorkingSet64 -Sum).Sum / 1MB } else { 0 }
            FreeMemoryPercent = if ($memory) { [math]::Round(($memory.FreePhysicalMemory / $memory.TotalVisibleMemorySize) * 100, 2) } else { 0 }
            DiskFreeGB = if ($diskSpace) { [math]::Round(($diskSpace | Where-Object { $_.DeviceID -eq "C:" }).FreeSpace / 1GB, 2) } else { 0 }
            LastCheck = Get-Date
        }
        
        return $health
        
    } catch {
        Write-MonitorLog "⚠️ Erreur santé système $MachineName : $_" "WARN"
        return @{
            Machine = $MachineName
            ProcessCount = -1
            MemoryUsageMB = -1
            FreeMemoryPercent = -1
            DiskFreeGB = -1
            LastCheck = Get-Date
            Error = $_.ToString()
        }
    }
}

function Show-MonitoringSummary {
    param([array]$Machines, [array]$HealthData)
    
    Write-MonitorLog "=== ÉTAT MONITORING RING 0 ===" "INFO"
    Write-MonitorLog "Machines surveillées: $($Machines.Count)" "INFO"
    Write-MonitorLog "Interval: ${CheckIntervalSeconds}s" "INFO"
    
    if ($HealthData.Count -gt 0) {
        Write-MonitorLog "Santé système:" "INFO"
        foreach ($health in $HealthData) {
            if ($health.ProcessCount -ge 0) {
                $status = "✓"
                $level = "SUCCESS"
            } else {
                $status = "❌"
                $level = "ERROR"
            }
            
            Write-MonitorLog "  $status $($health.Machine): Proc=$($health.ProcessCount), Mem=$([math]::Round($health.MemoryUsageMB, 1))MB, FreeMem=$($health.FreeMemoryPercent)%" $level
        }
    }
}

function Start-ContinuousMonitoring {
    param([array]$Machines)
    
    Write-MonitorLog "🔍 Démarrage monitoring continu Ring 0..." "INFO"
    Write-MonitorLog "Appuyez sur Ctrl+C pour arrêter" "INFO"
    
    $lastCheckTime = (Get-Date).AddHours(-1)  # Vérifier dernière heure au démarrage
    $iteration = 0
    
    try {
        while ($true) {
            $iteration++
            $currentTime = Get-Date
            Write-MonitorLog "--- Vérification #$iteration ---" "INFO"
            
            $allAlerts = @()
            $healthData = @()
            
            foreach ($machine in $Machines) {
                Write-MonitorLog "Surveillance: $machine" "INFO"
                
                # Obtenir logs de l'application
                $logFiles = Get-ApplicationLogs -MachineName $machine
                
                if ($logFiles.Count -eq 0) {
                    Write-MonitorLog "⚠️ Aucun log trouvé pour $machine" "WARN"
                    continue
                }
                
                # Analyser chaque fichier de log
                foreach ($logFile in $logFiles) {
                    $alerts = Test-LogForPatterns -LogFile $logFile -MachineName $machine -SinceTime $lastCheckTime
                    $allAlerts += $alerts
                }
                
                # Santé système
                $health = Get-SystemHealth -MachineName $machine
                $healthData += $health
                
                # Pause entre machines
                Start-Sleep -Milliseconds 500
            }
            
            # Traiter alertes
            foreach ($alert in $allAlerts) {
                Send-Alert -Alert $alert
            }
            
            # Résumé si verbose
            if ($Verbose -or ($iteration % 10 -eq 0)) {
                Show-MonitoringSummary -Machines $Machines -HealthData $healthData
            }
            
            # Mémoriser temps de vérification
            $lastCheckTime = $currentTime
            
            # Attendre prochain cycle
            Write-MonitorLog "Pause $CheckIntervalSeconds secondes..." "INFO"
            Start-Sleep -Seconds $CheckIntervalSeconds
        }
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        Write-MonitorLog "Monitoring arrêté par l'utilisateur" "INFO"
    }
    catch {
        Write-MonitorLog "❌ Erreur monitoring: $_" "ERROR"
        throw
    }
}

function Invoke-OneTimeCheck {
    param([array]$Machines)
    
    Write-MonitorLog "🔍 Vérification unique Ring 0..." "INFO"
    
    $allAlerts = @()
    $healthData = @()
    $checkTime = (Get-Date).AddMinutes(-10)  # Dernières 10 minutes
    
    foreach ($machine in $Machines) {
        Write-MonitorLog "Vérification: $machine" "INFO"
        
        # Logs
        $logFiles = Get-ApplicationLogs -MachineName $machine
        
        foreach ($logFile in $logFiles) {
            $alerts = Test-LogForPatterns -LogFile $logFile -MachineName $machine -SinceTime $checkTime
            $allAlerts += $alerts
        }
        
        # Santé
        $health = Get-SystemHealth -MachineName $machine
        $healthData += $health
    }
    
    # Rapporter résultats
    if ($allAlerts.Count -gt 0) {
        Write-MonitorLog "🚨 $($allAlerts.Count) alerte(s) trouvée(s):" "ALERT"
        foreach ($alert in $allAlerts) {
            Send-Alert -Alert $alert
        }
    } else {
        Write-MonitorLog "✅ Aucune alerte détectée" "SUCCESS"
    }
    
    Show-MonitoringSummary -Machines $Machines -HealthData $healthData
}

# Fonction principale
function Main {
    Write-MonitorLog "=== Monitoring Ring 0 - USB Video Vault ===" "INFO"
    
    try {
        # Obtenir machines à surveiller
        $machines = Get-MachinesForMonitoring
        
        if ($machines.Count -eq 0) {
            Write-MonitorLog "❌ Aucune machine à surveiller" "ERROR"
            exit 1
        }
        
        Write-MonitorLog "Configuration:" "INFO"
        Write-MonitorLog "  Machines: $($machines.Count)" "INFO"
        Write-MonitorLog "  Mode: $(if ($ContinuousMode) { 'Continu' } else { 'Unique' })" "INFO"
        Write-MonitorLog "  Patterns critiques: $($CriticalPatterns.Count)" "INFO"
        Write-MonitorLog "  Webhook: $(if ($AlertWebhook) { 'Configuré' } else { 'Non' })" "INFO"
        
        if ($ContinuousMode) {
            Start-ContinuousMonitoring -Machines $machines
        } else {
            Invoke-OneTimeCheck -Machines $machines
        }
        
        Write-MonitorLog "🎉 Monitoring terminé" "SUCCESS"
        
    } catch {
        Write-MonitorLog "❌ Erreur critique monitoring: $_" "ERROR"
        exit 1
    }
}

# Gestion Ctrl+C
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Write-MonitorLog "Arrêt monitoring..." "INFO"
}

# Exécution
Main