$ErrorActionPreference = 'Stop'
$url64      = 'https://github.com/zed-industries/zed/releases/download/v1.3.6/Zed-x86_64.exe'

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  url64          = $url64
  softwareName   = 'Zed*'
  checksum64     = '28a5c5d2b1a54e9dba1093d860cc02664044b719dc995af7f2af60cd235b6a3d'
  checksumType64 = 'sha256'
  silentArgs     = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
}

Install-ChocolateyPackage @packageArgs
