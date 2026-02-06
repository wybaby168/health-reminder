param(
  [string]$MsixPath
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

if ([string]::IsNullOrWhiteSpace($MsixPath)) {
  $dist = Join-Path $repoRoot '..\dist\msix'
  $msix = Get-ChildItem -Path $dist -Recurse -File -Include *.msix | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($null -eq $msix) {
    throw "No .msix found under $dist. Run windows\scripts\build-msix.ps1 first."
  }
  $MsixPath = $msix.FullName
}

if (-not (Test-Path $MsixPath)) {
  throw "MSIX not found: $MsixPath"
}

Add-AppxPackage -Path $MsixPath -ForceApplicationShutdown -ForceUpdateFromAnyVersion
Write-Host "Installed: $MsixPath"

