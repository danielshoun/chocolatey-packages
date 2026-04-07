param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('pack', 'verify-install', 'verify-cleanup')]
  [string]$Command,

  [string]$ExpectedVersion
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Set-StepOutput {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Value
  )

  if ($env:GITHUB_OUTPUT) {
    "$Name=$Value" >> $env:GITHUB_OUTPUT
    return
  }

  Write-Host "$Name=$Value"
}

switch ($Command) {
  'pack' {
    $runnerTemp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
    $packageOutputDir = Join-Path $runnerTemp 'alire-package'
    New-Item -ItemType Directory -Path $packageOutputDir -Force | Out-Null

    choco pack (Join-Path $repoRoot 'alire\alire.nuspec') --outputdirectory $packageOutputDir --yes --no-progress

    $package = Get-ChildItem -Path $packageOutputDir -Filter 'alire.*.nupkg' |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1

    if (-not $package) {
      throw 'Failed to create the Alire Chocolatey package.'
    }

    $installScriptPath = Join-Path $repoRoot 'alire\tools\chocolateyinstall.ps1'
    $installScript = Get-Content -Path $installScriptPath -Raw
    $versionMatch = [regex]::Match($installScript, 'releases/download/v([^/]+)/')

    if (-not $versionMatch.Success) {
      throw "Could not determine the expected Alire version from $installScriptPath."
    }

    Set-StepOutput -Name 'package_source' -Value $packageOutputDir
    Set-StepOutput -Name 'expected_alire_version' -Value $versionMatch.Groups[1].Value
  }

  'verify-install' {
    if (-not $ExpectedVersion) {
      throw 'The verify-install command requires -ExpectedVersion.'
    }

    $alireCommand = Get-Command alr -ErrorAction SilentlyContinue
    if (-not $alireCommand) {
      throw 'The alr command was not available after installation.'
    }

    $versionOutput = (& alr --version 2>&1 | Out-String).Trim()
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
      $versionOutput = (& alr version 2>&1 | Out-String).Trim()
      $exitCode = $LASTEXITCODE
    }

    if ($exitCode -ne 0) {
      throw "Unable to read the installed Alire version.`n$versionOutput"
    }

    if ($versionOutput -notmatch [regex]::Escape($ExpectedVersion)) {
      throw "Expected Alire version $ExpectedVersion, but got:`n$versionOutput"
    }

    $alireLocalDataDir = Join-Path $env:LOCALAPPDATA 'alire'
    & alr settings --global --set ci.cleanup_probe true
    if ($LASTEXITCODE -ne 0) {
      throw 'Failed to create Alire global settings state with "alr settings --global --set".'
    }

    if (-not (Test-Path -LiteralPath $alireLocalDataDir)) {
      throw "Expected Alire to create its local data directory: $alireLocalDataDir"
    }

    $packageInstallDir = Join-Path $env:ChocolateyInstall 'lib\alire'
    if (-not (Test-Path -LiteralPath $packageInstallDir)) {
      throw "Chocolatey package directory was not created: $packageInstallDir"
    }
  }

  'verify-cleanup' {
    $pathsThatMustBeRemoved = @(
      (Join-Path $env:LOCALAPPDATA 'alire')
      (Join-Path $env:ChocolateyInstall 'lib\alire')
      (Join-Path $env:ChocolateyInstall 'lib-bad\alire')
    )

    $remainingPaths = $pathsThatMustBeRemoved | Where-Object { Test-Path -LiteralPath $_ }
    if ($remainingPaths) {
      throw "Expected these paths to be removed after uninstall:`n$($remainingPaths -join "`n")"
    }

    $shimPath = Join-Path $env:ChocolateyInstall 'bin\alr.exe'
    if (Test-Path -LiteralPath $shimPath) {
      throw "Chocolatey shim still exists after uninstall: $shimPath"
    }
  }
}
