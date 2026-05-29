$ErrorActionPreference = 'Stop' # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url64      = 'https://github.com/alire-project/alire/releases/download/v2.1.1/alr-2.1.1-bin-x86_64-windows.zip' # download url, HTTPS preferred

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  unzipLocation  = $toolsDir
  url64          = $url64
  checksum64     = '863013b1f94da6f3b7d0d5a74022ac3370424eeea9a470ebdb33d188d61b9125'
  checksumType64 = 'sha256' #default is md5, can also be sha1, sha256 or sha512
}

Install-ChocolateyZipPackage @packageArgs
