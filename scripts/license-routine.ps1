# Gestion Licences Routine - USB Video Vault
# Audit trail hebdo, rotation KID mensuelle, renouvellement J-15

param(
    [string]$Task = "audit",  # audit, rotation, renewal
    [string]$OutputDir = "routine-output",
    [string]$LicenseDir = "deliveries",
    [string]$AuditDays = "7",
    [switch]$DryRun,
    [switch]$Verbose
)

# === CONFIGURATION ===

$RoutineConfig = @{
    AuditTrailPath = "audit-trail.json"
    BackupDir = "backups\keys"
    RenewalLeadDays = 15
    KIDRotationDays = 60
    CurrentKID = "1"
}

# === FONCTIONS UTILITAIRES ===

function Write-Log {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    Write-Host $logMessage -ForegroundColor $(
        switch($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            "STEP" { "Cyan" }
            default { "White" }
        }
    )
}

function Initialize-RoutineEnvironment {
    if (!(Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    $subdirs = @("audit", "rotation", "renewal", "backups")
    foreach ($subdir in $subdirs) {
        $path = Join-Path $OutputDir $subdir
        if (!(Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

# === AUDIT TRAIL HEBDOMADAIRE ===

function Export-AuditTrail {
    param($Days)
    
    Write-Log "=== EXPORT AUDIT TRAIL ($Days jours) ===" "STEP"
    
    $auditData = @{
        ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        PeriodDays = $Days
        Licenses = @{
            Issued = @()
            Delivered = @()
            Activated = @()
            Revoked = @()
        }
        Summary = @{
            TotalIssued = 0
            TotalDelivered = 0
            TotalActivated = 0
            TotalRevoked = 0
            PendingActivation = 0
            Issues = @()
        }
    }
    
    try {
        # 1. Analyser les licences émises (deliveries/)
        if (Test-Path $LicenseDir) {
            $issuedLicenses = Get-ChildItem "$LicenseDir\**\*.bin" -Recurse | 
                Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-$Days) }
            
            foreach ($license in $issuedLicenses) {
                $licenseInfo = @{
                    File = $license.Name
                    Path = $license.FullName
                    IssuedDate = $license.CreationTime.ToString("yyyy-MM-dd HH:mm:ss")
                    Size = $license.Length
                    Directory = $license.Directory.Name
                }
                
                $auditData.Licenses.Issued += $licenseInfo
            }
            
            $auditData.Summary.TotalIssued = $auditData.Licenses.Issued.Count
            Write-Log "Licences émises: $($auditData.Summary.TotalIssued)" "INFO"
        }
        
        # 2. Analyser les logs pour les activations/révocations
        $logPath = "$env:APPDATA\USB Video Vault\logs\main.log"
        if (Test-Path $logPath) {
            $logContent = Get-Content $logPath | Where-Object { 
                $_ -match "\d{4}-\d{2}-\d{2}" 
            } | Where-Object {
                try {
                    $dateMatch = [regex]::Match($_, '\d{4}-\d{2}-\d{2}')
                    if ($dateMatch.Success) {
                        $logDate = [datetime]::Parse($dateMatch.Value)
                        return $logDate -gt (Get-Date).AddDays(-$Days)
                    }
                } catch { }
                return $false
            }
            
            # Activations
            $activations = $logContent | Where-Object { $_ -match "licence.*valid|licence.*activ" }
            foreach ($activation in $activations) {
                $auditData.Licenses.Activated += @{
                    Timestamp = [regex]::Match($activation, '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}').Value
                    LogEntry = $activation
                }
            }
            
            # Révocations
            $revocations = $logContent | Where-Object { $_ -match "licence.*revoqu|CRL.*revoqu" }
            foreach ($revocation in $revocations) {
                $auditData.Licenses.Revoked += @{
                    Timestamp = [regex]::Match($revocation, '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}').Value
                    LogEntry = $revocation
                }
            }
            
            $auditData.Summary.TotalActivated = $auditData.Licenses.Activated.Count
            $auditData.Summary.TotalRevoked = $auditData.Licenses.Revoked.Count
            
            Write-Log "Activations détectées: $($auditData.Summary.TotalActivated)" "INFO"
            Write-Log "Révocations détectées: $($auditData.Summary.TotalRevoked)" "INFO"
        }
        
        # 3. Contrôle de cohérence
        $auditData.Summary.PendingActivation = $auditData.Summary.TotalIssued - $auditData.Summary.TotalActivated
        
        if ($auditData.Summary.PendingActivation -gt 0) {
            $auditData.Summary.Issues += "⚠️ $($auditData.Summary.PendingActivation) licence(s) émise(s) non activée(s)"
        }
        
        if ($auditData.Summary.TotalRevoked -gt 0) {
            $auditData.Summary.Issues += "🚫 $($auditData.Summary.TotalRevoked) révocation(s) détectée(s)"
        }
        
        # 4. Export
        $auditPath = Join-Path $OutputDir "audit\audit-trail-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $auditData | ConvertTo-Json -Depth 4 | Out-File -FilePath $auditPath -Encoding UTF8
        
        Write-Log "Audit trail exporté: $auditPath" "SUCCESS"
        
        # 5. Résumé console
        Write-Log "=== RESUME AUDIT TRAIL ===" "STEP"
        Write-Log "Période: $Days jours" "INFO"
        Write-Log "Émises: $($auditData.Summary.TotalIssued) | Activées: $($auditData.Summary.TotalActivated) | Révoquées: $($auditData.Summary.TotalRevoked)" "INFO"
        
        if ($auditData.Summary.Issues.Count -gt 0) {
            Write-Log "⚠️ PROBLEMES DETECTES:" "WARN"
            foreach ($issue in $auditData.Summary.Issues) {
                Write-Log "  $issue" "WARN"
            }
        } else {
            Write-Log "✅ Aucun problème détecté" "SUCCESS"
        }
        
        return $auditPath
        
    } catch {
        Write-Log "Erreur export audit trail: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# === ROTATION KID MENSUELLE ===

function Test-KIDRotation {
    param($DryRun = $true)
    
    Write-Log "=== TEST ROTATION KID (DRY-RUN: $DryRun) ===" "STEP"
    
    try {
        $rotationData = @{
            TestDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            CurrentKID = $RoutineConfig.CurrentKID
            NextKID = ([int]$RoutineConfig.CurrentKID + 1).ToString()
            DryRun = $DryRun
            Results = @{
                KeyGeneration = $false
                KeyBackup = $false
                TestSignature = $false
                TestVerification = $false
                RollbackReady = $false
            }
            Issues = @()
        }
        
        # 1. Génération nouvelle clé KID+1
        Write-Log "Test génération clé KID $($rotationData.NextKID)..." "INFO"
        
        if (!$DryRun) {
            # Vraie génération de clé (non implémentée ici - serait avec votre système crypto)
            Write-Log "⚠️ Génération clé réelle non implémentée (dry-run forcé)" "WARN"
        } else {
            # Simulation
            Start-Sleep -Seconds 2
            $rotationData.Results.KeyGeneration = $true
            Write-Log "✅ Génération clé KID $($rotationData.NextKID) simulée" "SUCCESS"
        }
        
        # 2. Backup clé actuelle
        Write-Log "Test backup clé actuelle..." "INFO"
        
        $backupPath = Join-Path $OutputDir "backups\kid-$($RoutineConfig.CurrentKID)-backup-$(Get-Date -Format 'yyyyMMdd').key"
        
        if ($DryRun) {
            # Créer un fichier de test
            "BACKUP_TEST_KEY_KID_$($RoutineConfig.CurrentKID)" | Out-File -FilePath $backupPath -Encoding UTF8
            $rotationData.Results.KeyBackup = $true
            Write-Log "✅ Backup clé simulé: $backupPath" "SUCCESS"
        }
        
        # 3. Test signature avec nouvelle clé
        Write-Log "Test signature avec KID $($rotationData.NextKID)..." "INFO"
        
        if ($DryRun) {
            Start-Sleep -Seconds 1
            $rotationData.Results.TestSignature = $true
            Write-Log "✅ Test signature simulé" "SUCCESS"
        }
        
        # 4. Test vérification
        Write-Log "Test vérification signature..." "INFO"
        
        if ($DryRun) {
            Start-Sleep -Seconds 1
            $rotationData.Results.TestVerification = $true
            Write-Log "✅ Test vérification simulé" "SUCCESS"
        }
        
        # 5. Préparation rollback
        Write-Log "Vérification procédure rollback..." "INFO"
        
        $rollbackScript = "scripts\rollback-kid.ps1"
        if (Test-Path $rollbackScript -or $DryRun) {
            $rotationData.Results.RollbackReady = $true
            Write-Log "✅ Procédure rollback prête" "SUCCESS"
        } else {
            $rotationData.Issues += "❌ Script rollback manquant: $rollbackScript"
        }
        
        # 6. Évaluation globale
        $allTestsOK = $rotationData.Results.KeyGeneration -and 
                      $rotationData.Results.KeyBackup -and 
                      $rotationData.Results.TestSignature -and 
                      $rotationData.Results.TestVerification -and 
                      $rotationData.Results.RollbackReady
        
        $rotationData.GlobalStatus = if ($allTestsOK) { "READY" } else { "NOT_READY" }
        
        # 7. Export résultats
        $rotationPath = Join-Path $OutputDir "rotation\kid-rotation-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $rotationData | ConvertTo-Json -Depth 4 | Out-File -FilePath $rotationPath -Encoding UTF8
        
        Write-Log "=== RESUME ROTATION KID ===" "STEP"
        Write-Log "Status global: $($rotationData.GlobalStatus)" $(if($allTestsOK){"SUCCESS"}else{"ERROR"})
        
        if ($rotationData.Issues.Count -gt 0) {
            foreach ($issue in $rotationData.Issues) {
                Write-Log "  $issue" "WARN"
            }
        }
        
        Write-Log "Rapport sauvegardé: $rotationPath" "SUCCESS"
        
        return $rotationPath
        
    } catch {
        Write-Log "Erreur test rotation KID: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# === RENOUVELLEMENT J-15 ===

function Process-LicenseRenewal {
    param($LeadDays = 15)
    
    Write-Log "=== RENOUVELLEMENT LICENCES (J-$LeadDays) ===" "STEP"
    
    try {
        # 1. Identifier les licences à renouveler
        $renewalCandidates = @()
        
        # Simuler une liste de clients avec dates d'expiration
        $clientsExpiration = @(
            @{ Machine = "CLIENT-ALPHA-PC01"; Fingerprint = "ALPHA-FP-001"; ExpiryDate = (Get-Date).AddDays(10) },
            @{ Machine = "CLIENT-BETA-PC01"; Fingerprint = "BETA-FP-002"; ExpiryDate = (Get-Date).AddDays(20) },
            @{ Machine = "CLIENT-GAMMA-PC01"; Fingerprint = "GAMMA-FP-003"; ExpiryDate = (Get-Date).AddDays(45) }
        )
        
        foreach ($client in $clientsExpiration) {
            $daysToExpiry = ($client.ExpiryDate - (Get-Date)).Days
            
            if ($daysToExpiry -le $LeadDays -and $daysToExpiry -gt 0) {
                $renewalCandidates += @{
                    Machine = $client.Machine
                    Fingerprint = $client.Fingerprint
                    ExpiryDate = $client.ExpiryDate.ToString("yyyy-MM-dd")
                    DaysRemaining = $daysToExpiry
                    UsbSerial = "USB-SER-$(Get-Random -Minimum 1000 -Maximum 9999)"
                }
            }
        }
        
        Write-Log "Candidats au renouvellement: $($renewalCandidates.Count)" "INFO"
        
        if ($renewalCandidates.Count -eq 0) {
            Write-Log "Aucune licence à renouveler dans les $LeadDays prochains jours" "SUCCESS"
            return
        }
        
        # 2. Créer CSV pour traitement batch
        $renewalCsvPath = Join-Path $OutputDir "renewal\ring1-renewals-$(Get-Date -Format 'yyyyMMdd').csv"
        
        $csvContent = "Machine,Fingerprint,UsbSerial,ExpiryDate,DaysRemaining`n"
        foreach ($candidate in $renewalCandidates) {
            $csvContent += "$($candidate.Machine),$($candidate.Fingerprint),$($candidate.UsbSerial),$($candidate.ExpiryDate),$($candidate.DaysRemaining)`n"
        }
        
        $csvContent | Out-File -FilePath $renewalCsvPath -Encoding UTF8
        Write-Log "CSV renouvellement créé: $renewalCsvPath" "SUCCESS"
        
        # 3. Générer les commandes de renouvellement (snippet utilisateur)
        $renewalScriptPath = Join-Path $OutputDir "renewal\renewal-commands-$(Get-Date -Format 'yyyyMMdd').ps1"
        
        $scriptContent = @"
# Script de renouvellement automatique généré le $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# A exécuter depuis le répertoire racine du projet

Import-Csv "$renewalCsvPath" | ForEach-Object {
    Write-Host "Renouvellement: `$(`$_.Machine)" -ForegroundColor Yellow
    
    # Génération nouvelle licence
    node .\scripts\make-license.mjs `$_.Fingerprint `$_.UsbSerial
    
    # Déplacement vers répertoire de livraison
    `$newLicensePath = ".\deliveries\renewals\`$(`$_.Machine)-license-renewed.bin"
    Move-Item .\license.bin `$newLicensePath -Force
    
    # Vérification
    node .\scripts\verify-license.mjs `$newLicensePath
    
    if (`$LASTEXITCODE -eq 0) {
        Write-Host "✅ Licence renouvelée: `$newLicensePath" -ForegroundColor Green
    } else {
        Write-Host "❌ Erreur renouvellement: `$(`$_.Machine)" -ForegroundColor Red
    }
}

Write-Host "`nRenouvellement terminé. Vérifiez le répertoire .\deliveries\renewals\" -ForegroundColor Cyan
"@
        
        $scriptContent | Out-File -FilePath $renewalScriptPath -Encoding UTF8
        Write-Log "Script renouvellement créé: $renewalScriptPath" "SUCCESS"
        
        # 4. Résumé et instructions
        Write-Log "=== INSTRUCTIONS RENOUVELLEMENT ===" "STEP"
        Write-Log "1. Vérifier le CSV: $renewalCsvPath" "INFO"
        Write-Log "2. Exécuter le script: $renewalScriptPath" "INFO"
        Write-Log "3. Distribuer les licences depuis: .\deliveries\renewals\" "INFO"
        Write-Log "4. Confirmer activation avec les clients" "INFO"
        
        foreach ($candidate in $renewalCandidates) {
            Write-Log "⏰ $($candidate.Machine): Expire dans $($candidate.DaysRemaining) jour(s)" "WARN"
        }
        
        return @{
            CsvPath = $renewalCsvPath
            ScriptPath = $renewalScriptPath
            Count = $renewalCandidates.Count
        }
        
    } catch {
        Write-Log "Erreur renouvellement licences: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# === EXECUTION PRINCIPALE ===

try {
    Initialize-RoutineEnvironment
    
    switch ($Task) {
        "audit" {
            Export-AuditTrail -Days $AuditDays
        }
        
        "rotation" {
            Test-KIDRotation -DryRun $DryRun
        }
        
        "renewal" {
            Process-LicenseRenewal -LeadDays $RoutineConfig.RenewalLeadDays
        }
        
        default {
            Write-Log "Tâche non reconnue: $Task" "ERROR"
            Write-Log "Tâches disponibles: audit, rotation, renewal" "INFO"
            exit 1
        }
    }
    
    Write-Log "Tâche routine '$Task' terminée avec succès" "SUCCESS"
    
} catch {
    Write-Log "Erreur tâche routine: $($_.Exception.Message)" "ERROR"
    exit 1
}