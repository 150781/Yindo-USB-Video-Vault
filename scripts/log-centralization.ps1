# Centralisation des logs USB Video Vault vers stack externe
# Support ELK/Seq/Grafana avec formatage structuré

param(
    [string]$LogSource = "$env:APPDATA\USB Video Vault\logs\main.log",
    [string]$OutputFormat = "json",  # json, syslog, grafana
    [string]$ExportDir = "logs-export",
    [string]$ElkEndpoint = "",       # http://elk-server:9200
    [string]$SeqEndpoint = "",       # http://seq-server:5341
    [string]$GrafanaEndpoint = "",   # http://grafana:3000/api/ds/query
    [int]$BatchSize = 100,
    [switch]$RealTime,
    [switch]$Verbose
)

# === CONFIGURATION SHIPPING ===

$CriticalEvents = @(
    'licence invalide',
    'signature invalide', 
    'anti-rollback',
    'crash',
    'fatal',
    'exception',
    'unhandled',
    'memory',
    'startup failed'
)

$LogFields = @{
    timestamp = ""
    level = ""
    component = ""
    message = ""
    event_type = ""
    license_id = ""
    process_id = ""
    memory_mb = 0
    error_code = ""
    stack_trace = ""
    machine_id = ""
    app_version = ""
}

# === FONCTIONS PARSING ===

function Write-Log {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
        switch($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "Cyan" }
        }
    )
}

function Parse-LogLine {
    param($LogLine)
    
    # Créer objet log structuré
    $logEntry = $LogFields.Clone()
    
    try {
        # Extraire timestamp (pattern courant: [YYYY-MM-DD HH:mm:ss])
        if ($LogLine -match '\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') {
            $logEntry.timestamp = $matches[1]
        } else {
            $logEntry.timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        # Extraire niveau de log ([INFO], [ERROR], etc.)
        if ($LogLine -match '\[(INFO|ERROR|WARN|DEBUG|SUCCESS|STEP)\]') {
            $logEntry.level = $matches[1]
        }
        
        # Déterminer le composant (CRL, License, Main, etc.)
        $logEntry.component = switch -regex ($LogLine) {
            'CRL:|crlManager' { 'CRL' }
            'License:|licence' { 'License' }
            'IPC:|ipc' { 'IPC' }
            'Vault:|vault' { 'Vault' }
            'Main:|main' { 'Main' }
            default { 'Unknown' }
        }
        
        # Déterminer le type d'événement
        $logEntry.event_type = "info"
        foreach ($criticalEvent in $CriticalEvents) {
            if ($LogLine -match $criticalEvent) {
                $logEntry.event_type = "critical"
                break
            }
        }
        
        # Extraire license ID si présent
        if ($LogLine -match 'license.*?([A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12})') {
            $logEntry.license_id = $matches[1]
        }
        
        # Extraire PID si présent
        if ($LogLine -match 'PID[:\s](\d+)') {
            $logEntry.process_id = $matches[1]
        }
        
        # Extraire utilisation mémoire
        if ($LogLine -match '(\d+(?:\.\d+)?)\s*MB') {
            $logEntry.memory_mb = [double]$matches[1]
        }
        
        # Extraire code d'erreur
        if ($LogLine -match 'error[:\s](\w+)' -or $LogLine -match 'code[:\s](\d+)') {
            $logEntry.error_code = $matches[1]
        }
        
        # Message principal (nettoyé)
        $logEntry.message = $LogLine -replace '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]', '' `
                                     -replace '\[(INFO|ERROR|WARN|DEBUG|SUCCESS|STEP)\]', '' `
                                     -replace '^\s+', ''
        
        # Métadonnées système
        $logEntry.machine_id = $env:COMPUTERNAME
        $logEntry.app_version = "v1.0.4"
        
        return $logEntry
        
    } catch {
        Write-Log "Erreur parsing ligne: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Export-ToFormat {
    param($LogEntries, $Format, $OutputPath)
    
    switch ($Format) {
        "json" {
            $LogEntries | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
        }
        
        "syslog" {
            $syslogLines = $LogEntries | ForEach-Object {
                $priority = switch ($_.level) {
                    "ERROR" { "3" }   # Error
                    "WARN" { "4" }    # Warning  
                    "INFO" { "6" }    # Info
                    default { "7" }   # Debug
                }
                
                $timestamp = Get-Date $_.timestamp -Format "MMM dd HH:mm:ss"
                "<$priority>$timestamp $($_.machine_id) usbvideovault: [$($_.component)] $($_.message)"
            }
            $syslogLines | Out-File -FilePath $OutputPath -Encoding UTF8
        }
        
        "grafana" {
            $grafanaLogs = $LogEntries | ForEach-Object {
                @{
                    timestamp = [int64]((Get-Date $_.timestamp).Subtract((Get-Date "1970-01-01")).TotalMilliseconds * 1000000)
                    line = "$($_.component): $($_.message)"
                    labels = @{
                        level = $_.level
                        component = $_.component
                        event_type = $_.event_type
                        machine = $_.machine_id
                        app = "usb-video-vault"
                        version = $_.app_version
                    }
                }
            }
            
            $payload = @{
                streams = @(@{
                    stream = @{ app = "usb-video-vault" }
                    values = $grafanaLogs | ForEach-Object { @($_.timestamp.ToString(), $_.line) }
                })
            }
            
            $payload | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutputPath -Encoding UTF8
        }
    }
    
    Write-Log "Logs exportés vers $OutputPath (format: $Format)" "SUCCESS"
}

function Ship-ToElk {
    param($LogEntries, $Endpoint)
    
    try {
        foreach ($batch in ($LogEntries | ForEach-Object { $i = [math]::Floor(($LogEntries.IndexOf($_)) / $BatchSize); $_ } | Group-Object { [math]::Floor($_.Index / $BatchSize) })) {
            $bulkData = ""
            
            foreach ($entry in $batch.Group) {
                $indexLine = @{ index = @{ _index = "usb-video-vault-$(Get-Date -Format 'yyyy.MM.dd')" } } | ConvertTo-Json -Compress
                $docLine = $entry | ConvertTo-Json -Compress
                $bulkData += "$indexLine`n$docLine`n"
            }
            
            $response = Invoke-RestMethod -Uri "$Endpoint/_bulk" -Method Post -Body $bulkData -ContentType "application/json"
            
            if ($response.errors) {
                Write-Log "Erreurs ELK lors de l'envoi du batch" "WARN"
            } else {
                Write-Log "Batch envoyé vers ELK: $($batch.Group.Count) entrées" "SUCCESS"
            }
        }
    } catch {
        Write-Log "Erreur envoi ELK: $($_.Exception.Message)" "ERROR"
    }
}

function Ship-ToSeq {
    param($LogEntries, $Endpoint)
    
    try {
        foreach ($batch in ($LogEntries | ForEach-Object { $i = [math]::Floor(($LogEntries.IndexOf($_)) / $BatchSize); $_ } | Group-Object { [math]::Floor($_.Index / $BatchSize) })) {
            $seqEvents = $batch.Group | ForEach-Object {
                @{
                    Timestamp = $_.timestamp
                    Level = $_.level
                    MessageTemplate = $_.message
                    Properties = @{
                        Component = $_.component
                        EventType = $_.event_type
                        LicenseId = $_.license_id
                        ProcessId = $_.process_id
                        MemoryMB = $_.memory_mb
                        ErrorCode = $_.error_code
                        MachineId = $_.machine_id
                        AppVersion = $_.app_version
                    }
                }
            }
            
            $payload = @{ Events = $seqEvents } | ConvertTo-Json -Depth 4
            
            $response = Invoke-RestMethod -Uri "$Endpoint/api/events/raw" -Method Post -Body $payload -ContentType "application/json"
            Write-Log "Batch envoyé vers Seq: $($batch.Group.Count) entrées" "SUCCESS"
        }
    } catch {
        Write-Log "Erreur envoi Seq: $($_.Exception.Message)" "ERROR"
    }
}

function Start-RealTimeShipping {
    param($LogPath, $Endpoints)
    
    Write-Log "Démarrage monitoring temps réel: $LogPath" "INFO"
    
    $lastPosition = if (Test-Path $LogPath) { (Get-Item $LogPath).Length } else { 0 }
    
    while ($true) {
        try {
            if (Test-Path $LogPath) {
                $currentSize = (Get-Item $LogPath).Length
                
                if ($currentSize -gt $lastPosition) {
                    # Nouvelles données disponibles
                    $newData = Get-Content $LogPath -Encoding UTF8 -ReadCount 0 | Select-Object -Skip ([Math]::Max(0, $lastPosition / 100))
                    
                    if ($newData) {
                        $parsedEntries = $newData | ForEach-Object { Parse-LogLine $_ } | Where-Object { $_ -ne $null }
                        
                        if ($parsedEntries) {
                            Write-Log "Nouvelles entrées détectées: $($parsedEntries.Count)" "INFO"
                            
                            # Expédier vers les endpoints configurés
                            if ($Endpoints.Elk) { Ship-ToElk -LogEntries $parsedEntries -Endpoint $Endpoints.Elk }
                            if ($Endpoints.Seq) { Ship-ToSeq -LogEntries $parsedEntries -Endpoint $Endpoints.Seq }
                        }
                    }
                    
                    $lastPosition = $currentSize
                }
            }
            
            Start-Sleep -Seconds 5  # Vérification toutes les 5 secondes
            
        } catch {
            Write-Log "Erreur monitoring temps réel: $($_.Exception.Message)" "ERROR"
            Start-Sleep -Seconds 30  # Attendre plus longtemps en cas d'erreur
        }
    }
}

# === EXECUTION PRINCIPALE ===

try {
    Write-Log "=== CENTRALISATION LOGS USB VIDEO VAULT ===" "INFO"
    
    # Créer répertoire d'export
    if (!(Test-Path $ExportDir)) {
        New-Item -ItemType Directory -Path $ExportDir -Force | Out-Null
    }
    
    # Configurer endpoints
    $endpoints = @{}
    if ($ElkEndpoint) { $endpoints.Elk = $ElkEndpoint }
    if ($SeqEndpoint) { $endpoints.Seq = $SeqEndpoint }
    
    if ($RealTime) {
        # Mode temps réel
        Start-RealTimeShipping -LogPath $LogSource -Endpoints $endpoints
    } else {
        # Mode batch
        if (Test-Path $LogSource) {
            Write-Log "Traitement fichier: $LogSource" "INFO"
            
            $logLines = Get-Content $LogSource -Encoding UTF8
            $parsedEntries = $logLines | ForEach-Object { Parse-LogLine $_ } | Where-Object { $_ -ne $null }
            
            Write-Log "Entrées parsées: $($parsedEntries.Count)" "INFO"
            
            # Export local
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $outputPath = Join-Path $ExportDir "logs-$timestamp.$OutputFormat"
            Export-ToFormat -LogEntries $parsedEntries -Format $OutputFormat -OutputPath $outputPath
            
            # Expédition vers endpoints externes
            if ($endpoints.Elk) { Ship-ToElk -LogEntries $parsedEntries -Endpoint $endpoints.Elk }
            if ($endpoints.Seq) { Ship-ToSeq -LogEntries $parsedEntries -Endpoint $endpoints.Seq }
            
        } else {
            Write-Log "Fichier log non trouvé: $LogSource" "ERROR"
        }
    }
    
    Write-Log "Centralisation logs terminée" "SUCCESS"
    
} catch {
    Write-Log "Erreur centralisation: $($_.Exception.Message)" "ERROR"
    exit 1
}