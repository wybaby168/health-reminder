param(
  [ValidateSet('Release')] [string]$Configuration = 'Release',
  [ValidateSet('x64')] [string]$Platform = 'x64',
  [string]$PfxPath,
  [string]$PfxPassword
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$solution = Join-Path $repoRoot 'HealthReminder.Windows\HealthReminder.Windows.sln'

if ([string]::IsNullOrWhiteSpace($PfxPath)) {
  $PfxPath = Join-Path $repoRoot '..\certs\HealthReminder.Dev.pfx'
}

if (-not (Test-Path $PfxPath)) {
  throw "PFX not found: $PfxPath. Run windows\scripts\new-dev-cert.ps1 first."
}

if ([string]::IsNullOrWhiteSpace($PfxPassword)) {
  throw 'PfxPassword is required.'
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) {
  throw "vswhere not found: $vswhere. Install Visual Studio 2022 or Build Tools."
}

$msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($msbuild) -or -not (Test-Path $msbuild)) {
  throw 'MSBuild.exe not found. Install Visual Studio 2022 (MSBuild + Windows App SDK tooling).'
}

& $msbuild $solution /restore /t:Build /p:Configuration=$Configuration /p:Platform=$Platform /p:GenerateAppxPackageOnBuild=true /p:AppxBundle=Never /p:UapAppxPackageBuildMode=SideloadOnly /p:PackageCertificateKeyFile="$PfxPath" /p:PackageCertificatePassword="$PfxPassword"

$dist = Join-Path $repoRoot '..\dist\msix'
$msix = Get-ChildItem -Path $dist -Recurse -File -Include *.msix | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $msix) {
  throw "No .msix found under $dist."
}

Write-Host "MSIX: $($msix.FullName)"

