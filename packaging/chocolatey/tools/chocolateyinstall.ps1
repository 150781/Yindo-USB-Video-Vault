$ErrorActionPreference = 'Stop'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$packageName = 'usbvideovault'
$url64 = 'https://github.com/150781/Yindo-USB-Video-Vault/releases/download/v0.1.4/USB%20Video%20Vault%20Setup%200.1.4.exe'

$packageArgs = @{
  packageName    = $packageName
  unzipLocation  = $toolsDir
  fileType       = 'EXE'
  url64bit       = $url64
  softwareName   = 'USB Video Vault*'
  checksum64     = '3065BF01E798EBD3C49E934943B3A078F947E15DD6BE08CCA30F882E7F6A52BD'
  checksumType64 = 'sha256'
  silentArgs     = "/S"
  validExitCodes = @(0)
}

Install-ChocolateyPackage @packageArgs
