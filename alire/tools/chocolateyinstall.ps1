$ErrorActionPreference = 'Stop' # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url64      = 'https://github.com/alire-project/alire/releases/download/v2.0.1/alr-2.0.1-bin-x86_64-windows.zip' # download url, HTTPS preferred

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  unzipLocation  = $toolsDir
  url64          = $url64
  checksum64     = '0d448c476286c782ba62a91e3ff8588e66d23417edd1cbf042b2fad685fb55d5'
  checksumType64 = 'sha256' #default is md5, can also be sha1, sha256 or sha512
}

Install-ChocolateyZipPackage @packageArgs
