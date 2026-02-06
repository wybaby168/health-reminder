param(
  [string]$Subject = 'CN=HealthReminder.Dev',
  [string]$PfxPath,
  [string]$Password
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
if ([string]::IsNullOrWhiteSpace($PfxPath)) {
  $PfxPath = Join-Path $repoRoot '..\certs\HealthReminder.Dev.pfx'
}

if ([string]::IsNullOrWhiteSpace($Password)) {
  $Password = [Guid]::NewGuid().ToString('N')
}

$cert = New-SelfSignedCertificate -Type Custom -Subject $Subject -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -KeyUsage DigitalSignature -CertStoreLocation 'Cert:\CurrentUser\My' -KeyExportPolicy Exportable -NotAfter (Get-Date).AddYears(5) -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3')

$secure = ConvertTo-SecureString -String $Password -AsPlainText -Force
New-Item -ItemType Directory -Force -Path (Split-Path $PfxPath) | Out-Null
Export-PfxCertificate -Cert $cert -FilePath $PfxPath -Password $secure | Out-Null

$trusted = 'Cert:\CurrentUser\TrustedPeople'
Import-PfxCertificate -FilePath $PfxPath -CertStoreLocation $trusted -Password $secure | Out-Null

Write-Host "PFX: $PfxPath"
Write-Host "Password: $Password"
Write-Host "Thumbprint: $($cert.Thumbprint)"

