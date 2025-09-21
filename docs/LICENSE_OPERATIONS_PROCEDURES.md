# Procédures Standardisées - Opérations Licence USB Video Vault

## Vue d'ensemble

Workflow complet pour la gestion des licences clients : collecte empreinte → émission → vérification → livraison sécurisée.

## 1. Collecte Empreinte Client

### Script de Collecte
```bash
# Côté client - Collecte automatique
node scripts/print-bindings.mjs > client-fingerprint.txt
```

### Informations Collectées
- **machineFingerprint** : Empreinte unique de la machine
- **usbSerial** : Numéro série du périphérique USB (optionnel)
- **systemInfo** : Informations système pour validation

### Format de Sortie
```json
{
  "machineFingerprint": "ABC123DEF456789...",
  "usbSerial": "USB_1234567890", 
  "systemInfo": {
    "hostname": "CLIENT-PC",
    "os": "Windows 10",
    "architecture": "x64"
  },
  "collectedAt": "2025-09-20T10:30:00Z"
}
```

## 2. Émission de Licence

### Commande Standard
```bash
# Licence machine uniquement
node scripts/make-license.mjs "<FINGERPRINT>" --kid 1 --exp "2026-12-31T23:59:59Z"

# Licence avec USB spécifique
node scripts/make-license.mjs "<FINGERPRINT>" "USB_SERIAL" --kid 1 --exp "2026-12-31T23:59:59Z"

# Options avancées
node scripts/make-license.mjs "<FINGERPRINT>" --kid 2 --exp "2025-12-31T23:59:59Z" --features "premium,analytics"
```

### Paramètres
- **FINGERPRINT** : Empreinte machine du client
- **USB_SERIAL** : Numéro série USB (optionnel)
- **--kid** : ID de la clé de signature (1=prod, 2=test)
- **--exp** : Date d'expiration ISO 8601
- **--features** : Fonctionnalités activées (optionnel)

## 3. Vérification de Licence

### Validation Automatique
```bash
# Vérification standard
node scripts/verify-license.mjs ".\out\license.bin"

# Vérification avec détails
node scripts/verify-license.mjs ".\out\license.bin" --verbose

# Vérification avec empreinte spécifique
node scripts/verify-license.mjs ".\out\license.bin" --fingerprint "<FINGERPRINT>"
```

### Calcul Signature
```bash
# Hash SHA256 pour traçabilité
CertUtil -hashfile ".\out\license.bin" SHA256
```

## 4. Livraison Sécurisée

### Packaging 7-Zip Chiffré
```bash
# Création archive chiffrée
7z a -p -mhe ".\deliveries\clientX-license.zip" ".\out\license.bin"

# Options avancées
7z a -p -mhe -mx9 ".\deliveries\client-COMPANY-20250920.zip" ".\out\license.bin" "installation-guide.pdf"
```

### Transmission Sécurisée
1. **Archive** : Fichier 7z avec mot de passe
2. **Mot de passe** : Envoyé par canal séparé (SMS, email séparé, téléphone)
3. **Checksum** : SHA256 pour vérification intégrité

## Workflow Complet

### Script d'Orchestration
```powershell
# scripts/license-workflow.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$ClientName,
    
    [Parameter(Mandatory=$true)] 
    [string]$Fingerprint,
    
    [string]$UsbSerial = "",
    [int]$KeyId = 1,
    [string]$Expiration = "2026-12-31T23:59:59Z",
    [string]$Features = "",
    [switch]$Verbose
)

function Write-WorkflowLog {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    
    # Log vers fichier audit
    Add-Content -Path ".\logs\license-workflow.log" -Value $logMessage
}

function New-LicenseForClient {
    param(
        [string]$ClientName,
        [string]$Fingerprint, 
        [string]$UsbSerial,
        [int]$KeyId,
        [string]$Expiration,
        [string]$Features
    )
    
    Write-WorkflowLog "=== DÉBUT ÉMISSION LICENCE POUR $ClientName ==="
    
    # 1. Validation des paramètres
    if (-not $Fingerprint -or $Fingerprint.Length -lt 32) {
        throw "Fingerprint invalide: $Fingerprint"
    }
    
    # 2. Génération de la licence
    Write-WorkflowLog "Génération licence..."
    $licenseCmd = "node scripts/make-license.mjs `"$Fingerprint`""
    
    if ($UsbSerial) {
        $licenseCmd += " `"$UsbSerial`""
    }
    
    $licenseCmd += " --kid $KeyId --exp `"$Expiration`""
    
    if ($Features) {
        $licenseCmd += " --features `"$Features`""
    }
    
    Write-WorkflowLog "Commande: $licenseCmd"
    $result = Invoke-Expression $licenseCmd
    
    if ($LASTEXITCODE -ne 0) {
        throw "Erreur génération licence: $result"
    }
    
    # 3. Vérification de la licence
    Write-WorkflowLog "Vérification licence..."
    $verifyResult = & node scripts/verify-license.mjs ".\out\license.bin"
    
    if ($LASTEXITCODE -ne 0) {
        throw "Erreur vérification licence: $verifyResult"
    }
    
    # 4. Calcul signature
    Write-WorkflowLog "Calcul signature..."
    $sha256 = (CertUtil -hashfile ".\out\license.bin" SHA256 | Select-String -Pattern "[A-F0-9]{64}").Matches[0].Value
    
    # 5. Packaging sécurisé
    Write-WorkflowLog "Packaging sécurisé..."
    $deliveryPath = ".\deliveries\$ClientName-license-$(Get-Date -Format 'yyyyMMdd').zip"
    
    # Générer mot de passe aléatoire
    $password = -join ((33..126) | Get-Random -Count 16 | ForEach-Object {[char]$_})
    
    # Créer archive chiffrée
    & 7z a -p"$password" -mhe "$deliveryPath" ".\out\license.bin" | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        throw "Erreur création archive sécurisée"
    }
    
    # 6. Enregistrement audit
    $auditEntry = @{
        licenseId = (New-Guid).ToString()
        client = $ClientName
        fingerprint = $Fingerprint
        usbSerial = $UsbSerial
        keyId = $KeyId
        expiration = $Expiration
        features = $Features
        sha256 = $sha256
        issuedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        issuedBy = $env:USERNAME
        deliveryPath = $deliveryPath
        password = $password
    }
    
    Add-AuditEntry -Entry $auditEntry
    
    Write-WorkflowLog "=== LICENCE ÉMISE AVEC SUCCÈS ==="
    Write-WorkflowLog "Fichier: $deliveryPath"
    Write-WorkflowLog "SHA256: $sha256"
    Write-WorkflowLog "Mot de passe: $password"
    
    return $auditEntry
}

function Add-AuditEntry {
    param([object]$Entry)
    
    $auditPath = ".\audit\license-audit.csv"
    
    # Créer le fichier avec en-têtes si inexistant
    if (-not (Test-Path $auditPath)) {
        $headers = "licenseId,client,kid,expiration,fingerprint,usbSerial,sha256,issuedAt,issuedBy,deliveryPath"
        $headers | Out-File -FilePath $auditPath -Encoding UTF8
    }
    
    # Ajouter l'entrée
    $csvLine = "$($Entry.licenseId),$($Entry.client),$($Entry.keyId),$($Entry.expiration),$($Entry.fingerprint),$($Entry.usbSerial),$($Entry.sha256),$($Entry.issuedAt),$($Entry.issuedBy),$($Entry.deliveryPath)"
    Add-Content -Path $auditPath -Value $csvLine
    
    Write-WorkflowLog "Entrée audit ajoutée: $($Entry.licenseId)"
}

# === EXÉCUTION PRINCIPALE ===
try {
    # Assurer que les dossiers existent
    @(".\out", ".\deliveries", ".\audit", ".\logs") | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -Path $_ -ItemType Directory -Force | Out-Null
        }
    }
    
    # Générer la licence
    $licenseInfo = New-LicenseForClient -ClientName $ClientName -Fingerprint $Fingerprint -UsbSerial $UsbSerial -KeyId $KeyId -Expiration $Expiration -Features $Features
    
    # Afficher résumé
    Write-Host "`n=== RÉSUMÉ ÉMISSION LICENCE ===" -ForegroundColor Green
    Write-Host "Client: $($licenseInfo.client)" -ForegroundColor Yellow
    Write-Host "License ID: $($licenseInfo.licenseId)" -ForegroundColor Yellow
    Write-Host "Fichier: $($licenseInfo.deliveryPath)" -ForegroundColor Yellow
    Write-Host "SHA256: $($licenseInfo.sha256)" -ForegroundColor Yellow
    Write-Host "`nMot de passe archive: $($licenseInfo.password)" -ForegroundColor Red
    Write-Host "(À transmettre par canal séparé)" -ForegroundColor Red
    
} catch {
    Write-WorkflowLog "ERREUR: $($_.Exception.Message)" "ERROR"
    exit 1
}
```

## Checklist Opérationnelle

### Avant Émission
- [ ] Validation identité client
- [ ] Réception empreinte machine
- [ ] Vérification format fingerprint
- [ ] Validation date d'expiration
- [ ] Autorisation émission

### Pendant Émission  
- [ ] Génération licence réussie
- [ ] Vérification signature
- [ ] Calcul checksum SHA256
- [ ] Création archive chiffrée
- [ ] Enregistrement audit

### Après Émission
- [ ] Transmission archive client
- [ ] Envoi mot de passe (canal séparé)
- [ ] Confirmation réception
- [ ] Test installation client
- [ ] Archivage documentation

## Sécurité

### Bonnes Pratiques
- **Séparation** : Archive et mot de passe par canaux différents
- **Traçabilité** : Audit complet de chaque émission
- **Vérification** : Checksum SHA256 systématique
- **Expiration** : Dates d'expiration appropriées
- **Accès** : Restriction opérateurs autorisés

### Audit Trail
Chaque émission génère une trace complète dans `license-audit.csv` :
```csv
licenseId,client,kid,expiration,fingerprint,usbSerial,sha256,issuedAt,issuedBy,deliveryPath
uuid-1234,ClientA,1,2026-12-31T23:59:59Z,ABC123...,USB_789,sha256hash,2025-09-20T10:30:00Z,operator1,./deliveries/ClientA-license.zip
```