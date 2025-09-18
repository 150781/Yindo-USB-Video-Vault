# === SMOKE TEST RAPIDE ===
# Lance l'app et vérifie les logs critiques

$ErrorActionPreference = 'Stop'

Write-Host "=== SMOKE TEST USB VIDEO VAULT ===" -ForegroundColor Cyan
Write-Host ""

# Configuration
$env:VAULT_PATH = (Resolve-Path ".\usb-package\vault").Path
$out = 'smoke.out.txt'
$err = 'smoke.err.txt'

Write-Host "VAULT_PATH: $env:VAULT_PATH" -ForegroundColor Green
Write-Host "Lancement de l'app..." -ForegroundColor Yellow

# Cleanup des anciens logs
Remove-Item $out, $err -ErrorAction SilentlyContinue

try {
    # Lancer l'app avec capture des logs
    $proc = Start-Process -FilePath 'npx' -ArgumentList @('electron', '.', '--no-sandbox') -RedirectStandardOutput $out -RedirectStandardError $err -NoNewWindow -PassThru
    
    Write-Host "Attente 6 secondes..." -ForegroundColor Blue
    Start-Sleep -Seconds 6
    
    Write-Host ""
    Write-Host "=== LOGS CRITIQUES ===" -ForegroundColor Magenta
    
    # Analyser les logs
    $logs = Get-Content $out, $err -ErrorAction SilentlyContinue | Where-Object { $_ -match "LICENSE|vault|GCM|watermark|error|ERROR|QUITTING" }
    
    if ($logs) {
        foreach ($log in $logs) {
            if ($log -match "ERROR|error|QUITTING") {
                Write-Host "ERREUR: $log" -ForegroundColor Red
            } elseif ($log -match "LICENSE.*valide|vault.*ready|GCM") {
                Write-Host "OK: $log" -ForegroundColor Green
            } else {
                Write-Host "INFO: $log" -ForegroundColor White
            }
        }
    } else {
        Write-Host "Aucun log critique trouvé" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "=== VERIFICATIONS ===" -ForegroundColor Cyan
    
    # Vérifier que l'app tourne
    if ($proc -and -not $proc.HasExited) {
        Write-Host "App active (PID: $($proc.Id))" -ForegroundColor Green
    } else {
        Write-Host "App arrêtée prématurément" -ForegroundColor Red
    }
    
    # Vérifier les fichiers vault
    $vaultChecks = @(
        @{ Path = "$env:VAULT_PATH\license.json"; Name = "Licence" },
        @{ Path = "$env:VAULT_PATH\.vault\manifest.bin"; Name = "Manifest" },
        @{ Path = "$env:VAULT_PATH\media"; Name = "Médias" }
    )
    
    foreach ($check in $vaultChecks) {
        if (Test-Path $check.Path) {
            Write-Host "$($check.Name) présent" -ForegroundColor Green
        } else {
            Write-Host "$($check.Name) manquant" -ForegroundColor Red
        }
    }
    
} finally {
    # Cleanup du processus
    if ($proc -and -not $proc.HasExited) {
        Write-Host ""
        Write-Host "Arrêt de l'app..." -ForegroundColor Yellow
        try { 
            $null = $proc.CloseMainWindow() 
        } catch { }
        Start-Sleep -Milliseconds 500
        if (-not $proc.HasExited) { 
            Stop-Process $proc -Force 
        }
        Write-Host "App arrêtée" -ForegroundColor Green
    }
    
    # Cleanup des logs
    Remove-Item $out, $err -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "SMOKE TEST TERMINE" -ForegroundColor Cyan