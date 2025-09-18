# 🧪 SMOKE TEST - USB Video Vault
# Test de démarrage rapide de l'exécutable

param(
    [string]$ExePath = ".\dist\USB-Video-Vault-0.1.0-portable.exe",
    [int]$TimeoutSeconds = 5
)

Write-Host "🚀 === SMOKE TEST USB VIDEO VAULT ===" -ForegroundColor Green
Write-Host ""

# Vérifier que l'exécutable existe
if (-not (Test-Path $ExePath)) {
    Write-Host "❌ ERREUR: Exécutable introuvable: $ExePath" -ForegroundColor Red
    exit 1
}

Write-Host "📁 Exécutable: $ExePath" -ForegroundColor Cyan
Write-Host "⏱️ Timeout: $TimeoutSeconds secondes" -ForegroundColor Cyan
Write-Host ""

# Créer répertoire temporaire pour les logs
$tempDir = Join-Path $env:TEMP "usbvault-smoke-test"
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

$stdoutFile = Join-Path $tempDir "stdout.log"
$stderrFile = Join-Path $tempDir "stderr.log"

Write-Host "📋 Logs temporaires:" -ForegroundColor Yellow
Write-Host "   STDOUT: $stdoutFile"
Write-Host "   STDERR: $stderrFile"
Write-Host ""

try {
    Write-Host "🔥 Lancement de l'application..." -ForegroundColor Yellow
    
    # Lancer le processus avec redirection
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $ExePath
    $processInfo.Arguments = "--no-sandbox --disable-gpu-sandbox --disable-dev-shm-usage"
    $processInfo.UseShellExecute = $false
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.CreateNoWindow = $false
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    
    # Démarrer le processus
    $started = $process.Start()
    
    if ($started) {
        Write-Host "✅ Processus démarré (PID: $($process.Id))" -ForegroundColor Green
        
        # Lire les outputs de façon asynchrone
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        
        # Attendre le timeout
        Write-Host "⏳ Attente de $TimeoutSeconds secondes..." -ForegroundColor Yellow
        
        $waitResult = $process.WaitForExit($TimeoutSeconds * 1000)
        
        if (-not $waitResult) {
            Write-Host "⏰ Timeout atteint - fermeture du processus..." -ForegroundColor Yellow
            
            # Essayer de fermer proprement
            try {
                $process.CloseMainWindow()
                Start-Sleep -Seconds 2
                
                if (-not $process.HasExited) {
                    Write-Host "🔨 Fermeture forcée..." -ForegroundColor Orange
                    $process.Kill()
                }
            } catch {
                Write-Host "⚠️ Erreur lors de la fermeture: $($_.Exception.Message)" -ForegroundColor Orange
            }
        }
        
        # Attendre la fin des tâches de lecture
        $stdout = ""
        $stderr = ""
        
        try {
            $stdout = $stdoutTask.GetAwaiter().GetResult()
            $stderr = $stderrTask.GetAwaiter().GetResult()
        } catch {
            Write-Host "⚠️ Erreur lecture outputs: $($_.Exception.Message)" -ForegroundColor Orange
        }
        
        # Sauvegarder dans les fichiers
        $stdout | Out-File -FilePath $stdoutFile -Encoding UTF8
        $stderr | Out-File -FilePath $stderrFile -Encoding UTF8
        
        Write-Host "✅ Processus terminé (Exit Code: $($process.ExitCode))" -ForegroundColor Green
        
    } else {
        throw "Impossible de démarrer le processus"
    }
    
} catch {
    Write-Host "❌ ERREUR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    if ($process -and -not $process.HasExited) {
        try {
            $process.Kill()
        } catch {}
    }
    if ($process) {
        $process.Dispose()
    }
}

Write-Host ""
Write-Host "🔍 === ANALYSE DES LOGS ===" -ForegroundColor Green

# Analyser STDOUT
Write-Host ""
Write-Host "📤 STDOUT - Lignes contenant LICENSE, vault, GCM:" -ForegroundColor Cyan

if (Test-Path $stdoutFile) {
    $stdoutContent = Get-Content $stdoutFile -ErrorAction SilentlyContinue
    if ($stdoutContent) {
        $filteredStdout = $stdoutContent | Where-Object { 
            $_ -match "LICENSE|vault|GCM|error|ERROR|warning|WARNING" 
        }
        
        if ($filteredStdout) {
            $filteredStdout | ForEach-Object {
                Write-Host "   $_" -ForegroundColor White
            }
        } else {
            Write-Host "   (aucune ligne trouvée)" -ForegroundColor Gray
        }
        
        Write-Host "   Total lignes STDOUT: $($stdoutContent.Count)" -ForegroundColor Gray
    } else {
        Write-Host "   (STDOUT vide)" -ForegroundColor Gray
    }
} else {
    Write-Host "   (fichier STDOUT non trouvé)" -ForegroundColor Gray
}

# Analyser STDERR
Write-Host ""
Write-Host "📥 STDERR - Lignes contenant LICENSE, vault, GCM:" -ForegroundColor Cyan

if (Test-Path $stderrFile) {
    $stderrContent = Get-Content $stderrFile -ErrorAction SilentlyContinue
    if ($stderrContent) {
        $filteredStderr = $stderrContent | Where-Object { 
            $_ -match "LICENSE|vault|GCM|error|ERROR|warning|WARNING" 
        }
        
        if ($filteredStderr) {
            $filteredStderr | ForEach-Object {
                if ($_ -match "error|ERROR") {
                    Write-Host "   $_" -ForegroundColor Red
                } elseif ($_ -match "warning|WARNING") {
                    Write-Host "   $_" -ForegroundColor Yellow
                } else {
                    Write-Host "   $_" -ForegroundColor White
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

Write-Host ""
Write-Host "🎯 === RÉSULTAT SMOKE TEST ===" -ForegroundColor Green

# Déterminer le résultat
$hasErrors = $false
if (Test-Path $stderrFile) {
    $stderrContent = Get-Content $stderrFile -ErrorAction SilentlyContinue
    $errors = $stderrContent | Where-Object { $_ -match "error|ERROR|fatal|FATAL" }
    if ($errors) {
        $hasErrors = $true
    }
}

if ($hasErrors) {
    Write-Host "❌ SMOKE TEST ÉCHOUÉ - Erreurs détectées" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ SMOKE TEST RÉUSSI - Application démarre correctement" -ForegroundColor Green
}

Write-Host ""
Write-Host "📂 Logs conservés dans: $tempDir" -ForegroundColor Cyan
Write-Host "🧹 Pour nettoyer: Remove-Item '$tempDir' -Recurse -Force" -ForegroundColor Gray