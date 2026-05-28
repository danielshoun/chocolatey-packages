param(
  [Parameter(Mandatory = $true)]
  [string]$BeforeSha
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

$packageConfigs = @(
  [pscustomobject]@{
    Id = 'alire'
    Nuspec = 'alire/alire.nuspec'
    ValidationScript = '.github/scripts/validate-alire-package.ps1'
  }
  [pscustomobject]@{
    Id = 'zed-editor'
    Nuspec = 'zed-editor/zed-editor.nuspec'
    ValidationScript = '.github/scripts/validate-zed-editor-package.ps1'
  }
)

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

function Get-NuspecVersion {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Content,

    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $nuspec = [xml]$Content
  $version = [string]$nuspec.package.metadata.version
  if ([string]::IsNullOrWhiteSpace($version)) {
    throw "Could not read package version from $Path."
  }

  return $version.Trim()
}

$changedPackages = @()

if ([string]::IsNullOrWhiteSpace($BeforeSha) -or $BeforeSha -match '^0{40}$') {
  Write-Host 'This push has no previous commit to compare; no packages will be published.'
} else {
  foreach ($package in $packageConfigs) {
    $currentPath = Join-Path $repoRoot $package.Nuspec
    $currentContent = Get-Content -Path $currentPath -Raw
    $currentVersion = Get-NuspecVersion -Content $currentContent -Path $package.Nuspec

    $previousContentLines = & git -C $repoRoot show "${BeforeSha}:$($package.Nuspec)"
    if ($LASTEXITCODE -ne 0) {
      throw "Could not read $($package.Nuspec) from previous commit $BeforeSha."
    }

    $previousContent = $previousContentLines -join "`n"
    $previousVersion = Get-NuspecVersion -Content $previousContent -Path "${BeforeSha}:$($package.Nuspec)"

    if ($previousVersion -ne $currentVersion) {
      Write-Host "$($package.Id): $previousVersion -> $currentVersion"
      $changedPackages += [pscustomobject]@{
        id = $package.Id
        version = $currentVersion
        validation_script = $package.ValidationScript
      }
    } else {
      Write-Host "$($package.Id): version unchanged ($currentVersion)"
    }
  }
}

if ($changedPackages.Count -gt 0) {
  $jsonItems = @($changedPackages | ForEach-Object { $_ | ConvertTo-Json -Compress })
  $packagesJson = "[$($jsonItems -join ',')]"
  $hasPackages = 'true'
} else {
  $packagesJson = '[]'
  $hasPackages = 'false'
}

Set-StepOutput -Name 'packages' -Value $packagesJson
Set-StepOutput -Name 'has_packages' -Value $hasPackages
