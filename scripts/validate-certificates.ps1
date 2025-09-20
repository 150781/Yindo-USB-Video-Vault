#!/usr/bin/env pwsh
# Validation Certificats - Code Signing

param(
    [switch]$ShowAll,
    [switch]$CheckExpiry,
    [int]$ExpiryWarningDays = 30
)

function Get-CodeSigningCerts {
    $certs = @()
    
    # Certificats utilisateur
    $userCerts = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue
    foreach ($cert in $userCerts) {
        $certs += [PSCustomObject]@{
            Location = "CurrentUser"
            Subject = $cert.Subject
            Issuer = $cert.Issuer
            Thumbprint = $cert.Thumbprint
            NotBefore = $cert.NotBefore
            NotAfter = $cert.NotAfter
            DaysToExpiry = [math]::Round(($cert.NotAfter - (Get-Date)).TotalDays, 0)
            IsExpired = $cert.NotAfter -lt (Get-Date)
            Certificate = $cert
        }
    }
    
    # Certificats machine
    $machineCerts = Get-ChildItem Cert:\LocalMachine\My -CodeSigningCert -ErrorAction SilentlyContinue
    foreach ($cert in $machineCerts) {
        $certs += [PSCustomObject]@{
            Location = "LocalMachine"
            Subject = $cert.Subject
            Issuer = $cert.Issuer
            Thumbprint = $cert.Thumbprint
            NotBefore = $cert.NotBefore
            NotAfter = $cert.NotAfter
            DaysToExpiry = [math]::Round(($cert.NotAfter - (Get-Date)).TotalDays, 0)
            IsExpired = $cert.NotAfter -lt (Get-Date)
            Certificate = $cert
        }
    }
    
    return $certs
}

function Show-CertificateStatus {
    param([object[]]$Certificates)
    
    Write-Host "CERTIFICATS CODE SIGNING" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    
    if (-not $Certificates) {
        Write-Host "AUCUN certificat code signing trouve" -ForegroundColor Red
        Write-Host "Installer un certificat dans CurrentUser\My ou LocalMachine\My" -ForegroundColor Yellow
        return
    }
    
    foreach ($cert in $Certificates) {
        $statusColor = "Green"
        $statusIcon = "OK"
        
        if ($cert.IsExpired) {
            $statusColor = "Red"
            $statusIcon = "EXPIRE"
        } elseif ($cert.DaysToExpiry -le $ExpiryWarningDays) {
            $statusColor = "Yellow"
            $statusIcon = "ATTENTION"
        }
        
        Write-Host "`n$statusIcon CERTIFICAT - $($cert.Location)" -ForegroundColor $statusColor
        Write-Host "   Subject:     $($cert.Subject)" -ForegroundColor White
        Write-Host "   Issuer:      $($cert.Issuer)" -ForegroundColor Gray
        Write-Host "   Thumbprint:  $($cert.Thumbprint)" -ForegroundColor Gray
        Write-Host "   Validite:    $($cert.NotBefore.ToString('yyyy-MM-dd')) -> $($cert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
        
        if ($cert.IsExpired) {
            Write-Host "   Statut:      EXPIRE depuis $(-$cert.DaysToExpiry) jours" -ForegroundColor Red
        } else {
            Write-Host "   Statut:      Expire dans $($cert.DaysToExpiry) jours" -ForegroundColor $statusColor
        }
    }
}

function Test-SignToolAccess {
    Write-Host "`nSIGNTOOL DISPONIBILITE" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    
    try {
        $signToolOutput = & signtool 2>&1
        if ($LASTEXITCODE -eq 0 -or $signToolOutput -match "Usage: signtool") {
            Write-Host "SignTool.exe disponible" -ForegroundColor Green
            
            # Version SignTool
            $versionLine = $signToolOutput | Select-String "Version" | Select-Object -First 1
            if ($versionLine) {
                Write-Host "   $($versionLine.Line)" -ForegroundColor Gray
            }
        } else {
            Write-Host "SignTool non fonctionnel" -ForegroundColor Red
        }
    } catch {
        Write-Host "SignTool.exe non trouve" -ForegroundColor Red
        Write-Host "Installer Windows SDK ou Visual Studio" -ForegroundColor Yellow
    }
}

function Test-TimestampServers {
    Write-Host "`nSERVEURS TIMESTAMP" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    
    $timestampServers = @(
        "http://timestamp.digicert.com",
        "http://timestamp.comodoca.com",
        "http://timestamp.sectigo.com"
    )
    
    foreach ($server in $timestampServers) {
        try {
            $null = Invoke-WebRequest -Uri $server -Method Head -TimeoutSec 5 -ErrorAction Stop
            Write-Host "OK $server" -ForegroundColor Green
        } catch {
            Write-Host "ERREUR $server" -ForegroundColor Red
        }
    }
}

# =============================================================================
# EXECUTION PRINCIPALE
# =============================================================================

Write-Host "VALIDATION CERTIFICATS CODE SIGNING" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

$certificates = Get-CodeSigningCerts
Show-CertificateStatus -Certificates $certificates

Test-SignToolAccess
Test-TimestampServers

# Recommandations finales
$validCerts = $certificates | Where-Object { -not $_.IsExpired }
if ($validCerts) {
    Write-Host "`nCERTIFICAT RECOMMANDE POUR PRODUCTION:" -ForegroundColor Green
    $bestCert = $validCerts | Sort-Object DaysToExpiry -Descending | Select-Object -First 1
    Write-Host "   Thumbprint: $($bestCert.Thumbprint)" -ForegroundColor White
    Write-Host "   Subject:    $($bestCert.Subject)" -ForegroundColor White
    Write-Host "   Expire:     $($bestCert.NotAfter.ToString('yyyy-MM-dd')) ($($bestCert.DaysToExpiry) jours)" -ForegroundColor White
    
    Write-Host "`nCOMMANDE SIGNATURE:" -ForegroundColor Cyan
    Write-Host "   signtool sign /sha1 $($bestCert.Thumbprint) /tr http://timestamp.digicert.com /td SHA256 /fd SHA256 `"file.exe`"" -ForegroundColor White
} else {
    Write-Host "`nAUCUN CERTIFICAT VALIDE - BUILD SIGNING IMPOSSIBLE" -ForegroundColor Red
}

Write-Host "`nValidation terminee" -ForegroundColor Green