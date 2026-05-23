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
    $packageOutputDir = Join-Path $runnerTemp 'zed-editor-package'
    New-Item -ItemType Directory -Path $packageOutputDir -Force | Out-Null

    choco pack (Join-Path $repoRoot 'zed-editor\zed-editor.nuspec') --outputdirectory $packageOutputDir --yes --no-progress

    $package = Get-ChildItem -Path $packageOutputDir -Filter 'zed-editor.*.nupkg' |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1

    if (-not $package) {
      throw 'Failed to create the Zed Chocolatey package.'
    }

    $installScriptPath = Join-Path $repoRoot 'zed-editor\tools\chocolateyinstall.ps1'
    $installScript = Get-Content -Path $installScriptPath -Raw
    $versionMatch = [regex]::Match($installScript, 'releases/download/v([^/]+)/')

    if (-not $versionMatch.Success) {
      throw "Could not determine the expected Zed version from $installScriptPath."
    }

    Set-StepOutput -Name 'package_source' -Value $packageOutputDir
    Set-StepOutput -Name 'expected_zed_version' -Value $versionMatch.Groups[1].Value
  }

  'verify-install' {
    if (-not $ExpectedVersion) {
      throw 'The verify-install command requires -ExpectedVersion.'
    }

    $zedCommand = Get-Command zed -ErrorAction SilentlyContinue
    if (-not $zedCommand) {
      throw 'The zed command was not available after installation.'
    }

    $versionOutput = (& zed --version 2>&1 | Out-String).Trim()
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
      throw "Unable to read the installed Zed version.`n$versionOutput"
    }

    if ($versionOutput -notmatch [regex]::Escape($ExpectedVersion)) {
      throw "Expected Zed version $ExpectedVersion, but got:`n$versionOutput"
    }

    $packageInstallDir = Join-Path $env:ChocolateyInstall 'lib\zed-editor'
    if (-not (Test-Path -LiteralPath $packageInstallDir)) {
      throw "Chocolatey package directory was not created: $packageInstallDir"
    }
  }

  'verify-cleanup' {
    $pathsThatMustBeRemoved = @(
      (Join-Path $env:LOCALAPPDATA 'Zed')
      (Join-Path $env:ChocolateyInstall 'lib\zed-editor')
      (Join-Path $env:ChocolateyInstall 'lib-bad\zed-editor')
    )

    $remainingPaths = $pathsThatMustBeRemoved | Where-Object { Test-Path -LiteralPath $_ }
    if ($remainingPaths) {
      throw "Expected these paths to be removed after uninstall:`n$($remainingPaths -join "`n")"
    }

    $shimPath = Join-Path $env:ChocolateyInstall 'bin\zed.exe'
    if (Test-Path -LiteralPath $shimPath) {
      throw "Chocolatey shim still exists after uninstall: $shimPath"
    }
  }
}
