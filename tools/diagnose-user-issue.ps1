# Script de diagnostic utilisateur complet
# Usage: .\tools\diagnose-user-issue.ps1 [-Issue "description"] [-Verbose] [-ExportReport]

param(
    [string]$Issue = "",
    [switch]$Verbose,
    [switch]$ExportReport
)

Write-Host "=== DIAGNOSTIC UTILISATEUR USB VIDEO VAULT ===" -ForegroundColor Cyan
Write-Host ""

if ($Issue) {
    Write-Host "Probleme signale: $Issue" -ForegroundColor Yellow
    Write-Host ""
}

$diagnosticData = @{
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    issue = $Issue
    system = @{}
    application = @{}
    vault = @{}
    network = @{}
    recommendations = @()
}

# COLLECTE INFORMATIONS SYSTEME
Write-Host "1. COLLECTE INFORMATIONS SYSTEME..." -ForegroundColor Yellow

try {
    $computerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
    $diagnosticData.system = @{
        os = "$($computerInfo.WindowsProductName) ($($computerInfo.WindowsVersion))"
        build = $computerInfo.WindowsBuildLabEx
        memory = [math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 1)
        architecture = $env:PROCESSOR_ARCHITECTURE
        powershell = "$($PSVersionTable.PSVersion)"
        dotnet = ""
        antivirus = ""
    }

    Write-Host "  OS: $($diagnosticData.system.os)" -ForegroundColor Green
    Write-Host "  RAM: $($diagnosticData.system.memory) GB" -ForegroundColor Green
    Write-Host "  Architecture: $($diagnosticData.system.architecture)" -ForegroundColor Green

} catch {
    Write-Host "  ERREUR collecte systeme: $($_.Exception.Message)" -ForegroundColor Red
}

# Detection .NET Framework
try {
    $dotnetVersions = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse |
        Get-ItemProperty -Name version -ErrorAction SilentlyContinue |
        Where-Object { $_.version -like "4.*" } |
        Sort-Object version -Descending |
        Select-Object -First 1

    if ($dotnetVersions) {
        $diagnosticData.system.dotnet = $dotnetVersions.version
        Write-Host "  .NET Framework: $($dotnetVersions.version)" -ForegroundColor Green
    } else {
        Write-Host "  .NET Framework: NON DETECTE" -ForegroundColor Red
        $diagnosticData.recommendations += "Installer .NET Framework 4.8+"
    }
} catch {
    Write-Host "  .NET Framework: ERREUR DETECTION" -ForegroundColor Yellow
}

# Detection antivirus
try {
    $antivirus = Get-WmiObject -Namespace "root\SecurityCenter2" -Class AntiVirusProduct -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($antivirus) {
        $diagnosticData.system.antivirus = $antivirus.displayName
        Write-Host "  Antivirus: $($antivirus.displayName)" -ForegroundColor Green
    }
} catch {
    # Ignorer si pas d'acces
}

# VERIFICATION APPLICATION
Write-Host ""
Write-Host "2. VERIFICATION APPLICATION..." -ForegroundColor Yellow

# Recherche installation
$installPaths = @(
    "C:\Program Files\USB Video Vault",
    "C:\Program Files (x86)\USB Video Vault",
    "$env:LOCALAPPDATA\Programs\USB Video Vault"
)

$foundInstall = $null
foreach ($path in $installPaths) {
    if (Test-Path $path) {
        $foundInstall = $path
        break
    }
}

if ($foundInstall) {
    Write-Host "  Installation: DETECTEE" -ForegroundColor Green
    Write-Host "    Chemin: $foundInstall" -ForegroundColor Gray

    $exePath = Join-Path $foundInstall "USB Video Vault.exe"
    if (Test-Path $exePath) {
        $diagnosticData.application.installed = $true
        $diagnosticData.application.path = $foundInstall
        $diagnosticData.application.executable = $exePath

        # Version executable
        try {
            $versionInfo = (Get-ItemProperty $exePath).VersionInfo
            $diagnosticData.application.version = $versionInfo.FileVersion
            Write-Host "    Version: $($versionInfo.FileVersion)" -ForegroundColor Green
        } catch {
            Write-Host "    Version: NON LISIBLE" -ForegroundColor Yellow
        }

        # Taille executable
        $exeSize = [math]::Round((Get-Item $exePath).Length / 1MB, 1)
        $diagnosticData.application.size = $exeSize
        Write-Host "    Taille: $exeSize MB" -ForegroundColor Gray

        # Signature executable
        try {
            $signature = Get-AuthenticodeSignature $exePath
            $diagnosticData.application.signed = ($signature.Status -eq "Valid")

            if ($signature.Status -eq "Valid") {
                Write-Host "    Signature: VALIDE" -ForegroundColor Green
                Write-Host "      Signataire: $($signature.SignerCertificate.Subject)" -ForegroundColor Gray
            } elseif ($signature.Status -eq "NotSigned") {
                Write-Host "    Signature: NON SIGNEE" -ForegroundColor Yellow
                $diagnosticData.recommendations += "Utiliser version officielle signee depuis GitHub"
            } else {
                Write-Host "    Signature: INVALIDE ($($signature.Status))" -ForegroundColor Red
                $diagnosticData.recommendations += "Reinstaller version officielle"
            }
        } catch {
            Write-Host "    Signature: ERREUR VERIFICATION" -ForegroundColor Red
        }

    } else {
        Write-Host "  Executable: MANQUANT" -ForegroundColor Red
        $diagnosticData.application.installed = $false
        $diagnosticData.recommendations += "Reinstaller l'application"
    }
} else {
    Write-Host "  Installation: NON DETECTEE" -ForegroundColor Red
    $diagnosticData.application.installed = $false
    $diagnosticData.recommendations += "Installer USB Video Vault"
}

# Verification registre Windows
try {
    $registryEntry = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*USB Video Vault*" }

    if ($registryEntry) {
        Write-Host "  Registre: PRESENT" -ForegroundColor Green
        Write-Host "    Version registre: $($registryEntry.DisplayVersion)" -ForegroundColor Gray
    } else {
        Write-Host "  Registre: ABSENT" -ForegroundColor Yellow
        if ($diagnosticData.application.installed) {
            $diagnosticData.recommendations += "Installation corrompue - reinstaller"
        }
    }
} catch {
    Write-Host "  Registre: ERREUR ACCES" -ForegroundColor Yellow
}

# TEST LANCEMENT RAPIDE
if ($diagnosticData.application.installed -and $diagnosticData.application.executable) {
    Write-Host ""
    Write-Host "3. TEST LANCEMENT RAPIDE..." -ForegroundColor Yellow

    try {
        Write-Host "  Lancement test (5s timeout)..." -ForegroundColor Gray

        $testProcess = Start-Process -FilePath $diagnosticData.application.executable -ArgumentList "--version" -PassThru -WindowStyle Hidden -RedirectStandardOutput "diagnostic-output.tmp" -RedirectStandardError "diagnostic-error.tmp"

        $timeout = 5000  # 5 secondes
        if ($testProcess.WaitForExit($timeout)) {
            if ($testProcess.ExitCode -eq 0) {
                Write-Host "  Lancement: SUCCES" -ForegroundColor Green
                $diagnosticData.application.launchable = $true
            } else {
                Write-Host "  Lancement: ECHEC (code $($testProcess.ExitCode))" -ForegroundColor Red
                $diagnosticData.application.launchable = $false

                # Lire erreur si disponible
                if (Test-Path "diagnostic-error.tmp") {
                    $errorContent = Get-Content "diagnostic-error.tmp" -Raw -ErrorAction SilentlyContinue
                    if ($errorContent.Trim()) {
                        Write-Host "    Erreur: $($errorContent.Trim())" -ForegroundColor Red
                        $diagnosticData.application.lastError = $errorContent.Trim()
                    }
                }
            }
        } else {
            Write-Host "  Lancement: TIMEOUT" -ForegroundColor Yellow
            $diagnosticData.application.launchable = $false
            $testProcess.Kill()
        }

        # Nettoyer fichiers temporaires
        @("diagnostic-output.tmp", "diagnostic-error.tmp") | ForEach-Object {
            if (Test-Path $_) { Remove-Item $_ -Force -ErrorAction SilentlyContinue }
        }

    } catch {
        Write-Host "  Lancement: ERREUR ($($_.Exception.Message))" -ForegroundColor Red
        $diagnosticData.application.launchable = $false
        $diagnosticData.application.lastError = $_.Exception.Message
    }
}

# VERIFICATION VAULTS
Write-Host ""
Write-Host "4. VERIFICATION VAULTS..." -ForegroundColor Yellow

$vaultPaths = @(
    ".\usb-package\vault",
    ".\vault",
    ".\test-vault",
    "$env:USERPROFILE\Documents\USB Video Vault\vaults"
)

$foundVaults = @()
foreach ($vaultPath in $vaultPaths) {
    if (Test-Path $vaultPath) {
        $vaultInfo = @{
            path = $vaultPath
            size = 0
            mediaCount = 0
            hasManifest = $false
        }

        # Calculer taille
        try {
            $vaultSize = (Get-ChildItem $vaultPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
            $vaultInfo.size = [math]::Round($vaultSize / 1MB, 1)
        } catch {
            $vaultInfo.size = 0
        }

        # Compter medias
        $mediaFiles = Get-ChildItem "$vaultPath\media" -Filter "*.enc" -ErrorAction SilentlyContinue
        $vaultInfo.mediaCount = ($mediaFiles | Measure-Object).Count

        # Verifier manifest
        $vaultInfo.hasManifest = Test-Path "$vaultPath\manifest.json"

        $foundVaults += $vaultInfo
        Write-Host "  Vault: $vaultPath" -ForegroundColor Green
        Write-Host "    Taille: $($vaultInfo.size) MB" -ForegroundColor Gray
        Write-Host "    Medias: $($vaultInfo.mediaCount)" -ForegroundColor Gray
        Write-Host "    Manifest: $(if($vaultInfo.hasManifest){'Present'}else{'Manquant'})" -ForegroundColor Gray
    }
}

$diagnosticData.vault.found = $foundVaults.Count
$diagnosticData.vault.details = $foundVaults

if ($foundVaults.Count -eq 0) {
    Write-Host "  Aucun vault detecte" -ForegroundColor Yellow
    $diagnosticData.recommendations += "Creer un vault de demo pour tester"
} else {
    Write-Host "  Total: $($foundVaults.Count) vault(s) detecte(s)" -ForegroundColor Green
}

# VERIFICATION CONNECTIVITE
Write-Host ""
Write-Host "5. VERIFICATION CONNECTIVITE..." -ForegroundColor Yellow

# Test DNS
try {
    $dnsTest = Resolve-DnsName "github.com" -ErrorAction Stop
    Write-Host "  DNS: OK" -ForegroundColor Green
    $diagnosticData.network.dns = $true
} catch {
    Write-Host "  DNS: ECHEC" -ForegroundColor Red
    $diagnosticData.network.dns = $false
    $diagnosticData.recommendations += "Verifier configuration DNS"
}

# Test HTTPS
try {
    $webTest = Invoke-WebRequest "https://api.github.com" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    Write-Host "  HTTPS: OK (GitHub API accessible)" -ForegroundColor Green
    $diagnosticData.network.https = $true
} catch {
    Write-Host "  HTTPS: ECHEC" -ForegroundColor Yellow
    $diagnosticData.network.https = $false
    if ($_.Exception.Message -like "*proxy*") {
        $diagnosticData.recommendations += "Configurer proxy d'entreprise"
    }
}

# ANALYSE PROCESSUS
Write-Host ""
Write-Host "6. ANALYSE PROCESSUS..." -ForegroundColor Yellow

$usbProcesses = Get-Process | Where-Object { $_.ProcessName -like "*USB*Video*Vault*" -or $_.ProcessName -like "*usbvideovault*" }

if ($usbProcesses) {
    Write-Host "  Processus actifs: $($usbProcesses.Count)" -ForegroundColor Yellow
    foreach ($proc in $usbProcesses) {
        $memoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 1)
        Write-Host "    - PID $($proc.Id): $memoryMB MB" -ForegroundColor Gray
    }
    $diagnosticData.recommendations += "Fermer instances existantes avant troubleshooting"
} else {
    Write-Host "  Aucun processus actif" -ForegroundColor Green
}

# RAPPORT FINAL
Write-Host ""
Write-Host "=== RAPPORT DIAGNOSTIC ===" -ForegroundColor Cyan

$criticalIssues = 0
$warnings = 0

# Evaluation critique
if (-not $diagnosticData.application.installed) {
    Write-Host "CRITIQUE: Application non installee" -ForegroundColor Red
    $criticalIssues++
} elseif (-not $diagnosticData.application.launchable) {
    Write-Host "CRITIQUE: Application ne demarre pas" -ForegroundColor Red
    $criticalIssues++
}

if ($diagnosticData.system.memory -lt 4) {
    Write-Host "ATTENTION: RAM insuffisante ($($diagnosticData.system.memory) GB)" -ForegroundColor Yellow
    $warnings++
}

if (-not $diagnosticData.system.dotnet) {
    Write-Host "ATTENTION: .NET Framework manquant" -ForegroundColor Yellow
    $warnings++
}

# Statut global
Write-Host ""
if ($criticalIssues -eq 0) {
    Write-Host "STATUT: SYSTEME FONCTIONNEL" -ForegroundColor Green
} elseif ($criticalIssues -eq 1) {
    Write-Host "STATUT: PROBLEME MINEUR" -ForegroundColor Yellow
} else {
    Write-Host "STATUT: PROBLEMES CRITIQUES" -ForegroundColor Red
}

# Recommendations
if ($diagnosticData.recommendations.Count -gt 0) {
    Write-Host ""
    Write-Host "RECOMMANDATIONS:" -ForegroundColor Blue
    for ($i = 0; $i -lt $diagnosticData.recommendations.Count; $i++) {
        Write-Host "  $($i+1). $($diagnosticData.recommendations[$i])" -ForegroundColor White
    }
}

# Export rapport si demande
if ($ExportReport) {
    $reportFile = "diagnostic-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $diagnosticData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Host ""
    Write-Host "Rapport exporte: $reportFile" -ForegroundColor Green
    Write-Host "Joindre ce fichier au rapport de bug" -ForegroundColor Blue
}

Write-Host ""
Write-Host "Duree diagnostic: $([math]::Round(((Get-Date) - [datetime]$diagnosticData.timestamp).TotalSeconds, 1))s" -ForegroundColor Gray
