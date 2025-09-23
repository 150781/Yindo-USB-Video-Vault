param(
  [Parameter(Mandatory)][string]$EncryptedKeyFile,   # ex: .\keys\privkey.asc.gpg
  [Parameter(Mandatory)][string]$ManifestFile,       # ex: .\keys\manifest.json { "file":"privkey.asc","sha256":"..." }
  [Parameter()][string]$OutDir = ".\out\keys-restore"
)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if(-not (Get-Command gpg -ErrorAction SilentlyContinue)){ throw "gpg non disponible dans le PATH" }

# 1) Déchiffrer
$plain = Join-Path $OutDir "restored.asc"
$null = & gpg --batch --quiet --decrypt --output "$plain" "$EncryptedKeyFile"
if($LASTEXITCODE -ne 0){ throw "Échec déchiffrement GPG" }

# 2) Intégrité
$manifest = Get-Content $ManifestFile | ConvertFrom-Json
$hash = (Get-FileHash $plain -Algorithm SHA256).Hash.ToLower()
if($hash -ne $manifest.sha256.ToLower()){ throw "SHA256 ne correspond pas au manifeste" }

Write-Host "Restauration OK et intégrité validée → $plain" -ForegroundColor Green
exit 0