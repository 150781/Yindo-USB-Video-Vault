#  SMOKE TEST - USB Video Vault
# Test de démarrage rapide de l'application (EXE si présent, sinon fallback dev via npx electron)

param(
    [string]$ExePath,                 # Optionnel : chemin exact de l'exécutable
    [int]$WaitSeconds = 6,            # Temps d'attente avant fermeture
    [string]$VaultPath = $env:VAULT_PATH  # Optionnel : VAULT_PATH à appliquer
)

$ErrorActionPreference = 'Stop'

Write-Host " === SMOKE TEST USB VIDEO VAULT ===" -ForegroundColor Green
Write-Host ""

# -- Préparation logs temporaires --
$tempDir = Join-Path $env:TEMP "usbvault-smoke-test"
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

$stdoutFile = Join-Path $tempDir "stdout.log"
$stderrFile = Join-Path $tempDir "stderr.log"
Remove-Item $stdoutFile, $stderrFile -ErrorAction SilentlyContinue

Write-Host " Logs temporaires:" -ForegroundColor Yellow
Write-Host "   STDOUT: $stdoutFile"
Write-Host "   STDERR: $stderrFile"
Write-Host ""

# -- VAULT_PATH (facultatif) --
if ($VaultPath) {
    try {
        $resolved = Resolve-Path $VaultPath -ErrorAction Stop
        $env:VAULT_PATH = $resolved.Path
        Write-Host "VAULT_PATH: $env:VAULT_PATH" -ForegroundColor Cyan
    } catch {
        Write-Host "  VAULT_PATH introuvable: $VaultPath" -ForegroundColor DarkYellow
    }
}

# -- Résolution de l'exécutable --
function Resolve-Exe {
    param([string]$HintPath)

    if ($HintPath -and (Test-Path $HintPath)) {
        return @{ FilePath = (Resolve-Path $HintPath).Path; Args = @(); Mode = 'exe' }
    }

    $distMaybe = Join-Path $PSScriptRoot '..\dist'
    $dist = Resolve-Path $distMaybe -ErrorAction SilentlyContinue
    if ($dist) {
        $exe = Get-ChildItem -Path $dist.Path -Filter 'USB-Video-Vault-*.exe' -File |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($exe) {
            return @{ FilePath = $exe.FullName; Args = @(); Mode = 'exe' }
        }
    }

    # Fallback dev : npx electron .
    return @{ FilePath = 'npx'; Args = @('electron','.', '--no-sandbox'); Mode = 'dev' }
}

$target = Resolve-Exe -HintPath $ExePath
if ($target.Mode -eq 'exe') {
    Write-Host " Exécutable: $($target.FilePath)" -ForegroundColor Cyan
} else {
    Write-Host " Fallback dev: npx electron . --no-sandbox" -ForegroundColor Yellow
}
Write-Host " Timeout: $WaitSeconds secondes" -ForegroundColor Cyan
Write-Host ""

# -- Lancement + capture logs --
$proc = $null

try {
    if ($target.Mode -eq 'exe') {
        # EXE : Start-Process avec redirection
        $proc = Start-Process -FilePath $target.FilePath `
            -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile `
            -PassThru -NoNewWindow
    } else {
        # Fallback dev : npx electron .
        $proc = Start-Process -FilePath $target.FilePath `
            -ArgumentList $target.Args `
            -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile `
            -PassThru -NoNewWindow
    }

    if (-not $proc) { throw "Impossible de démarrer le processus" }

    Write-Host " Processus démarré (PID: $($proc.Id))" -ForegroundColor Green
    Write-Host " Attente de $WaitSeconds secondes..." -ForegroundColor Yellow
    Start-Sleep -Seconds $WaitSeconds

    # Afficher extraits des logs
    Write-Host ""
    Write-Host " === ANALYSE DES LOGS ===" -ForegroundColor Green

    Write-Host ""
    Write-Host " STDOUT - Lignes contenant LICENSE | vault | GCM | warning | error :" -ForegroundColor Cyan
    if (Test-Path $stdoutFile) {
        $stdoutContent = Get-Content $stdoutFile -ErrorAction SilentlyContinue
        if ($stdoutContent) {
            $filteredStdout = $stdoutContent | Where-Object { $_ -match 'LICENSE|vault|GCM|error|ERROR|warning|WARNING' }
            if ($filteredStdout) { $filteredStdout | ForEach-Object { Write-Host "   $_" } }
            else { Write-Host "   (aucune ligne trouvée)" -ForegroundColor Gray }
            Write-Host "   Total lignes STDOUT: $($stdoutContent.Count)" -ForegroundColor Gray
        } else {
            Write-Host "   (STDOUT vide)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   (fichier STDOUT non trouvé)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host " STDERR - Lignes contenant LICENSE | vault | GCM | warning | error :" -ForegroundColor Cyan
    if (Test-Path $stderrFile) {
        $stderrContent = Get-Content $stderrFile -ErrorAction SilentlyContinue
        if ($stderrContent) {
            $filteredStderr = $stderrContent | Where-Object { $_ -match 'LICENSE|vault|GCM|error|ERROR|warning|WARNING|QUITTING' }
            if ($filteredStderr) {
                foreach ($line in $filteredStderr) {
                    if ($line -match 'error|ERROR|fatal|FATAL|QUITTING') {
                        Write-Host "   $line" -ForegroundColor Red
                    } elseif ($line -match 'warning|WARNING') {
                        Write-Host "   $line" -ForegroundColor Yellow
                    } else {
                        Write-Host "   $line"
                    }
                }
            } else {
                Write-Host "   (aucune ligne trouvée)" -ForegroundColor Gray
            }
            Write-Host "   Total lignes STDERR: $($stderrContent.Count)" -ForegroundColor Gray
        } else {
            Write-Host "   (STDERR vide)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   (fichier STDERR non trouvé)" -ForegroundColor Gray
    }

    # Déterminer le résultat
    Write-Host ""
    Write-Host " === RÉSULTAT SMOKE TEST ===" -ForegroundColor Green
    $hasErrors = $false
    if (Test-Path $stderrFile) {
        $stderrContent = Get-Content $stderrFile -ErrorAction SilentlyContinue
        $errors = $stderrContent | Where-Object { $_ -match 'error|ERROR|fatal|FATAL' }
        if ($errors) { $hasErrors = $true }
    }

    if ($hasErrors) {
        Write-Host " SMOKE TEST ÉCHOUÉ - Erreurs détectées" -ForegroundColor Red
        exit 1
    } else {
        Write-Host " SMOKE TEST RÉUSSI - Application démarre correctement" -ForegroundColor Green
        exit 0
    }

} catch {
    Write-Host " ERREUR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Arrêt de l'app
    if ($proc -and -not $proc.HasExited) {
        Write-Host ""
        Write-Host " Arrêt de l'app..." -ForegroundColor Yellow
        try { $null = $proc.CloseMainWindow() } catch { }
        Start-Sleep -Milliseconds 500
        if (-not $proc.HasExited) {
            Stop-Process -Id $proc.Id -Force
        }
        Write-Host " App arrêtée" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host " Logs conservés dans: $tempDir" -ForegroundColor Cyan
    Write-Host " Pour nettoyer: Remove-Item '$tempDir' -Recurse -Force" -ForegroundColor Gray
}
