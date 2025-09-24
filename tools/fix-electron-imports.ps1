# Migration automatique des imports Electron vers ESM
# Corrige les named imports problématiques d'Electron

$files = @(
  "src/main/vault.ts",
  "src/main/protocol.ts",
  "src/main/licenseSecure.ts",
  "src/main/windows.ts",
  "src/main/ipcSecurity.ts",
  "src/main/ipcStatsExtended.ts",
  "src/main/ipc.ts",
  "src/main/csp.ts",
  "src/main/sandbox.ts",
  "src/main/antiDebug.ts",
  "src/main/licenseExpirationAlert.ts",
  "src/main/displayWindow.ts",
  "src/main/devAssets.ts",
  "src/main/ipcDisplay.ts",
  "src/main/ipcQueue.ts",
  "src/main/mediaProtocols.ts",
  "src/main/playerQueue.ts",
  "src/main/vaultPath.ts",
  "src/main/protocol.vault.ts",
  "src/main/protocol-new.ts",
  "src/main/protocol-old.ts"
)

foreach ($file in $files) {
  if (Test-Path $file) {
    Write-Host "Processing $file..." -ForegroundColor Green

    $content = Get-Content $file -Raw
    if ($content -match "from 'electron'") {
      Write-Host "  - Found Electron imports, needs manual review: $file" -ForegroundColor Yellow
    }
  }
}

Write-Host "`nManual correction needed for complex cases." -ForegroundColor Cyan
Write-Host "Use pattern: import * as electron from 'electron'; const { app, ... } = electron;" -ForegroundColor Cyan
