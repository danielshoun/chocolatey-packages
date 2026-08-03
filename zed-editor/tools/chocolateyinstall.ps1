$ErrorActionPreference = 'Stop'
$url64      = 'https://github.com/zed-industries/zed/releases/download/v1.13.2/Zed-x86_64.exe'
$zedCliPath = Join-Path $env:LOCALAPPDATA 'Programs\Zed\bin\zed.exe'

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  url64          = $url64
  softwareName   = 'Zed*'
  checksum64     = 'f9e73b28ed1d202832dc2ff1e5df1be46297d16ac7aa1762f230f7c9995fd5b3'
  checksumType64 = 'sha256'
  silentArgs     = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
}

Install-ChocolateyPackage @packageArgs

if (-not (Test-Path -LiteralPath $zedCliPath)) {
  throw "Zed CLI executable was not found after installation: $zedCliPath"
}

Install-BinFile -Name 'zed' -Path $zedCliPath
