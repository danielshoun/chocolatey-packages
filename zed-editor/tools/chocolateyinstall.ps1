$ErrorActionPreference = 'Stop'
$url64      = 'https://github.com/zed-industries/zed/releases/download/v1.12.1/Zed-x86_64.exe'
$zedCliPath = Join-Path $env:LOCALAPPDATA 'Programs\Zed\bin\zed.exe'

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  url64          = $url64
  softwareName   = 'Zed*'
  checksum64     = '443a94d86011c4b5f39f701543e25998c6478bd18b8357486cea9282faf27597'
  checksumType64 = 'sha256'
  silentArgs     = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'
}

Install-ChocolateyPackage @packageArgs

if (-not (Test-Path -LiteralPath $zedCliPath)) {
  throw "Zed CLI executable was not found after installation: $zedCliPath"
}

Install-BinFile -Name 'zed' -Path $zedCliPath
