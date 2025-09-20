# 🚨 Procédures d'Incident - USB Video Vault License

## 🕐 Problèmes d'Horloge Système

### 📋 Symptômes
```
❌ Erreur: "Horloge système invalide (rollback détecté)"
❌ Erreur: "Validation temporelle échouée"
❌ Application refuse de démarrer
❌ Licence semble valide mais application bloquée
```

### 🔧 Diagnostic Rapide
```powershell
# Vérifier horloge système
Get-Date

# Vérifier décalage NTP
w32tm /query /status

# Vérifier fuseau horaire
tzutil /g
```

### ✅ Correction Horloge

#### 1. **Synchronisation Automatique**
```powershell
# Activer sync automatique NTP
w32tm /config /manualpeerlist:"pool.ntp.org" /syncfromflags:manual /reliable:yes /update
w32tm /resync /force

# Vérifier synchronisation
w32tm /query /status | Select-String "Last Successful Sync Time"
```

#### 2. **Correction Manuelle**
```powershell
# Si pas d'accès internet, correction manuelle
Set-Date "2025-09-19 15:30:00"

# Vérifier fuseau horaire correct
tzutil /s "Romance Standard Time"  # France
```

#### 3. **Reset State License**
```powershell
# ATTENTION: Perte de l'état anti-rollback
Remove-Item "$env:APPDATA\USB Video Vault\.license_state.json" -Force
Write-Host "State license réinitialisé - redémarrer l'application"
```

### ⚠️ Procédure d'Urgence
```powershell
# Script correction horloge + reset state
$correctTime = "2025-09-19 15:30:00"  # Ajuster date/heure correcte
Set-Date $correctTime
Remove-Item "$env:APPDATA\USB Video Vault\.license_state.json" -Force -ErrorAction SilentlyContinue
Write-Host "Correction d'urgence appliquée - relancer l'application"
```

## 🔄 Problèmes de Binding (Machine/USB)

### 📋 Symptômes
```
❌ Erreur: "Machine fingerprint invalide"
❌ Erreur: "USB binding échoué"
❌ Licence valide mais refusée après changement matériel
❌ Migration vers nouveau poste/USB
```

### 🔍 Diagnostic Binding

#### Script Diagnostic
```powershell
# scripts/diagnose-binding.ps1
Write-Host "DIAGNOSTIC BINDING - USB Video Vault" -ForegroundColor Cyan

# Empreinte machine actuelle
$fingerprint = & node scripts/print-bindings.mjs | Select-String "Fingerprint" | Out-String
Write-Host "Machine fingerprint:" -ForegroundColor Yellow
Write-Host $fingerprint

# USB série actuel
$usbSerial = & node scripts/print-bindings.mjs | Select-String "USB" | Out-String
Write-Host "USB serial:" -ForegroundColor Yellow  
Write-Host $usbSerial

# Licence actuelle
$licensePath = "$env:USERPROFILE\Documents\vault\.vault\license.bin"
if (Test-Path $licensePath) {
    Write-Host "Licence trouvée: $licensePath" -ForegroundColor Green
    & node scripts/verify-license.mjs $licensePath
} else {
    Write-Host "Licence non trouvée: $licensePath" -ForegroundColor Red
}
```

### ✅ Correction Binding

#### 1. **Changement Machine (même USB)**
```powershell
# 1. Récupérer nouvelle empreinte
& node scripts/print-bindings.mjs > new-fingerprint.txt

# 2. Envoyer new-fingerprint.txt à l'administrateur
# 3. Administrateur génère nouvelle licence
# 4. Remplacer license.bin avec nouvelle licence
```

#### 2. **Changement USB (même machine)**
```powershell
# 1. Brancher nouveau USB sur même port si possible
# 2. Récupérer nouvelle empreinte
& node scripts/print-bindings.mjs > new-fingerprint.txt

# 3. Si binding USB strict, regénération licence nécessaire
```

#### 3. **Migration Complète (machine + USB)**
```powershell
# 1. Sur nouvelle machine avec nouveau USB
& node scripts/print-bindings.mjs > migration-fingerprint.txt

# 2. Envoyer à l'administrateur avec justification
# 3. Génération licence complètement nouvelle
# 4. Désactiver ancienne licence si nécessaire
```

### 🚀 Regénération Express
```powershell
# Template pour demande regénération
Write-Host @"
DEMANDE REGENERATION LICENCE
============================
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
Utilisateur: $env:USERNAME
Machine: $env:COMPUTERNAME
Raison: [Changement matériel/Migration/Incident horloge]

Nouvelle empreinte:
$(& node scripts/print-bindings.mjs 2>$null)

Action demandée: Regénération licence urgente
"@
```

## 🔒 Problèmes Licence Expirée

### 📋 Symptômes
```
⚠️ "Licence expire dans X jours"
❌ "Licence expirée"
❌ Application refuse l'accès aux médias
```

### ✅ Procédure Renouvellement

#### 1. **Vérification Expiration**
```powershell
# Vérifier détails licence actuelle
& node scripts/verify-license.mjs "$env:USERPROFILE\Documents\vault\.vault\license.bin"
```

#### 2. **Demande Renouvellement (≤30 jours)**
```powershell
# Template demande renouvellement
$licenseInfo = & node scripts/verify-license.mjs "$env:USERPROFILE\Documents\vault\.vault\license.bin" 2>$null

Write-Host @"
DEMANDE RENOUVELLEMENT LICENCE
==============================
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
Utilisateur: $env:USERNAME
Machine: $env:COMPUTERNAME

Licence actuelle:
$licenseInfo

Statut: Expire bientôt - renouvellement requis
Action: Générer nouvelle licence avec même binding
"@
```

#### 3. **Urgence (licence expirée)**
```powershell
# Si licence expirée, pas de bypass possible
# Contacter administrateur en urgence avec empreinte actuelle
& node scripts/print-bindings.mjs > urgence-binding.txt
Write-Host "Fichier urgence-binding.txt créé - transmettre immédiatement à l'administrateur"
```

## 📞 Contacts Urgence

### 🏢 Support Technique
```
Administrateur Licence: [CONTACT_ADMIN]
Support IT: [CONTACT_IT]  
Escalade: [CONTACT_MANAGER]
```

### ⏰ Niveaux Urgence
```
🔴 P0 - CRITIQUE: Application bloquée, production arrêtée
🟡 P1 - URGENT: Expire dans <7 jours
🟢 P2 - PLANIFIÉ: Expire dans 7-30 jours
```

### 📋 Informations à Fournir
```
✅ Date/heure incident
✅ Message d'erreur exact
✅ Fichier empreinte (print-bindings.mjs)
✅ Logs application (%APPDATA%\USB Video Vault\logs)
✅ État before/after (changement matériel, heure, etc.)
✅ Impact métier (utilisateurs bloqués, production)
```

## 🛠️ Scripts d'Urgence

### 📁 `scripts/emergency-reset.ps1`
```powershell
#!/usr/bin/env pwsh
# Reset d'urgence - license state + horloge

param(
    [string]$CorrectDateTime = "",
    [switch]$Force
)

Write-Host "RESET D'URGENCE - USB Video Vault" -ForegroundColor Red
Write-Host "=================================" -ForegroundColor Red

if (-not $Force) {
    $confirm = Read-Host "ATTENTION: Reset complet (O/N)"
    if ($confirm -ne "O") { exit 0 }
}

# 1. Arrêter application si en cours
Get-Process "USB Video Vault" -ErrorAction SilentlyContinue | Stop-Process -Force

# 2. Corriger horloge si spécifiée
if ($CorrectDateTime) {
    Write-Host "Correction horloge: $CorrectDateTime" -ForegroundColor Yellow
    Set-Date $CorrectDateTime
}

# 3. Reset state license
$statePath = "$env:APPDATA\USB Video Vault\.license_state.json"
if (Test-Path $statePath) {
    Remove-Item $statePath -Force
    Write-Host "License state réinitialisé" -ForegroundColor Yellow
}

# 4. Sync NTP si possible
Write-Host "Tentative sync NTP..." -ForegroundColor Yellow
w32tm /resync /force 2>$null

# 5. Générer rapport incident
$reportPath = "incident-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
@"
RAPPORT INCIDENT - $(Get-Date)
=============================
Machine: $env:COMPUTERNAME
Utilisateur: $env:USERNAME
Heure correction: $CorrectDateTime
State reset: Oui

Nouvelle empreinte:
$(& node scripts/print-bindings.mjs 2>$null)

Actions requises:
1. Vérifier horloge système correcte
2. Regénérer licence si binding changé
3. Tester application après redémarrage
"@ | Out-File $reportPath

Write-Host "`nReset terminé - rapport: $reportPath" -ForegroundColor Green
Write-Host "1. Redémarrer l'application" -ForegroundColor Cyan
Write-Host "2. Si erreur persiste, envoyer rapport à l'administrateur" -ForegroundColor Cyan
```

---

**🚨 Procédures d'incident validées et prêtes**  
**⏰ Correction horloge + reset state automatisés**  
**🔄 Regénération binding documentée étape par étape**  
**📞 Escalade et contacts définis**