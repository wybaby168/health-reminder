param(
  [ValidateSet('Debug','Release')] [string]$Configuration = 'Debug',
  [ValidateSet('x64')] [string]$Platform = 'x64'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$proj = Join-Path $repoRoot 'HealthReminder.Windows\HealthReminder.Windows\HealthReminder.Windows.csproj'

dotnet restore $proj
dotnet build $proj -c $Configuration -p:Platform=$Platform

