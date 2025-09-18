# 📋 TASK SCHEDULER SETUP
Scripts pour automatiser les Day-2 Ops sur Windows et Linux

## Windows Task Scheduler

### 🕘 Opérations Quotidiennes (9h00)
```powershell
# Créer la tâche quotidienne
schtasks /Create /TN "USBVault-Daily-Ops" `
  /TR "powershell -ExecutionPolicy Bypass -File C:\USBVault\scripts\day2-ops\daily-ops.ps1" `
  /SC DAILY /ST 09:00 `
  /RU "SYSTEM" /RL HIGHEST `
  /F

# Vérifier la tâche
schtasks /Query /TN "USBVault-Daily-Ops"

# Test manuel
schtasks /Run /TN "USBVault-Daily-Ops"
```

### 🔴 Tests Red Team (Lundi 7h30)
```powershell
# Créer la tâche hebdomadaire
schtasks /Create /TN "USBVault-RedTeam-Weekly" `
  /TR "node C:\USBVault\test-red-scenarios.mjs --full" `
  /SC WEEKLY /D MON /ST 07:30 `
  /RU "SYSTEM" /RL HIGHEST `
  /F

# Vérifier
schtasks /Query /TN "USBVault-RedTeam-Weekly"
```

### 📊 Opérations Hebdomadaires (Vendredi 17h)
```powershell
# Créer la tâche hebdomadaire
schtasks /Create /TN "USBVault-Weekly-Ops" `
  /TR "powershell -ExecutionPolicy Bypass -File C:\USBVault\scripts\day2-ops\weekly-ops.ps1" `
  /SC WEEKLY /D FRI /ST 17:00 `
  /RU "SYSTEM" /RL HIGHEST `
  /F
```

### 🔧 Script d'installation automatique
```powershell
# install-scheduled-tasks.ps1
param(
    [string]$InstallPath = "C:\USBVault"
)

Write-Host "🚀 Installation tâches Day-2 Ops..."

# Vérifier chemin d'installation
if (-not (Test-Path $InstallPath)) {
    Write-Error "Chemin d'installation introuvable: $InstallPath"
    exit 1
}

# Supprimer tâches existantes
@("USBVault-Daily-Ops", "USBVault-Weekly-Ops", "USBVault-RedTeam-Weekly") | ForEach-Object {
    try {
        schtasks /Delete /TN $_ /F 2>$null
        Write-Host "✅ Supprimé: $_"
    } catch {
        Write-Host "ℹ️ Tâche inexistante: $_"
    }
}

# Créer nouvelles tâches
$tasks = @(
    @{
        Name = "USBVault-Daily-Ops"
        Command = "powershell -ExecutionPolicy Bypass -File $InstallPath\day2-ops-automation.mjs daily"
        Schedule = "DAILY"
        Time = "09:00"
    },
    @{
        Name = "USBVault-Weekly-Ops"  
        Command = "node $InstallPath\day2-ops-automation.mjs weekly"
        Schedule = "WEEKLY"
        Day = "FRI"
        Time = "17:00"
    },
    @{
        Name = "USBVault-RedTeam-Weekly"
        Command = "node $InstallPath\test-red-scenarios.mjs --full"
        Schedule = "WEEKLY" 
        Day = "MON"
        Time = "07:30"
    }
)

foreach ($task in $tasks) {
    try {
        $schedArgs = "/SC $($task.Schedule) /ST $($task.Time)"
        if ($task.Day) { $schedArgs += " /D $($task.Day)" }
        
        $createCmd = "schtasks /Create /TN `"$($task.Name)`" /TR `"$($task.Command)`" $schedArgs /RU SYSTEM /RL HIGHEST /F"
        
        Invoke-Expression $createCmd
        Write-Host "✅ Créé: $($task.Name)"
        
        # Test de la tâche
        schtasks /Query /TN $task.Name | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "🔍 Vérification OK: $($task.Name)"
        }
        
    } catch {
        Write-Error "❌ Échec création: $($task.Name) - $($_.Exception.Message)"
    }
}

Write-Host "`n📋 Tâches installées:"
schtasks /Query /FO LIST | Select-String "USBVault"

Write-Host "`n✅ Installation terminée!"
Write-Host "🔧 Commandes utiles:"
Write-Host "   - Lister: schtasks /Query | findstr USBVault"
Write-Host "   - Exécuter: schtasks /Run /TN USBVault-Daily-Ops"
Write-Host "   - Supprimer: schtasks /Delete /TN USBVault-Daily-Ops /F"
```

## Linux Cron

### 📝 Installation automatique
```bash
#!/bin/bash
# install-cron-jobs.sh

INSTALL_PATH="/opt/usbvault"
CRON_FILE="/etc/cron.d/usbvault-ops"

echo "🚀 Installation cron jobs Day-2 Ops..."

# Vérifier chemin d'installation
if [ ! -d "$INSTALL_PATH" ]; then
    echo "❌ Chemin d'installation introuvable: $INSTALL_PATH"
    exit 1
fi

# Créer fichier cron
cat > $CRON_FILE << EOF
# USB Video Vault Day-2 Operations
# Généré automatiquement le $(date)

# Opérations quotidiennes (9h00)
0 9 * * * root /usr/bin/node $INSTALL_PATH/day2-ops-automation.mjs daily >> /var/log/usbvault/daily.log 2>&1

# Tests Red Team (Lundi 7h30)  
30 7 * * 1 root /usr/bin/node $INSTALL_PATH/test-red-scenarios.mjs --full >> /var/log/usbvault/redteam.log 2>&1

# Opérations hebdomadaires (Vendredi 17h)
0 17 * * 5 root /usr/bin/node $INSTALL_PATH/day2-ops-automation.mjs weekly >> /var/log/usbvault/weekly.log 2>&1

# Nettoyage logs (Dimanche 2h)
0 2 * * 0 root find /var/log/usbvault -name "*.log" -mtime +30 -delete

EOF

# Créer répertoire logs
mkdir -p /var/log/usbvault
chown root:root /var/log/usbvault
chmod 755 /var/log/usbvault

# Permissions cron
chown root:root $CRON_FILE
chmod 644 $CRON_FILE

# Redémarrer cron
systemctl reload cron 2>/dev/null || service cron reload 2>/dev/null

echo "✅ Cron jobs installés dans: $CRON_FILE"
echo "📋 Jobs actifs:"
crontab -l 2>/dev/null | grep usbvault || echo "   (aucun job utilisateur)"
cat $CRON_FILE | grep -v "^#" | grep -v "^$"

echo ""
echo "🔧 Commandes utiles:"
echo "   - Voir logs: tail -f /var/log/usbvault/daily.log"
echo "   - Test manuel: $INSTALL_PATH/day2-ops-automation.mjs daily"
echo "   - Éditer cron: nano $CRON_FILE && systemctl reload cron"
```

## Verification & Monitoring

### 🔍 Script de vérification
```powershell
# verify-automation.ps1
Write-Host "🔍 === VÉRIFICATION AUTOMATION ===`n"

# Windows: Vérifier tâches programmées
Write-Host "📅 Tâches programmées:"
$usbTasks = schtasks /Query /FO CSV | ConvertFrom-Csv | Where-Object { $_.TaskName -like "*USBVault*" }

if ($usbTasks) {
    $usbTasks | ForEach-Object {
        $status = if ($_.Status -eq "Ready") { "✅" } else { "❌" }
        Write-Host "   $status $($_.TaskName) - $($_.Status)"
    }
} else {
    Write-Host "   ❌ Aucune tâche USBVault trouvée"
}

# Vérifier dernières exécutions
Write-Host "`n📊 Dernières exécutions:"
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational'; ID=201} -MaxEvents 10 -ErrorAction SilentlyContinue | 
    Where-Object { $_.Message -like "*USBVault*" } |
    ForEach-Object {
        Write-Host "   📅 $($_.TimeCreated): $($_.Message.Split('"')[1])"
    }

# Vérifier fichiers de logs/rapports
Write-Host "`n📄 Fichiers récents:"
@(".\logs\day2-ops", ".\reports\day2-ops") | ForEach-Object {
    if (Test-Path $_) {
        Get-ChildItem $_ -Filter "*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 3 | ForEach-Object {
            Write-Host "   📄 $($_.Name) - $($_.LastWriteTime)"
        }
    }
}

Write-Host "`n✅ Vérification terminée"
```

### 🚨 Monitoring des échecs
```bash
#!/bin/bash
# monitor-failures.sh

echo "🚨 === MONITORING ÉCHECS ==="

# Vérifier logs d'erreur récents
echo "📋 Erreurs récentes (24h):"
find /var/log/usbvault -name "*.log" -mtime -1 -exec grep -l "ERROR\|FAIL\|❌" {} \; | while read logfile; do
    echo "📄 $logfile:"
    grep "ERROR\|FAIL\|❌" "$logfile" | tail -5 | sed 's/^/   /'
done

# Vérifier cron jobs ratés
echo ""
echo "⏰ Cron jobs (dernière heure):"
journalctl -u cron --since "1 hour ago" | grep usbvault | tail -5

# Alertes critiques
echo ""
echo "🚨 Alertes critiques:"
if [ -f "/tmp/usbvault-alerts.log" ]; then
    cat /tmp/usbvault-alerts.log | tail -10
else
    echo "   ✅ Aucune alerte"
fi

echo ""
echo "✅ Monitoring terminé"
```

---

## 🎯 Installation Rapide

### Windows
```powershell
# Installation complète en une commande
.\install-scheduled-tasks.ps1 -InstallPath "C:\USBVault"
.\verify-automation.ps1
```

### Linux  
```bash
# Installation complète
sudo ./install-cron-jobs.sh
./monitor-failures.sh
```

**🔄 L'automatisation Day-2 Ops est maintenant active !**