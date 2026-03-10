[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Pack
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$nuspecPath = Join-Path $packageDir 'alire.nuspec'
$installScriptPath = Join-Path $packageDir 'tools\chocolateyinstall.ps1'
$releaseApiUrl = 'https://api.github.com/repos/alire-project/alire/releases/latest'
$windowsAssetPattern = '^alr-(?<version>.+)-bin-x86_64-windows\.zip$'

function Get-TextFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return Get-Content -LiteralPath $Path -Raw -Encoding utf8
}

function Write-TextFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Content
    )

    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8 -NoNewline
}

function Get-GitHubHeaders {
    $headers = @{
        Accept = 'application/vnd.github+json'
        'User-Agent' = 'chocolatey-packages-alire-updater'
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    if ($env:GITHUB_TOKEN) {
        $headers.Authorization = "Bearer $($env:GITHUB_TOKEN)"
    }

    return $headers
}

function Get-CurrentPackageVersion {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $nuspec = [xml](Get-TextFile -Path $Path)
    return [string]$nuspec.package.metadata.version
}

function Split-PackageVersion {
    param(
        [Parameter(Mandatory)]
        [string]$Version
    )

    $match = [regex]::Match($Version, '^(?<base>\d+\.\d+\.\d+)(?:\.(?<fix>\d{8}))?$')
    if ($match.Success) {
        return [pscustomobject]@{
            BaseVersion = $match.Groups['base'].Value
            FixVersion = $match.Groups['fix'].Value
        }
    }

    return [pscustomobject]@{
        BaseVersion = $Version
        FixVersion = $null
    }
}

function Get-ChocolateyFixVersion {
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [datetime]$Date = (Get-Date)
    )

    $versionInfo = Split-PackageVersion -Version $Version
    if ($versionInfo.BaseVersion -notmatch '^\d+\.\d+\.\d+$') {
        throw "Chocolatey fix version notation requires a three-part numeric version. '$($versionInfo.BaseVersion)' is not supported."
    }

    $fixDate = $Date.ToString('yyyyMMdd', [System.Globalization.CultureInfo]::InvariantCulture)
    return "$($versionInfo.BaseVersion).$fixDate"
}

function Update-NuspecVersion {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Version
    )

    $content = Get-TextFile -Path $Path
    $pattern = '(?s)(<version>)([^<]+)(</version>)'
    if ($content -notmatch $pattern) {
        throw "Failed to locate <version> in $Path."
    }

    $updated = $content -replace $pattern, "`${1}$Version`${3}"

    if ($updated -ne $content) {
        Write-TextFile -Path $Path -Content $updated
    }
}

function Update-InstallScript {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Url64,

        [Parameter(Mandatory)]
        [string]$Checksum64
    )

    $content = Get-TextFile -Path $Path
    $urlPattern = '(?m)(^\$url64\s*=\s*)''[^'']+'''
    $checksumPattern = '(?m)(^\s*checksum64\s*=\s*)''[^'']+'''

    if ($content -notmatch $urlPattern) {
        throw "Failed to locate `$url64 in $Path."
    }

    if ($content -notmatch $checksumPattern) {
        throw "Failed to locate checksum64 in $Path."
    }

    $updated = $content `
        -replace $urlPattern, "`$1'$Url64'" `
        -replace $checksumPattern, "`$1'$Checksum64'"

    if ($updated -ne $content) {
        Write-TextFile -Path $Path -Content $updated
    }
}

if (-not (Test-Path -LiteralPath $nuspecPath)) {
    throw "Could not find nuspec file at $nuspecPath."
}

if (-not (Test-Path -LiteralPath $installScriptPath)) {
    throw "Could not find install script at $installScriptPath."
}

$headers = Get-GitHubHeaders
$release = Invoke-RestMethod -Uri $releaseApiUrl -Headers $headers
$currentVersion = Get-CurrentPackageVersion -Path $nuspecPath
$latestVersion = [string]$release.tag_name

if ($latestVersion.StartsWith('v')) {
    $latestVersion = $latestVersion.Substring(1)
}

$currentVersionInfo = Split-PackageVersion -Version $currentVersion

$asset = $release.assets | Where-Object { $_.name -match $windowsAssetPattern } | Select-Object -First 1

if (-not $asset) {
    throw 'Could not find the Windows x64 binary zip in the latest Alire release.'
}

$assetMatch = [regex]::Match($asset.name, $windowsAssetPattern)
$assetVersion = $assetMatch.Groups['version'].Value
if ($assetVersion -ne $latestVersion) {
    throw "Release tag version '$latestVersion' does not match asset version '$assetVersion'."
}

if (-not $Force -and $currentVersionInfo.BaseVersion -eq $latestVersion) {
    Write-Host "Alire is already up to date at version $currentVersion."
    return
}

$packageVersion = $latestVersion
if ($Force -and $currentVersionInfo.BaseVersion -eq $latestVersion) {
    $packageVersion = Get-ChocolateyFixVersion -Version $latestVersion
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("alire-choco-update-" + [System.Guid]::NewGuid().ToString('N'))
$downloadPath = Join-Path $tempDir $asset.name

try {
    New-Item -Path $tempDir -ItemType Directory | Out-Null
    Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -OutFile $downloadPath

    $checksum64 = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash.ToLowerInvariant()

    Update-NuspecVersion -Path $nuspecPath -Version $packageVersion
    Update-InstallScript -Path $installScriptPath -Url64 $asset.browser_download_url -Checksum64 $checksum64

    Write-Host "Updated Alire package files to version $packageVersion."
    Write-Host "URL: $($asset.browser_download_url)"
    Write-Host "SHA256: $checksum64"

    if ($Pack) {
        $choco = Get-Command choco -ErrorAction SilentlyContinue
        if (-not $choco) {
            throw 'Chocolatey CLI was not found in PATH, so the package could not be packed.'
        }

        & $choco.Source pack $nuspecPath --outputdirectory $packageDir
    }
}
finally {
    if (Test-Path -LiteralPath $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force
    }
}
