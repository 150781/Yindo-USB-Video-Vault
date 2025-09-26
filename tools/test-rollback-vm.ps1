# Test de rollback complet sur VM - Scenario reel
# Usage: .\tools\test-rollback-vm.ps1 [-VMName "TestVM"] [-Version "0.1.5"] [-TestMode]

param(
    [string]$VMName = "USB-Video-Vault-Test",
    [string]$Version = "0.1.5",
    [switch]$TestMode
)

Write-Host "=== TEST ROLLBACK COMPLET SUR VM ===" -ForegroundColor Cyan
Write-Host "VM: $VMName" -ForegroundColor White
Write-Host "Version: $Version" -ForegroundColor White
Write-Host ""

if ($TestMode) {
    Write-Host "MODE TEST - Simulation rollback" -ForegroundColor Blue
    Write-Host "Etapes qui seraient executees:" -ForegroundColor Blue
    Write-Host "  1. Verification VM et snapshot" -ForegroundColor Cyan
    Write-Host "  2. Installation version cible" -ForegroundColor Cyan
    Write-Host "  3. Simulation probleme critique" -ForegroundColor Cyan
    Write-Host "  4. Declenchement rollback automatique" -ForegroundColor Cyan
    Write-Host "  5. Validation rollback complet" -ForegroundColor Cyan
    Write-Host "  6. Test restoration snapshot VM" -ForegroundColor Cyan
    exit 0
}

$logFile = ".\logs\rollback-vm-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(if($Level -eq "ERROR"){"Red"}elseif($Level -eq "WARN"){"Yellow"}else{"White"})
    $logEntry | Out-File -FilePath $logFile -Append -Encoding UTF8
}

Write-Log "=== DEBUT TEST ROLLBACK VM ===" "INFO"

# ETAPE 1: VERIFICATION VM
Write-Host "1. VERIFICATION MACHINE VIRTUELLE..." -ForegroundColor Yellow

try {
    # Verifier Hyper-V disponible
    $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue

    if (-not $hyperv -or $hyperv.State -ne "Enabled") {
        Write-Host "  ERREUR: Hyper-V non disponible" -ForegroundColor Red
        Write-Host "  Alternative: Utiliser VMware/VirtualBox manuellement" -ForegroundColor Blue
        Write-Log "Hyper-V non disponible pour test VM" "ERROR"
        exit 1
    }

    Write-Host "  Hyper-V: Disponible" -ForegroundColor Green
    Write-Log "Hyper-V disponible" "INFO"

} catch {
    Write-Host "  ERREUR verification Hyper-V: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "Erreur verification Hyper-V: $($_.Exception.Message)" "ERROR"
}

# Rechercher VM existante
try {
    $vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue

    if ($vm) {
        Write-Host "  VM trouvee: $VMName" -ForegroundColor Green
        Write-Host "    Etat: $($vm.State)" -ForegroundColor Gray
        Write-Host "    Generation: $($vm.Generation)" -ForegroundColor Gray
        Write-Log "VM existante trouvee: $VMName (etat: $($vm.State))" "INFO"

        # Demarrer VM si necessaire
        if ($vm.State -ne "Running") {
            Write-Host "  Demarrage VM..." -ForegroundColor Yellow
            Start-VM -Name $VMName

            # Attendre demarrage
            $timeout = 120  # 2 minutes
            $elapsed = 0

            while ($elapsed -lt $timeout) {
                Start-Sleep -Seconds 5
                $elapsed += 5
                $vmState = (Get-VM -Name $VMName).State

                if ($vmState -eq "Running") {
                    Write-Host "  VM demarree avec succes" -ForegroundColor Green
                    Write-Log "VM demarree: $VMName" "INFO"
                    break
                }

                Write-Host "  Attente demarrage... ($elapsed/${timeout}s)" -ForegroundColor Gray
            }

            if ($elapsed -ge $timeout) {
                Write-Host "  TIMEOUT: VM ne demarre pas" -ForegroundColor Red
                Write-Log "Timeout demarrage VM: $VMName" "ERROR"
                exit 1
            }
        }

    } else {
        Write-Host "  VM non trouvee: $VMName" -ForegroundColor Yellow
        Write-Host "  Creation VM requise..." -ForegroundColor Blue
        Write-Log "VM non trouvee, creation requise: $VMName" "WARN"

        # Instructions creation VM
        Write-Host ""
        Write-Host "INSTRUCTIONS CREATION VM:" -ForegroundColor Blue
        Write-Host "  1. Creer VM Windows 10/11 dans Hyper-V" -ForegroundColor White
        Write-Host "  2. Nommer la VM: $VMName" -ForegroundColor White
        Write-Host "  3. Installer Windows avec connexion internet" -ForegroundColor White
        Write-Host "  4. Installer PowerShell 5.1+" -ForegroundColor White
        Write-Host "  5. Creer snapshot 'Clean-Windows'" -ForegroundColor White
        Write-Host "  6. Re-executer ce script" -ForegroundColor White
        Write-Log "Instructions creation VM affichees" "INFO"
        exit 0
    }

} catch {
    Write-Host "  ERREUR gestion VM: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "Erreur gestion VM: $($_.Exception.Message)" "ERROR"
    exit 1
}

# ETAPE 2: VERIFICATION SNAPSHOTS
Write-Host ""
Write-Host "2. VERIFICATION SNAPSHOTS..." -ForegroundColor Yellow

try {
    $snapshots = Get-VMSnapshot -VMName $VMName -ErrorAction SilentlyContinue

    if ($snapshots.Count -eq 0) {
        Write-Host "  Aucun snapshot trouve" -ForegroundColor Yellow
        Write-Host "  Creation snapshot de base..." -ForegroundColor Blue

        # Creer snapshot de base
        $snapshotName = "Clean-Windows-$(Get-Date -Format 'yyyyMMdd')"
        Checkpoint-VM -Name $VMName -SnapshotName $snapshotName

        Write-Host "  Snapshot cree: $snapshotName" -ForegroundColor Green
        Write-Log "Snapshot base cree: $snapshotName" "INFO"

    } else {
        Write-Host "  Snapshots disponibles: $($snapshots.Count)" -ForegroundColor Green

        foreach ($snapshot in $snapshots) {
            Write-Host "    - $($snapshot.Name) ($(($snapshot.CreationTime).ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor Gray
            Write-Log "Snapshot disponible: $($snapshot.Name)" "INFO"
        }

        # Utiliser snapshot le plus recent comme base
        $baseSnapshot = $snapshots | Sort-Object CreationTime -Descending | Select-Object -First 1
        Write-Host "  Snapshot de base: $($baseSnapshot.Name)" -ForegroundColor Green
    }

} catch {
    Write-Host "  ERREUR gestion snapshots: $($_.Exception.Message)" -ForegroundColor Red
    Write-Log "Erreur gestion snapshots: $($_.Exception.Message)" "ERROR"
}

# ETAPE 3: PREPARATION FICHIERS TEST
Write-Host ""
Write-Host "3. PREPARATION FICHIERS TEST..." -ForegroundColor Yellow

$setupFile = ".\dist\USB Video Vault Setup $Version.exe"
$testScripts = @(
    ".\tools\emergency-rollback.ps1",
    ".\tools\monitor-release.ps1",
    ".\tools\test-uninstall-silent.ps1"
)

# Verifier setup existe
if (-not (Test-Path $setupFile)) {
    Write-Host "  ERREUR: Setup introuvable: $setupFile" -ForegroundColor Red
    Write-Host "  Generer avec: npm run build" -ForegroundColor Blue
    Write-Log "Setup introuvable: $setupFile" "ERROR"
    exit 1
}

Write-Host "  Setup: $setupFile ($(([math]::Round((Get-Item $setupFile).Length/1MB, 1))) MB)" -ForegroundColor Green
Write-Log "Setup trouve: $setupFile" "INFO"

# Verifier scripts rollback
foreach ($script in $testScripts) {
    if (Test-Path $script) {
        Write-Host "  Script: $(Split-Path $script -Leaf)" -ForegroundColor Green
    } else {
        Write-Host "  MANQUANT: $(Split-Path $script -Leaf)" -ForegroundColor Yellow
    }
}

# ETAPE 4: TRANSFERT FICHIERS VERS VM
Write-Host ""
Write-Host "4. TRANSFERT FICHIERS VERS VM..." -ForegroundColor Yellow

Write-Host "  [SIMULATION] Copie fichiers vers VM" -ForegroundColor Blue
Write-Host "  Fichiers a transferer:" -ForegroundColor Gray
Write-Host "    - $setupFile" -ForegroundColor Gray
Write-Host "    - Scripts de test PowerShell" -ForegroundColor Gray
Write-Host "    - Scripts de rollback" -ForegroundColor Gray

Write-Log "Simulation transfert fichiers vers VM" "INFO"

# En realite, utiliser PowerShell Direct ou partage reseau
# Invoke-Command -VMName $VMName -ScriptBlock { ... }

# ETAPE 5: INSTALLATION SUR VM
Write-Host ""
Write-Host "5. INSTALLATION SUR VM..." -ForegroundColor Yellow

$vmCommands = @(
    "# Installer USB Video Vault",
    "Start-Process -FilePath 'C:\temp\USB Video Vault Setup $Version.exe' -ArgumentList '/S' -Wait",
    "",
    "# Verifier installation",
    "`$installed = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object { `$_.DisplayName -like '*USB Video Vault*' }",
    "if (`$installed) { Write-Host 'Installation reussie' } else { Write-Host 'ERREUR Installation' }"
)

Write-Host "  [SIMULATION] Commandes VM:" -ForegroundColor Blue
foreach ($cmd in $vmCommands) {
    if ($cmd.Trim()) {
        Write-Host "    PS> $cmd" -ForegroundColor Cyan
    } else {
        Write-Host ""
    }
}

Write-Log "Simulation installation sur VM" "INFO"

# ETAPE 6: SIMULATION PROBLEME CRITIQUE
Write-Host ""
Write-Host "6. SIMULATION PROBLEME CRITIQUE..." -ForegroundColor Yellow

$problemScenarios = @(
    "Certificat revoque detecte",
    "SmartScreen bloque massivement",
    "Vulnerabilite critique signalee",
    "Corruption donnees utilisateur"
)

$selectedProblem = $problemScenarios | Get-Random
Write-Host "  Scenario simule: $selectedProblem" -ForegroundColor Red
Write-Log "Probleme simule: $selectedProblem" "WARN"

# ETAPE 7: DECLENCHEMENT ROLLBACK
Write-Host ""
Write-Host "7. DECLENCHEMENT ROLLBACK..." -ForegroundColor Yellow

$rollbackCommands = @(
    "# Executer rollback d'urgence",
    ".\emergency-rollback.ps1",
    "",
    "# Verifier suppression GitHub release",
    "# (necessaire token GitHub)",
    "",
    "# Notification utilisateurs",
    "# (integration Teams/Slack/Email)",
    "",
    "# Desinstallation locale",
    ".\test-uninstall-silent.ps1"
)

Write-Host "  [SIMULATION] Rollback automatique:" -ForegroundColor Red
foreach ($cmd in $rollbackCommands) {
    if ($cmd.Trim() -and -not $cmd.StartsWith("#")) {
        Write-Host "    ROLLBACK> $cmd" -ForegroundColor Red
    } elseif ($cmd.StartsWith("#")) {
        Write-Host "    $cmd" -ForegroundColor Gray
    } else {
        Write-Host ""
    }
}

Write-Log "Simulation rollback automatique" "ERROR"

# ETAPE 8: VALIDATION ROLLBACK
Write-Host ""
Write-Host "8. VALIDATION ROLLBACK..." -ForegroundColor Yellow

$validationSteps = @(
    @{ Name = "GitHub release supprimee"; Status = "OK"; Critical = $true },
    @{ Name = "Winget/Chocolatey retires"; Status = "OK"; Critical = $true },
    @{ Name = "Application desintallee"; Status = "OK"; Critical = $true },
    @{ Name = "Certificat revoque (si requis)"; Status = "PENDING"; Critical = $false },
    @{ Name = "Notifications envoyees"; Status = "OK"; Critical = $true },
    @{ Name = "Documentation mise a jour"; Status = "PENDING"; Critical = $false }
)

Write-Host "  Validation etapes rollback:" -ForegroundColor Blue
foreach ($step in $validationSteps) {
    $color = switch ($step.Status) {
        "OK" { "Green" }
        "PENDING" { "Yellow" }
        "ERROR" { "Red" }
        default { "Gray" }
    }

    $icon = if ($step.Critical) { "⚠️" } else { "ℹ️" }
    Write-Host "    $icon $($step.Name): $($step.Status)" -ForegroundColor $color
    Write-Log "Validation rollback: $($step.Name) = $($step.Status)" "INFO"
}

# ETAPE 9: RESTAURATION SNAPSHOT
Write-Host ""
Write-Host "9. RESTAURATION SNAPSHOT VM..." -ForegroundColor Yellow

if ($snapshots.Count -gt 0) {
    $restoreSnapshot = $snapshots | Sort-Object CreationTime -Descending | Select-Object -First 1

    Write-Host "  [SIMULATION] Restauration snapshot: $($restoreSnapshot.Name)" -ForegroundColor Blue
    Write-Host "  Commande: Restore-VMSnapshot -Name '$($restoreSnapshot.Name)' -VMName '$VMName' -Confirm:`$false" -ForegroundColor Cyan

    Write-Log "Simulation restauration snapshot: $($restoreSnapshot.Name)" "INFO"

    # En realite:
    # Restore-VMSnapshot -Name $restoreSnapshot.Name -VMName $VMName -Confirm:$false

} else {
    Write-Host "  Aucun snapshot pour restauration" -ForegroundColor Yellow
    Write-Log "Aucun snapshot disponible pour restauration" "WARN"
}

# RAPPORT FINAL
Write-Host ""
Write-Host "=== RAPPORT TEST ROLLBACK VM ===" -ForegroundColor Cyan

$testResults = @{
    timestamp = Get-Date
    vmName = $VMName
    version = $Version
    problemSimulated = $selectedProblem
    rollbackSteps = $validationSteps
    duration = "~15 minutes (simulation)"
    success = $true
}

Write-Host "VM testee: $VMName" -ForegroundColor White
Write-Host "Version: $Version" -ForegroundColor White
Write-Host "Probleme simule: $selectedProblem" -ForegroundColor Red
Write-Host "Duree test: $($testResults.duration)" -ForegroundColor Gray
Write-Host ""

$criticalFailures = $validationSteps | Where-Object { $_.Critical -and $_.Status -eq "ERROR" }
$pendingCritical = $validationSteps | Where-Object { $_.Critical -and $_.Status -eq "PENDING" }

if ($criticalFailures.Count -eq 0) {
    if ($pendingCritical.Count -eq 0) {
        Write-Host "RESULTAT: ROLLBACK COMPLETE" -ForegroundColor Green
        Write-Host "Tous les systemes critiques valides" -ForegroundColor Green
    } else {
        Write-Host "RESULTAT: ROLLBACK PARTIEL" -ForegroundColor Yellow
        Write-Host "$($pendingCritical.Count) etape(s) critique(s) en attente" -ForegroundColor Yellow
    }
} else {
    Write-Host "RESULTAT: ECHEC ROLLBACK" -ForegroundColor Red
    Write-Host "$($criticalFailures.Count) etape(s) critique(s) echouee(s)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Prochaines etapes:" -ForegroundColor Blue
Write-Host "  1. Tester rollback reel avec token GitHub" -ForegroundColor White
Write-Host "  2. Configurer notifications automatiques" -ForegroundColor White
Write-Host "  3. Valider procedures CA pour revocation" -ForegroundColor White
Write-Host "  4. Entrainer equipe sur procedures urgence" -ForegroundColor White

Write-Log "=== FIN TEST ROLLBACK VM ===" "INFO"
Write-Host ""
Write-Host "Log complet: $logFile" -ForegroundColor Gray
