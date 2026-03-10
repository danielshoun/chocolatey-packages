$ErrorActionPreference = 'Stop'

$alireLocalDataDir = Join-Path $env:LOCALAPPDATA 'alire'

if (Test-Path -LiteralPath $alireLocalDataDir) {
  Remove-Item -LiteralPath $alireLocalDataDir -Recurse -Force
}
