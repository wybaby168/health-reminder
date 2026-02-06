param(
  [ValidateSet('Release')] [string]$Configuration = 'Release',
  [ValidateSet('x64')] [string]$Platform = 'x64'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$proj = Join-Path $repoRoot 'HealthReminder.Windows\HealthReminder.Windows\HealthReminder.Windows.csproj'
$outDir = Join-Path $repoRoot ('..\dist\win-unpackaged\' + $Platform)

dotnet restore $proj
dotnet publish $proj -c $Configuration -p:Platform=$Platform -o $outDir

$zipPath = Join-Path $repoRoot ('..\dist\HealthReminder-Windows-' + $Platform + '-unpackaged.zip')
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $outDir '*') -DestinationPath $zipPath

Write-Host "Published: $outDir"
Write-Host "Zipped: $zipPath"

