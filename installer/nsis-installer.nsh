# Script NSIS personnalisé pour USB Video Vault
# Crée automatiquement le répertoire vault et exécute le script post-install

!include "MUI2.nsh"
!include "FileFunc.nsh"

# Macros pour les fonctions personnalisées
!macro CreateVaultDirectory
  # Déterminer le chemin du vault
  ReadEnvStr $R0 "VAULT_PATH"
  StrCmp $R0 "" 0 VaultPathExists
  
  # Utiliser le chemin par défaut si VAULT_PATH n'existe pas
  StrCpy $R0 "$DOCUMENTS\Yindo-USB-Video-Vault\vault-real"
  
  VaultPathExists:
  # Créer le répertoire principal du vault
  CreateDirectory "$R0"
  
  # Créer le répertoire .vault
  CreateDirectory "$R0\.vault"
  
  # Définir VAULT_PATH dans l'environnement utilisateur
  WriteRegStr HKCU "Environment" "VAULT_PATH" "$R0"
  
  # Notifier le système du changement d'environnement
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
!macroend

# Fonction exécutée après l'installation
Function .onInstSuccess
  # Créer les répertoires vault
  !insertmacro CreateVaultDirectory
  
  # Vérifier si un fichier licence existe dans le répertoire d'installation
  IfFileExists "$INSTDIR\license.bin" 0 NoLicenseFile
  
  # Exécuter le script post-install si la licence existe
  ExecWait 'powershell.exe -ExecutionPolicy Bypass -File "$INSTDIR\scripts\post-install-simple.ps1" -LicenseSource "$INSTDIR\license.bin"'
  Goto PostInstallDone
  
  NoLicenseFile:
  # Afficher un message informatif si pas de licence
  MessageBox MB_ICONINFORMATION "Installation terminée.$\n$\nLe répertoire vault a été créé, mais aucun fichier licence n'a été trouvé.$\n$\nVous devrez installer la licence manuellement en utilisant le script post-install."
  
  PostInstallDone:
FunctionEnd

# Fonction de désinstallation personnalisée
Function un.onInit
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Voulez-vous également supprimer les données du vault et la configuration ?" IDYES true IDNO false
  true:
    # Lire VAULT_PATH
    ReadRegStr $R0 HKCU "Environment" "VAULT_PATH"
    StrCmp $R0 "" VaultPathEmpty
    
    # Demander confirmation pour supprimer le vault
    MessageBox MB_ICONEXCLAMATION|MB_YESNO|MB_DEFBUTTON2 "ATTENTION: Ceci supprimera définitivement tous vos médias et données dans:$\n$R0$\n$\nÊtes-vous sûr ?" IDYES DeleteVault
    Goto VaultPathEmpty
    
    DeleteVault:
    RMDir /r "$R0"
    DeleteRegValue HKCU "Environment" "VAULT_PATH"
    
  VaultPathEmpty:
  false:
FunctionEnd

# Configuration des pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "French"