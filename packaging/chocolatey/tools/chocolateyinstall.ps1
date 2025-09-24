$ErrorActionPreference = 'Stop'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$packageName = 'usbvideovault'
$url64      = 'https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v0.1.4/USB%20Video%20Vault%20Setup%200.1.4.exe'

$packageArgs = @{
  packageName   = $packageName
  unzipLocation = $toolsDir
  fileType      = 'EXE'
  url64bit      = $url64
  softwareName  = 'USB Video Vault*'
  checksum64    = '[PLACEHOLDER - Replace with SHA256 from release]'
  checksumType64= 'sha256'
  silentArgs    = "/S"
  validExitCodes= @(0)
}

Install-ChocolateyPackage @packageArgs