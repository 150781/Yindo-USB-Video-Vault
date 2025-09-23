# Journal d'Audit des Licences - USB Video Vault

## Vue d'ensemble

Système complet de traçabilité et audit pour toutes les opérations de licence.

## Structure Audit CSV

### Format Principal
```csv
licenseId,client,kid,expiration,fingerprint,usbSerial,sha256,issuedAt,issuedBy,deliveryPath,status,notes
```

### Champs Détaillés
- **licenseId** : UUID unique de la licence
- **client** : Nom/identifiant du client  
- **kid** : ID de la clé de signature utilisée
- **expiration** : Date d'expiration ISO 8601
- **fingerprint** : Empreinte machine complète
- **usbSerial** : Numéro série USB (optionnel)
- **sha256** : Hash SHA256 du fichier licence
- **issuedAt** : Timestamp d'émission ISO 8601
- **issuedBy** : Identifiant de l'opérateur
- **deliveryPath** : Chemin fichier livraison
- **status** : Statut (ISSUED, DELIVERED, ACTIVATED, REVOKED)
- **notes** : Notes complémentaires

## Script de Gestion Audit

```powershell
# scripts/license-audit.ps1
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("add", "search", "update", "report", "export")]
    [string]$Action,
    
    [string]$LicenseId = "",
    [string]$Client = "",
    [string]$AuditPath = ".\audit\license-audit.csv",
    [string]$OutputPath = ""
)

class LicenseAuditEntry {
    [string]$LicenseId
    [string]$Client
    [int]$Kid
    [string]$Expiration
    [string]$Fingerprint
    [string]$UsbSerial
    [string]$Sha256
    [string]$IssuedAt
    [string]$IssuedBy
    [string]$DeliveryPath
    [string]$Status
    [string]$Notes
    
    # Constructeur
    LicenseAuditEntry() {
        $this.LicenseId = (New-Guid).ToString()
        $this.IssuedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        $this.IssuedBy = $env:USERNAME
        $this.Status = "ISSUED"
    }
    
    # Conversion CSV
    [string] ToCsvLine() {
        return "$($this.LicenseId),$($this.Client),$($this.Kid),$($this.Expiration),$($this.Fingerprint),$($this.UsbSerial),$($this.Sha256),$($this.IssuedAt),$($this.IssuedBy),$($this.DeliveryPath),$($this.Status),$($this.Notes)"
    }
    
    # Validation
    [bool] IsValid() {
        return $this.LicenseId -and $this.Client -and $this.Fingerprint -and $this.Sha256
    }
}

function Initialize-AuditFile {
    param([string]$AuditPath)
    
    $directory = Split-Path $AuditPath -Parent
    if (-not (Test-Path $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }
    
    if (-not (Test-Path $AuditPath)) {
        $headers = "licenseId,client,kid,expiration,fingerprint,usbSerial,sha256,issuedAt,issuedBy,deliveryPath,status,notes"
        $headers | Out-File -FilePath $AuditPath -Encoding UTF8
        Write-Host "Fichier audit initialisé: $AuditPath" -ForegroundColor Green
    }
}

function Add-AuditEntry {
    param(
        [LicenseAuditEntry]$Entry,
        [string]$AuditPath
    )
    
    if (-not $Entry.IsValid()) {
        throw "Entrée audit invalide: champs obligatoires manquants"
    }
    
    Initialize-AuditFile -AuditPath $AuditPath
    
    # Vérifier unicité licenseId
    if (Test-LicenseExists -LicenseId $Entry.LicenseId -AuditPath $AuditPath) {
        throw "Licence déjà existante: $($Entry.LicenseId)"
    }
    
    # Ajouter entrée
    Add-Content -Path $AuditPath -Value $Entry.ToCsvLine()
    
    Write-Host "Entrée audit ajoutée: $($Entry.LicenseId)" -ForegroundColor Green
    return $Entry.LicenseId
}

function Test-LicenseExists {
    param([string]$LicenseId, [string]$AuditPath)
    
    if (-not (Test-Path $AuditPath)) {
        return $false
    }
    
    $content = Get-Content $AuditPath
    return $content | Where-Object { $_ -like "$LicenseId,*" }
}

function Search-AuditEntries {
    param(
        [string]$LicenseId = "",
        [string]$Client = "",
        [string]$Fingerprint = "",
        [string]$Status = "",
        [string]$AuditPath
    )
    
    if (-not (Test-Path $AuditPath)) {
        Write-Warning "Fichier audit non trouvé: $AuditPath"
        return @()
    }
    
    $entries = Import-Csv $AuditPath
    
    # Filtres
    if ($LicenseId) {
        $entries = $entries | Where-Object { $_.licenseId -like "*$LicenseId*" }
    }
    
    if ($Client) {
        $entries = $entries | Where-Object { $_.client -like "*$Client*" }
    }
    
    if ($Fingerprint) {
        $entries = $entries | Where-Object { $_.fingerprint -like "*$Fingerprint*" }
    }
    
    if ($Status) {
        $entries = $entries | Where-Object { $_.status -eq $Status }
    }
    
    return $entries
}

function Update-LicenseStatus {
    param(
        [string]$LicenseId,
        [string]$NewStatus,
        [string]$Notes = "",
        [string]$AuditPath
    )
    
    if (-not (Test-Path $AuditPath)) {
        throw "Fichier audit non trouvé: $AuditPath"
    }
    
    $entries = Import-Csv $AuditPath
    $found = $false
    
    foreach ($entry in $entries) {
        if ($entry.licenseId -eq $LicenseId) {
            $entry.status = $NewStatus
            if ($Notes) {
                $entry.notes = $Notes
            }
            $found = $true
            break
        }
    }
    
    if (-not $found) {
        throw "Licence non trouvée: $LicenseId"
    }
    
    # Réécrire le fichier
    $headers = "licenseId,client,kid,expiration,fingerprint,usbSerial,sha256,issuedAt,issuedBy,deliveryPath,status,notes"
    $headers | Out-File -FilePath $AuditPath -Encoding UTF8
    
    foreach ($entry in $entries) {
        $csvLine = "$($entry.licenseId),$($entry.client),$($entry.kid),$($entry.expiration),$($entry.fingerprint),$($entry.usbSerial),$($entry.sha256),$($entry.issuedAt),$($entry.issuedBy),$($entry.deliveryPath),$($entry.status),$($entry.notes)"
        Add-Content -Path $AuditPath -Value $csvLine
    }
    
    Write-Host "Statut mis à jour: $LicenseId -> $NewStatus" -ForegroundColor Green
}

function Export-AuditReport {
    param(
        [string]$AuditPath,
        [string]$OutputPath,
        [string]$Format = "HTML"
    )
    
    $entries = Import-Csv $AuditPath
    $totalEntries = $entries.Count
    
    # Statistiques
    $stats = @{
        Total = $totalEntries
        Issued = ($entries | Where-Object { $_.status -eq "ISSUED" }).Count
        Delivered = ($entries | Where-Object { $_.status -eq "DELIVERED" }).Count
        Activated = ($entries | Where-Object { $_.status -eq "ACTIVATED" }).Count
        Revoked = ($entries | Where-Object { $_.status -eq "REVOKED" }).Count
    }
    
    switch ($Format.ToUpper()) {
        "HTML" {
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Rapport Audit Licences - USB Video Vault</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .stats { display: flex; gap: 20px; margin: 20px 0; }
        .stat-box { background-color: #e8f4fd; padding: 10px; border-radius: 5px; text-align: center; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .status-ISSUED { color: #0066cc; }
        .status-DELIVERED { color: #ff8800; }
        .status-ACTIVATED { color: #008800; }
        .status-REVOKED { color: #cc0000; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Rapport Audit Licences USB Video Vault</h1>
        <p>Généré le $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") par $env:USERNAME</p>
    </div>
    
    <div class="stats">
        <div class="stat-box">
            <h3>$($stats.Total)</h3>
            <p>Total Licences</p>
        </div>
        <div class="stat-box">
            <h3>$($stats.Issued)</h3>
            <p>Émises</p>
        </div>
        <div class="stat-box">
            <h3>$($stats.Delivered)</h3>
            <p>Livrées</p>
        </div>
        <div class="stat-box">
            <h3>$($stats.Activated)</h3>
            <p>Activées</p>
        </div>
        <div class="stat-box">
            <h3>$($stats.Revoked)</h3>
            <p>Révoquées</p>
        </div>
    </div>
    
    <table>
        <thead>
            <tr>
                <th>License ID</th>
                <th>Client</th>
                <th>Kid</th>
                <th>Expiration</th>
                <th>Émis par</th>
                <th>Émis le</th>
                <th>Statut</th>
                <th>Notes</th>
            </tr>
        </thead>
        <tbody>
"@
            
            foreach ($entry in $entries) {
                $html += @"
            <tr>
                <td>$($entry.licenseId)</td>
                <td>$($entry.client)</td>
                <td>$($entry.kid)</td>
                <td>$($entry.expiration)</td>
                <td>$($entry.issuedBy)</td>
                <td>$($entry.issuedAt)</td>
                <td><span class="status-$($entry.status)">$($entry.status)</span></td>
                <td>$($entry.notes)</td>
            </tr>
"@
            }
            
            $html += @"
        </tbody>
    </table>
</body>
</html>
"@
            
            $html | Out-File -FilePath $OutputPath -Encoding UTF8
        }
        
        "JSON" {
            $report = @{
                generatedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                generatedBy = $env:USERNAME
                statistics = $stats
                entries = $entries
            }
            
            $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
        }
        
        default {
            throw "Format non supporté: $Format. Utilisez HTML ou JSON."
        }
    }
    
    Write-Host "Rapport exporté: $OutputPath" -ForegroundColor Green
}

# === LOGIQUE PRINCIPALE ===
switch ($Action) {
    "add" {
        throw "Utilisez le script license-workflow.ps1 pour ajouter des entrées"
    }
    
    "search" {
        $results = Search-AuditEntries -LicenseId $LicenseId -Client $Client -AuditPath $AuditPath
        
        if ($results.Count -eq 0) {
            Write-Host "Aucune entrée trouvée" -ForegroundColor Yellow
        } else {
            Write-Host "Trouvé $($results.Count) entrée(s):" -ForegroundColor Green
            $results | Format-Table -AutoSize
        }
    }
    
    "update" {
        if (-not $LicenseId) {
            throw "LicenseId requis pour la mise à jour"
        }
        
        $newStatus = Read-Host "Nouveau statut (ISSUED/DELIVERED/ACTIVATED/REVOKED)"
        $notes = Read-Host "Notes (optionnel)"
        
        Update-LicenseStatus -LicenseId $LicenseId -NewStatus $newStatus -Notes $notes -AuditPath $AuditPath
    }
    
    "report" {
        if (-not $OutputPath) {
            $OutputPath = ".\reports\license-audit-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
        }
        
        $directory = Split-Path $OutputPath -Parent
        if (-not (Test-Path $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }
        
        Export-AuditReport -AuditPath $AuditPath -OutputPath $OutputPath -Format "HTML"
    }
    
    "export" {
        if (-not $OutputPath) {
            $OutputPath = ".\exports\license-audit-export-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        }
        
        $directory = Split-Path $OutputPath -Parent
        if (-not (Test-Path $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }
        
        Export-AuditReport -AuditPath $AuditPath -OutputPath $OutputPath -Format "JSON"
    }
}
```

## Utilisation du Journal d'Audit

### Recherche d'Entrées
```powershell
# Rechercher par client
.\scripts\license-audit.ps1 -Action search -Client "ACME Corp"

# Rechercher par licence ID
.\scripts\license-audit.ps1 -Action search -LicenseId "abc123"

# Rechercher par statut
.\scripts\license-audit.ps1 -Action search | Where-Object { $_.status -eq "ACTIVATED" }
```

### Mise à jour Statut
```powershell
# Marquer comme livrée
.\scripts\license-audit.ps1 -Action update -LicenseId "abc123-def456"
# Saisir: DELIVERED
```

### Génération Rapports
```powershell
# Rapport HTML
.\scripts\license-audit.ps1 -Action report

# Export JSON
.\scripts\license-audit.ps1 -Action export -OutputPath "backup-audit.json"
```

## Intégration Workflow

### Automatisation
Le script `license-workflow.ps1` intègre automatiquement l'audit :

```powershell
# Émission avec audit automatique
.\scripts\license-workflow.ps1 -ClientName "ACME Corp" -Fingerprint "ABC123..."
```

### Suivi Lifecycle
1. **ISSUED** : Licence générée
2. **DELIVERED** : Archive transmise au client  
3. **ACTIVATED** : Installation confirmée côté client
4. **REVOKED** : Licence révoquée (si nécessaire)

## Sécurité et Compliance

### Intégrité
- Hash SHA256 de chaque licence
- Horodatage cryptographique
- Traçabilité complète des opérateurs

### Confidentialité  
- Mots de passe archives stockés séparément
- Accès audit restreint aux opérateurs autorisés
- Chiffrement des exports sensibles

### Archivage
- Sauvegarde quotidienne du fichier audit
- Rétention 7 ans minimum
- Export régulier vers système externe