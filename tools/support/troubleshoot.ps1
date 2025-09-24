# Script de diagnostic automatique pour USB Video Vault
# Utilisation: .\troubleshoot.ps1 [-Detailed] [-CollectLogs] [-FixPermissions]

param(
    [switch]$Detailed,
    [switch]$CollectLogs,
    [switch]$FixPermissions
)

Write-Host "=== USB Video Vault - Diagnostic automatique ===" -ForegroundColor Cyan
Write-Host ""

# Fonction pour vérifier l'état d'un service/processus
function Test-ProcessHealth {
    param($ProcessName)
    
    $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($processes) {
        Write-Host "✅ $ProcessName : ${processes.Count} processus actif(s)" -ForegroundColor Green
        if ($Detailed) {
            $processes | ForEach-Object {
                $memoryMB = [math]::Round($_.WorkingSet64 / 1MB, 2)
                Write-Host "   PID ${_.Id}: ${memoryMB}MB RAM, Démarré à ${_.StartTime}" -ForegroundColor Gray
            }
        }
        return $true
    } else {
        Write-Host "❌ $ProcessName : Aucun processus trouvé" -ForegroundColor Red
        return $false
    }
}

# Fonction pour vérifier les permissions de dossier
function Test-FolderPermissions {
    param($Path, $Name)
    
    if (Test-Path $Path) {
        try {
            $testFile = Join-Path $Path "test-permissions-$(Get-Random).tmp"
            "test" | Out-File $testFile -ErrorAction Stop
            Remove-Item $testFile -ErrorAction SilentlyContinue
            Write-Host "✅ $Name : Permissions d'écriture OK" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "❌ $Name : Permissions insuffisantes" -ForegroundColor Red
            Write-Host "   Erreur: $($_.Exception.Message)" -ForegroundColor Gray
            return $false
        }
    } else {
        Write-Host "❌ $Name : Dossier introuvable ($Path)" -ForegroundColor Red
        return $false
    }
}

# 1. Vérification des processus
Write-Host "1. État des processus:" -ForegroundColor Yellow
$appRunning = Test-ProcessHealth "USB Video Vault"
if (-not $appRunning) {
    Test-ProcessHealth "electron"
}

# 2. Vérification des dossiers critiques
Write-Host "`n2. Vérification des dossiers:" -ForegroundColor Yellow
$vaultOK = Test-FolderPermissions ".\vault" "Vault principal"
$usbOK = Test-FolderPermissions ".\usb-package\vault" "Vault USB"
$distOK = Test-FolderPermissions ".\dist" "Dossier de build"

# 3. Vérification des fichiers critiques
Write-Host "`n3. Fichiers critiques:" -ForegroundColor Yellow
$criticalFiles = @(
    @{Path=".\package.json"; Name="Configuration npm"},
    @{Path=".\dist\main\index.js"; Name="Point d'entrée principal"},
    @{Path=".\dist\renderer\index.html"; Name="Interface utilisateur"},
    @{Path=".\electron-builder.yml"; Name="Configuration de build"}
)

$allFilesOK = $true
foreach ($file in $criticalFiles) {
    if (Test-Path $file.Path) {
        $size = (Get-Item $file.Path).Length
        Write-Host "✅ $($file.Name) : ${size} octets" -ForegroundColor Green
    } else {
        Write-Host "❌ $($file.Name) : Fichier manquant ($($file.Path))" -ForegroundColor Red
        $allFilesOK = $false
    }
}

# 4. Vérification des dépendances Node.js
Write-Host "`n4. Environnement Node.js:" -ForegroundColor Yellow
try {
    $nodeVersion = node --version
    Write-Host "✅ Node.js : $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js : Non installé ou non accessible" -ForegroundColor Red
}

try {
    $npmVersion = npm --version
    Write-Host "✅ npm : v$npmVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ npm : Non installé ou non accessible" -ForegroundColor Red
}

# 5. Vérification du module node_modules
if (Test-Path ".\node_modules") {
    $moduleCount = (Get-ChildItem ".\node_modules" -Directory).Count
    Write-Host "✅ node_modules : $moduleCount modules installés" -ForegroundColor Green
} else {
    Write-Host "❌ node_modules : Dossier manquant - exécutez 'npm install'" -ForegroundColor Red
}

# 6. Collection des logs (si demandé)
if ($CollectLogs) {
    Write-Host "`n6. Collection des logs:" -ForegroundColor Yellow
    $logDir = "$env:APPDATA\USB Video Vault\logs"
    if (Test-Path $logDir) {
        $logFiles = Get-ChildItem $logDir -File | Sort-Object LastWriteTime -Descending
        if ($logFiles) {
            Write-Host "✅ Logs trouvés : $($logFiles.Count) fichiers" -ForegroundColor Green
            Write-Host "   Dernier log : $($logFiles[0].Name) ($(Get-Date $logFiles[0].LastWriteTime -Format 'dd/MM/yyyy HH:mm'))" -ForegroundColor Gray
            
            # Copier les logs récents dans un dossier de diagnostic
            $diagDir = ".\diagnostic-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            New-Item -ItemType Directory -Path $diagDir -Force | Out-Null
            $logFiles | Select-Object -First 5 | Copy-Item -Destination $diagDir
            Write-Host "   Logs copiés dans : $diagDir" -ForegroundColor Cyan
        } else {
            Write-Host "⚠️  Aucun fichier de log trouvé" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Dossier de logs introuvable : $logDir" -ForegroundColor Red
    }
}

# 7. Correction des permissions (si demandé)
if ($FixPermissions) {
    Write-Host "`n7. Correction des permissions:" -ForegroundColor Yellow
    
    $foldersToFix = @(".\vault", ".\usb-package", ".\dist", ".\logs")
    foreach ($folder in $foldersToFix) {
        if (Test-Path $folder) {
            try {
                icacls $folder /grant "$env:USERNAME:(OI)(CI)F" /T /Q
                Write-Host "✅ Permissions corrigées : $folder" -ForegroundColor Green
            } catch {
                Write-Host "❌ Erreur correction permissions : $folder" -ForegroundColor Red
            }
        }
    }
}

# 8. Résumé et recommandations
Write-Host "`n=== RÉSUMÉ ===" -ForegroundColor Cyan
if ($allFilesOK -and $vaultOK -and $usbOK) {
    Write-Host "✅ Système en bon état - Aucun problème critique détecté" -ForegroundColor Green
} else {
    Write-Host "⚠️  Problèmes détectés - Recommandations:" -ForegroundColor Yellow
    
    if (-not $allFilesOK) {
        Write-Host "   • Exécutez 'npm run build' pour regénérer les fichiers" -ForegroundColor White
    }
    
    if (-not $vaultOK -or -not $usbOK) {
        Write-Host "   • Vérifiez les permissions des dossiers vault/" -ForegroundColor White
        Write-Host "   • Exécutez ce script avec -FixPermissions" -ForegroundColor White
    }
    
    if (-not $appRunning) {
        Write-Host "   • L'application n'est pas en cours d'exécution" -ForegroundColor White
        Write-Host "   • Lancez 'npm start' pour démarrer en mode développement" -ForegroundColor White
    }
}

Write-Host "`nPour plus de détails, utilisez -Detailed" -ForegroundColor Gray
Write-Host "Pour collecter les logs, utilisez -CollectLogs" -ForegroundColor Gray
Write-Host "Pour corriger les permissions, utilisez -FixPermissions" -ForegroundColor Gray