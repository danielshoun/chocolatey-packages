$ErrorActionPreference = 'Stop'
$url64      = 'https://github.com/zed-industries/zed/releases/download/v1.17.2/Zed-x86_64.exe'
$zedCliPath = Join-Path $env:LOCALAPPDATA 'Programs\Zed\bin\zed.exe'

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  url64          = $url64
  softwareName   = 'Zed*'
  checksum64     = '4ece660b71e6b7904970027cda0c574b547555c9fb745972ed154f69c1ba3692'
  checksumType64 = 'sha256'
  silentArgs     = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
}

Install-ChocolateyPackage @packageArgs

if (-not (Test-Path -LiteralPath $zedCliPath)) {
  throw "Zed CLI executable was not found after installation: $zedCliPath"
}

Install-BinFile -Name 'zed' -Path $zedCliPath
