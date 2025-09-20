# Helper script pour la gestion sécurisée des mots de passe
# Usage: .\helper-secure-password.ps1

function New-SecurePassword {
    <#
    .SYNOPSIS
    Crée un mot de passe sécurisé pour utilisation dans les scripts
    
    .DESCRIPTION
    Ce helper permet de créer et stocker de manière sécurisée les mots de passe
    pour les certificats de signature de code.
    
    .EXAMPLE
    $securePassword = New-SecurePassword
    .\create-release.ps1 -CertPath "certificate.p12" -CertPassword $securePassword
    #>
    
    Write-Host "=== Helper - Mot de passe sécurisé ===" -ForegroundColor Cyan
    Write-Host "Entrez le mot de passe du certificat:" -ForegroundColor Yellow
    
    $securePassword = Read-Host -AsSecureString
    
    Write-Host "✅ Mot de passe sécurisé créé" -ForegroundColor Green
    Write-Host "Utilisez cette variable dans vos scripts:" -ForegroundColor White
    Write-Host '$securePassword' -ForegroundColor Yellow
    
    return $securePassword
}

function Export-SecurePassword {
    <#
    .SYNOPSIS
    Exporte un mot de passe sécurisé vers un fichier crypté
    
    .DESCRIPTION
    Sauvegarde le mot de passe de manière sécurisée pour réutilisation
    Attention: Le fichier ne peut être déchiffré que par le même utilisateur sur la même machine
    
    .PARAMETER SecurePassword
    Le mot de passe sécurisé à exporter
    
    .PARAMETER FilePath
    Le chemin où sauvegarder le fichier crypté
    
    .EXAMPLE
    $securePassword = Read-Host -AsSecureString
    Export-SecurePassword -SecurePassword $securePassword -FilePath "cert-password.txt"
    #>
    
    param(
        [Parameter(Mandatory)]
        [SecureString]$SecurePassword,
        
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    try {
        $SecurePassword | ConvertFrom-SecureString | Set-Content -Path $FilePath
        Write-Host "✅ Mot de passe exporté vers: $FilePath" -ForegroundColor Green
        Write-Host "⚠️  Ce fichier ne peut être lu que par $env:USERNAME sur $env:COMPUTERNAME" -ForegroundColor Yellow
    } catch {
        Write-Host "❌ Erreur lors de l'export: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Import-SecurePassword {
    <#
    .SYNOPSIS
    Importe un mot de passe sécurisé depuis un fichier crypté
    
    .DESCRIPTION
    Charge un mot de passe précédemment sauvegardé
    
    .PARAMETER FilePath
    Le chemin du fichier crypté contenant le mot de passe
    
    .EXAMPLE
    $securePassword = Import-SecurePassword -FilePath "cert-password.txt"
    .\create-release.ps1 -CertPath "certificate.p12" -CertPassword $securePassword
    #>
    
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    try {
        if (-not (Test-Path $FilePath)) {
            throw "Fichier non trouvé: $FilePath"
        }
        
        $securePassword = Get-Content -Path $FilePath | ConvertTo-SecureString
        Write-Host "✅ Mot de passe importé depuis: $FilePath" -ForegroundColor Green
        return $securePassword
        
    } catch {
        Write-Host "❌ Erreur lors de l'import: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Show-SecureUsageExamples {
    <#
    .SYNOPSIS
    Affiche des exemples d'utilisation sécurisée
    #>
    
    Write-Host @"
=== Exemples d'utilisation sécurisée ===

1. Création interactive d'un mot de passe sécurisé:
   `$securePassword = New-SecurePassword
   .\create-release.ps1 -CertPath "certificate.p12" -CertPassword `$securePassword

2. Sauvegarde du mot de passe pour réutilisation:
   `$securePassword = Read-Host -AsSecureString -Prompt "Mot de passe certificat"
   Export-SecurePassword -SecurePassword `$securePassword -FilePath "cert-password.secure"

3. Réutilisation du mot de passe sauvegardé:
   `$securePassword = Import-SecurePassword -FilePath "cert-password.secure"
   .\create-release.ps1 -CertPath "certificate.p12" -CertPassword `$securePassword

4. Release en mode test (sans certificat commercial):
   .\create-release.ps1 -TestMode

5. Release production complète:
   `$securePassword = Import-SecurePassword -FilePath "prod-cert-password.secure"
   .\create-release.ps1 -Version "1.0.4" -CertPath "prod-certificate.p12" -CertPassword `$securePassword

=== Sécurité ===
- Les fichiers .secure ne peuvent être déchiffrés que par l'utilisateur qui les a créés
- Ne jamais commiter les fichiers .secure dans Git
- Utiliser toujours SecureString pour les mots de passe en paramètres
"@ -ForegroundColor White
}

# Interface interactive si le script est exécuté directement
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "=== Helper - Gestion sécurisée des mots de passe ===" -ForegroundColor Cyan
    Write-Host ""
    
    $choice = Read-Host @"
Choisissez une action:
1. Créer un mot de passe sécurisé interactif
2. Sauvegarder un mot de passe dans un fichier crypté
3. Charger un mot de passe depuis un fichier crypté
4. Afficher les exemples d'utilisation
5. Quitter

Votre choix (1-5)
"@

    switch ($choice) {
        "1" { 
            $securePassword = New-SecurePassword
            Write-Host "Le mot de passe est maintenant disponible dans la variable `$securePassword" -ForegroundColor Green
        }
        "2" { 
            $securePassword = Read-Host -AsSecureString -Prompt "Entrez le mot de passe à sauvegarder"
            $filePath = Read-Host -Prompt "Nom du fichier de sauvegarde (ex: cert-password.secure)"
            Export-SecurePassword -SecurePassword $securePassword -FilePath $filePath
        }
        "3" { 
            $filePath = Read-Host -Prompt "Chemin du fichier crypté"
            $securePassword = Import-SecurePassword -FilePath $filePath
            if ($securePassword) {
                Write-Host "Le mot de passe est maintenant disponible dans la variable `$securePassword" -ForegroundColor Green
            }
        }
        "4" { 
            Show-SecureUsageExamples 
        }
        "5" { 
            Write-Host "Au revoir!" -ForegroundColor Green 
        }
        default { 
            Write-Host "Choix invalide" -ForegroundColor Red 
        }
    }
}