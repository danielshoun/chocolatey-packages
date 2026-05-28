param(
  [Parameter(Mandatory = $true)]
  [string]$PackageId,

  [Parameter(Mandatory = $true)]
  [string]$PackageVersion,

  [Parameter(Mandatory = $true)]
  [string]$ValidationScript,

  [string]$Source = 'https://push.chocolatey.org/'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Get-GitHubOutputValues {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Expected GitHub output file was not created: $Path"
  }

  $values = @{}
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -notmatch '^([^=]+)=(.*)$') {
      continue
    }

    $values[$matches[1]] = $matches[2]
  }

  return $values
}

if (-not $env:CHOCOLATEY_API_KEY) {
  throw 'Set the CHOCOLATEY_API_KEY repository secret before publishing packages.'
}

$validationScriptPath = Join-Path $repoRoot $ValidationScript
if (-not (Test-Path -LiteralPath $validationScriptPath)) {
  throw "Validation script does not exist: $validationScriptPath"
}

$runnerTemp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
$packOutputFile = Join-Path $runnerTemp "pack-output-$PackageId-$([System.Guid]::NewGuid().ToString('N')).txt"
$originalGithubOutput = $env:GITHUB_OUTPUT

try {
  $env:GITHUB_OUTPUT = $packOutputFile
  & $validationScriptPath -Command pack
  if ($LASTEXITCODE -ne 0) {
    throw "Packing $PackageId failed with exit code $LASTEXITCODE."
  }
} finally {
  $env:GITHUB_OUTPUT = $originalGithubOutput
}

$packOutputs = Get-GitHubOutputValues -Path $packOutputFile
if (-not $packOutputs.ContainsKey('package_source')) {
  throw "Packing $PackageId did not report a package_source output."
}

$packageSource = $packOutputs['package_source']
if (-not (Test-Path -LiteralPath $packageSource)) {
  throw "Package source directory does not exist: $packageSource"
}

$packageFileName = "$PackageId.$PackageVersion.nupkg"
$package = Get-ChildItem -Path $packageSource -Filter $packageFileName | Select-Object -First 1
if (-not $package) {
  throw "Could not find $packageFileName in $packageSource."
}

choco push $package.FullName --source $Source --api-key "$env:CHOCOLATEY_API_KEY" --yes --no-progress
if ($LASTEXITCODE -ne 0) {
  throw "Publishing $($package.Name) failed with exit code $LASTEXITCODE."
}
