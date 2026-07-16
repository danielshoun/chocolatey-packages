$ErrorActionPreference = 'Stop'
$url64      = 'https://github.com/zed-industries/zed/releases/download/v1.11.3/Zed-x86_64.exe'
$zedCliPath = Join-Path $env:LOCALAPPDATA 'Programs\Zed\bin\zed.exe'

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  url64          = $url64
  softwareName   = 'Zed*'
  checksum64     = '399ebb679477e81856c55df2c088c2dd8523b3d00e4fb21b3385ffda82398b9f'
  checksumType64 = 'sha256'
  silentArgs     = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
}

Install-ChocolateyPackage @packageArgs

if (-not (Test-Path -LiteralPath $zedCliPath)) {
  throw "Zed CLI executable was not found after installation: $zedCliPath"
}

Install-BinFile -Name 'zed' -Path $zedCliPath
