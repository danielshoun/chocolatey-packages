$ErrorActionPreference = 'Stop' # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url64      = 'https://github.com/alire-project/alire/releases/download/v2.0.2/alr-2.0.2-bin-x86_64-windows.zip' # download url, HTTPS preferred

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  unzipLocation  = $toolsDir
  url64          = $url64
  checksum64     = 'a6894e51acbc37af69316d807821917e246dfa8a2bdf5630fd547ff624011286'
  checksumType64 = 'sha256' #default is md5, can also be sha1, sha256 or sha512
}

Install-ChocolateyZipPackage @packageArgs
