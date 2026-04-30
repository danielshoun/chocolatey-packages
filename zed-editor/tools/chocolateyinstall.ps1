$ErrorActionPreference = 'Stop'
$url64      = 'https://github.com/zed-industries/zed/releases/download/v1.0.0/Zed-x86_64.exe'

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  url64          = $url64
  softwareName   = 'Zed*'
  checksum64     = 'f93014dc720ad772d43db8e9b2b705ccdb2f3adb665f4bfbf184f8d8d872a16d'
  checksumType64 = 'sha256'
  silentArgs     = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
}

Install-ChocolateyPackage @packageArgs
