$ErrorActionPreference = 'Stop' # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url64      = 'https://github.com/alire-project/alire/releases/download/v2.1.0/alr-2.1.0-bin-x86_64-windows.zip' # download url, HTTPS preferred

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  unzipLocation  = $toolsDir
  url64          = $url64
  checksum64     = '373ed06114f46c80e8a10c00a5edb3a14a86c9ad1ce6326060d734968a8155d9'
  checksumType64 = 'sha256' #default is md5, can also be sha1, sha256 or sha512
}

Install-ChocolateyZipPackage @packageArgs
