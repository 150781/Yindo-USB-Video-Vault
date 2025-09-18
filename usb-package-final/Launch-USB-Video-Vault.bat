@echo off
echo === Yindo USB Video Vault ===
echo.
echo Lancement de l'application...
echo.

rem Définir le vault local
set VAULT_PATH=%~dp0vault

rem Lancer l'application portable
"%~dp0USB-Video-Vault.exe" --no-sandbox

echo.
echo Application fermée.
pause
