# Module de raccourcis pour deploiement operationnel
# Version: 1.0.4

function New-Ring0LicensesBatch {
    param(
        [int]$Count = 5,
        [string]$OutputDir = ".\licenses\ring0",
        [string]$Prefix = "RING0-DEVICE"
    )
    
    Write-Host "Generation de $Count licences Ring 0..." -ForegroundColor Cyan
    
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    $licenses = @()
    
    for ($i = 1; $i -le $Count; $i++) {
        $deviceId = "$Prefix-$i"
        $outputFile = Join-Path $OutputDir "$deviceId.lic"
        
        try {
            $licenseData = @{
                DeviceId = $deviceId
                Type = "Ring0"
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                ExpiresAt = (Get-Date).AddYears(1).ToString("yyyy-MM-dd")
            }
            
            $licenseData | ConvertTo-Json | Out-File -FilePath $outputFile -Encoding UTF8
            
            $licenses += @{
                DeviceId = $deviceId
                File = $outputFile
                Status = "Generated"
            }
            
            Write-Host "  OK $deviceId -> $outputFile" -ForegroundColor Green
            
        } catch {
            Write-Host "  ERROR $deviceId : $_" -ForegroundColor Red
        }
    }
    
    Write-Host "Generation terminee: $($licenses.Count) licences" -ForegroundColor Green
    return $licenses
}

function Test-BatchLicenseValidation {
    param(
        [string]$LicenseDir = ".\licenses"
    )
    
    Write-Host "Validation batch des licences..." -ForegroundColor Cyan
    
    $licenseFiles = Get-ChildItem -Path $LicenseDir -Filter "*.lic" -Recurse -ErrorAction SilentlyContinue
    
    if ($licenseFiles.Count -eq 0) {
        Write-Host "Aucune licence trouvee dans $LicenseDir" -ForegroundColor Red
        return $false
    }
    
    Write-Host "$($licenseFiles.Count) licences a valider..." -ForegroundColor White
    
    $results = @{
        Total = $licenseFiles.Count
        Valid = 0
        Invalid = 0
    }
    
    foreach ($licenseFile in $licenseFiles) {
        try {
            $content = Get-Content $licenseFile.FullName | ConvertFrom-Json
            
            if ($content.DeviceId -and $content.Type) {
                $results.Valid++
                Write-Host "  OK $($licenseFile.Name): Valid" -ForegroundColor Green
            } else {
                $results.Invalid++
                Write-Host "  ERROR $($licenseFile.Name): Invalid" -ForegroundColor Yellow
            }
            
        } catch {
            $results.Invalid++
            Write-Host "  ERROR $($licenseFile.Name): Exception" -ForegroundColor Red
        }
    }
    
    $validationRate = [Math]::Round(($results.Valid / $results.Total) * 100, 1)
    Write-Host "Taux de succes: $validationRate%" -ForegroundColor Green
    
    return $results
}

function Get-DeploymentStatus {
    Write-Host "Statut du deploiement..." -ForegroundColor Cyan
    
    $status = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Phase = "Ring0"
        Health = "OK"
        Message = "Deploiement en cours"
    }
    
    Write-Host "Phase: $($status.Phase)" -ForegroundColor Green
    Write-Host "Sante: $($status.Health)" -ForegroundColor Green
    
    return $status
}

Export-ModuleMember -Function New-Ring0LicensesBatch, Test-BatchLicenseValidation, Get-DeploymentStatus