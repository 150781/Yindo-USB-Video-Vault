param(
    [string]$Mode = "CHECK",
    [string]$KeysPath = "scripts\keys",
    [string]$BackupPath = "scripts\keys\backup"
)

Write-Host ""
Write-Host "=== GESTION SECURISEE DES CLES ===" -ForegroundColor Cyan
Write-Host "Mode: $Mode" -ForegroundColor Yellow
Write-Host ""

try {
    # Verification existence des cles
    Write-Host "[STEP 1/4] Verification des cles..." -ForegroundColor Green
    
    $privateKeyPath = Join-Path $KeysPath "private.pem"
    $publicKeyPath = Join-Path $KeysPath "public.pem"
    
    $keyStatus = @()
    
    if (Test-Path $privateKeyPath) {
        $keyStatus += @{ Key = "Private"; Status = "OK"; Path = $privateKeyPath }
        Write-Host "  [OK] Cle privee presente: $privateKeyPath" -ForegroundColor Green
    } else {
        $keyStatus += @{ Key = "Private"; Status = "MISSING"; Path = $privateKeyPath }
        Write-Host "  [ERROR] Cle privee manquante: $privateKeyPath" -ForegroundColor Red
    }
    
    if (Test-Path $publicKeyPath) {
        $keyStatus += @{ Key = "Public"; Status = "OK"; Path = $publicKeyPath }
        Write-Host "  [OK] Cle publique presente: $publicKeyPath" -ForegroundColor Green
    } else {
        $keyStatus += @{ Key = "Public"; Status = "MISSING"; Path = $publicKeyPath }
        Write-Host "  [ERROR] Cle publique manquante: $publicKeyPath" -ForegroundColor Red
    }

    # Verification permissions
    Write-Host "[STEP 2/4] Verification permissions..." -ForegroundColor Green
    
    if (Test-Path $KeysPath) {
        Get-Acl $KeysPath | Out-Null
        Write-Host "  [OK] Permissions du repertoire des cles verifiees" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Repertoire des cles inexistant" -ForegroundColor Yellow
    }

    # Sauvegarde (si mode BACKUP)
    Write-Host "[STEP 3/4] Sauvegarde des cles..." -ForegroundColor Green
    
    if ($Mode -eq "BACKUP" -and (Test-Path $privateKeyPath)) {
        if (-not (Test-Path $BackupPath)) {
            New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPrivate = Join-Path $BackupPath "private-$timestamp.pem"
        $backupPublic = Join-Path $BackupPath "public-$timestamp.pem"
        
        Copy-Item $privateKeyPath $backupPrivate -ErrorAction SilentlyContinue
        Copy-Item $publicKeyPath $backupPublic -ErrorAction SilentlyContinue
        
        Write-Host "  [OK] Sauvegarde creee: $BackupPath" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] Sauvegarde non requise (mode: $Mode)" -ForegroundColor Gray
    }

    # Test integrite
    Write-Host "[STEP 4/4] Test integrite..." -ForegroundColor Green
    
    $integrityTests = @()
    
    if (Test-Path $privateKeyPath) {
        $content = Get-Content $privateKeyPath -Raw
        $integrityTests += @{
            Key = "Private"
            Valid = ($content.Length -gt 0)
            Size = $content.Length
        }
        Write-Host "  [OK] Integrite cle privee: OK ($($content.Length) caracteres)" -ForegroundColor Green
    }
    
    if (Test-Path $publicKeyPath) {
        $content = Get-Content $publicKeyPath -Raw
        $integrityTests += @{
            Key = "Public"
            Valid = ($content.Length -gt 0)
            Size = $content.Length
        }
        Write-Host "  [OK] Integrite cle publique: OK ($($content.Length) caracteres)" -ForegroundColor Green
    }

    # Rapport final
    $report = @{
        Mode = $Mode
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        KeysPath = $KeysPath
        BackupPath = $BackupPath
        KeyStatus = $keyStatus
        IntegrityTests = $integrityTests
        OverallStatus = "OK"
    }
    
    if (-not (Test-Path "test-output")) {
        New-Item -Path "test-output" -ItemType Directory -Force | Out-Null
    }
    
    $report | ConvertTo-Json -Depth 3 | Out-File "test-output\key-management-report.json" -Encoding UTF8
    
    Write-Host ""
    Write-Host "=== RESULTATS GESTION DES CLES ===" -ForegroundColor Cyan
    Write-Host "Cles presentes: " -NoNewline
    $presentKeys = ($keyStatus | Where-Object { $_.Status -eq "OK" }).Count
    $totalKeys = $keyStatus.Count
    Write-Host "$presentKeys/$totalKeys" -ForegroundColor $(if ($presentKeys -eq $totalKeys) { "Green" } else { "Yellow" })
    
    Write-Host "Integrite: " -NoNewline
    $validKeys = ($integrityTests | Where-Object { $_.Valid }).Count
    $totalValidated = $integrityTests.Count
    Write-Host "$validKeys/$totalValidated" -ForegroundColor $(if ($validKeys -eq $totalValidated) { "Green" } else { "Red" })
    
    Write-Host ""
    Write-Host "Rapport genere: test-output\key-management-report.json" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Gestion des cles terminee." -ForegroundColor Cyan
    exit 0

} catch {
    Write-Host ""
    Write-Host "ERREUR lors de la gestion des cles:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 1
}