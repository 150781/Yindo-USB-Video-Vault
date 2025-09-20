; Script Inno Setup pour USB Video Vault
; Crée automatiquement le vault et installe la licence

[Setup]
AppId={{A2B3C4D5-E6F7-8901-2345-6789ABCDEF00}
AppName=USB Video Vault
AppVersion=1.0.3
AppVerName=USB Video Vault 1.0.3
AppPublisher=Yindo
AppPublisherURL=https://github.com/150781/Yindo-USB-Video-Vault
DefaultDirName={autopf}\USB Video Vault
DisableProgramGroupPage=yes
LicenseFile=LICENSE
OutputDir=release
OutputBaseFilename=USB-Video-Vault-1.0.3-setup
SetupIconFile=build\icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
CreateAppDir=yes
AllowNoIcons=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "createvault"; Description: "Créer automatiquement le répertoire vault"; GroupDescription: "Configuration:"; Flags: checkedonce

[Files]
Source: "dist\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "scripts\post-install-simple.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "license.bin"; DestDir: "{app}"; Flags: ignoreversion external skipifsourcedoesntexist

[Icons]
Name: "{autoprograms}\USB Video Vault"; Filename: "{app}\USB Video Vault.exe"
Name: "{autodesktop}\USB Video Vault"; Filename: "{app}\USB Video Vault.exe"; Tasks: desktopicon

[Code]
var
  VaultPath: string;

function GetVaultPath(): string;
var
  EnvVaultPath: string;
begin
  // Vérifier si VAULT_PATH existe
  if RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'VAULT_PATH', EnvVaultPath) then
  begin
    Result := EnvVaultPath;
  end
  else
  begin
    // Utiliser le chemin par défaut
    Result := ExpandConstant('{userdocs}\Yindo-USB-Video-Vault\vault-real');
  end;
end;

procedure CreateVaultDirectory();
var
  VaultDir: string;
  VaultConfigDir: string;
begin
  VaultDir := GetVaultPath();
  VaultConfigDir := VaultDir + '\.vault';
  
  // Créer les répertoires
  if not DirExists(VaultDir) then
    ForceDirectories(VaultDir);
    
  if not DirExists(VaultConfigDir) then
    ForceDirectories(VaultConfigDir);
    
  // Définir VAULT_PATH dans l'environnement
  RegWriteStringValue(HKEY_CURRENT_USER, 'Environment', 'VAULT_PATH', VaultDir);
  
  // Log du succès
  Log(Format('Vault créé: %s', [VaultDir]));
end;

procedure RunPostInstallScript();
var
  ResultCode: Integer;
  PowerShellCmd: string;
  LicensePath: string;
begin
  LicensePath := ExpandConstant('{app}\license.bin');
  
  // Vérifier si le fichier licence existe
  if FileExists(LicensePath) then
  begin
    PowerShellCmd := Format('powershell.exe -ExecutionPolicy Bypass -File "%s\scripts\post-install-simple.ps1" -LicenseSource "%s"',
                           [ExpandConstant('{app}'), LicensePath]);
    
    if Exec('powershell.exe', Format('-ExecutionPolicy Bypass -File "%s\scripts\post-install-simple.ps1" -LicenseSource "%s"',
                                    [ExpandConstant('{app}'), LicensePath]), 
            '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      if ResultCode = 0 then
        Log('Script post-install exécuté avec succès')
      else
        Log(Format('Script post-install terminé avec le code: %d', [ResultCode]));
    end
    else
    begin
      Log('Impossible d''exécuter le script post-install');
    end;
  end
  else
  begin
    Log('Aucun fichier licence trouvé, installation sans licence');
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Créer le vault si la tâche est sélectionnée
    if IsTaskSelected('createvault') then
    begin
      CreateVaultDirectory();
      RunPostInstallScript();
    end;
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  
  // Page de sélection des tâches
  if CurPageID = wpSelectTasks then
  begin
    if IsTaskSelected('createvault') then
    begin
      VaultPath := GetVaultPath();
      if MsgBox(Format('Le vault sera créé dans:'#13#10'%s'#13#10#13#10'Continuer ?', [VaultPath]), 
                mbConfirmation, MB_YESNO) = IDNO then
        Result := False;
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  VaultDir: string;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // Demander si l'utilisateur veut supprimer le vault
    if RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'VAULT_PATH', VaultDir) then
    begin
      if MsgBox(Format('Voulez-vous également supprimer le vault et toutes ses données ?'#13#10#13#10'%s', [VaultDir]),
                mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      begin
        DelTree(VaultDir, True, True, True);
        RegDeleteValue(HKEY_CURRENT_USER, 'Environment', 'VAULT_PATH');
      end;
    end;
  end;
end;