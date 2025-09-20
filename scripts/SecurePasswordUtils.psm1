# Utilitaire de gestion sécurisée des mots de passe pour scripts de release
# Version: 1.0.0

<#
.SYNOPSIS
Utilitaires pour la gestion sécurisée des mots de passe dans les scripts de release.

.DESCRIPTION
Ce module fournit des fonctions pour convertir et gérer de manière sécurisée
les mots de passe utilisés pour les certificats de signature de code.

.EXAMPLE
# Convertir un mot de passe texte en SecureString
$securePassword = ConvertTo-SecurePassword -PlainTextPassword "monMotDePasse"

# Utiliser avec le script de release
.\create-release.ps1 -CertPath "cert.p12" -CertPassword $securePassword
#>

function ConvertTo-SecurePassword {
    <#
    .SYNOPSIS
    Convertit un mot de passe en texte brut en SecureString.
    
    .PARAMETER PlainTextPassword
    Le mot de passe en texte brut à convertir.
    
    .OUTPUTS
    SecureString - Le mot de passe sécurisé.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlainTextPassword
    )
    
    return ConvertTo-SecureString -String $PlainTextPassword -AsPlainText -Force
}

function Read-SecurePassword {
    <#
    .SYNOPSIS
    Demande un mot de passe de manière sécurisée à l'utilisateur.
    
    .PARAMETER Prompt
    Le message d'invite pour le mot de passe.
    
    .OUTPUTS
    SecureString - Le mot de passe saisi de manière sécurisée.
    #>
    [CmdletBinding()]
    param(
        [string]$Prompt = "Entrez le mot de passe du certificat"
    )
    
    return Read-Host -Prompt $Prompt -AsSecureString
}

function ConvertFrom-SecurePassword {
    <#
    .SYNOPSIS
    Convertit un SecureString en texte brut (à utiliser avec précaution).
    
    .PARAMETER SecurePassword
    Le mot de passe sécurisé à convertir.
    
    .OUTPUTS
    String - Le mot de passe en texte brut.
    
    .NOTES
    Cette fonction doit être utilisée avec précaution car elle expose
    le mot de passe en mémoire. Utilisez-la uniquement quand nécessaire
    pour l'interopérabilité avec des APIs qui n'acceptent pas SecureString.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [SecureString]$SecurePassword
    )
    
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
}

function Test-CertificatePassword {
    <#
    .SYNOPSIS
    Teste si un mot de passe est valide pour un certificat donné.
    
    .PARAMETER CertPath
    Le chemin vers le fichier de certificat (.p12/.pfx).
    
    .PARAMETER Password
    Le mot de passe à tester (SecureString).
    
    .OUTPUTS
    Boolean - True si le mot de passe est correct, False sinon.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CertPath,
        
        [Parameter(Mandatory = $true)]
        [SecureString]$Password
    )
    
    try {
        $plainPassword = ConvertFrom-SecurePassword -SecurePassword $Password
        $cert = Get-PfxCertificate -FilePath $CertPath -Password $Password
        return $true
    } catch {
        return $false
    }
}

# Exemples d'utilisation pour les développeurs
function Show-UsageExamples {
    Write-Host "=== Exemples d'utilisation ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Demander un mot de passe de manière sécurisée :" -ForegroundColor Yellow
    Write-Host '   $securePass = Read-SecurePassword -Prompt "Mot de passe certificat"'
    Write-Host ""
    Write-Host "2. Convertir un mot de passe texte :" -ForegroundColor Yellow
    Write-Host '   $securePass = ConvertTo-SecurePassword -PlainTextPassword "motdepasse"'
    Write-Host ""
    Write-Host "3. Utiliser avec le script de release :" -ForegroundColor Yellow
    Write-Host '   .\create-release.ps1 -CertPath "cert.p12" -CertPassword $securePass'
    Write-Host ""
    Write-Host "4. Tester un mot de passe :" -ForegroundColor Yellow
    Write-Host '   $isValid = Test-CertificatePassword -CertPath "cert.p12" -Password $securePass'
    Write-Host ""
}

# Export des fonctions publiques
Export-ModuleMember -Function @(
    'ConvertTo-SecurePassword',
    'Read-SecurePassword', 
    'ConvertFrom-SecurePassword',
    'Test-CertificatePassword',
    'Show-UsageExamples'
)