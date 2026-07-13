# Purpose: Consultar a atribuicao de IP da VM Hyper-V de laboratorio
# Category: lab
# Safety: lab-only
# Expected environment: host Windows com Hyper-V e shell administrativa
# Requires: Hyper-V
# Notes: Usa nome de VM e caminho de saida fixos

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$vm = "SRV-RAGOSTHINK"
$out = "C:\Users\aguia\Documents\ragos-hv-poll-ip.txt"

if (Test-Path $out) {
  Remove-Item $out -Force
}

$deadline = (Get-Date).AddMinutes(8)
$found = $false

while ((Get-Date) -lt $deadline) {
  $adapters = Get-VMNetworkAdapter -VMName $vm
  $ips = @(
    $adapters |
      ForEach-Object { $_.IPAddresses } |
      Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' -and $_ -notlike '169.254*' }
  )

  if ($ips.Count -gt 0) {
    "==IPS==" | Out-File -FilePath $out -Encoding utf8
    $ips | Out-File -FilePath $out -Append -Encoding utf8
    "==ADAPTERS==" | Out-File -FilePath $out -Append -Encoding utf8
    $adapters | Select-Object Name,SwitchName,Status,IPAddresses | Format-List | Out-File -FilePath $out -Append -Encoding utf8
    $found = $true
    break
  }

  Start-Sleep -Seconds 10
}

if (-not $found) {
  "NO_IP" | Out-File -FilePath $out -Encoding utf8
  Get-VMNetworkAdapter -VMName $vm | Select-Object Name,SwitchName,Status,IPAddresses | Format-List | Out-File -FilePath $out -Append -Encoding utf8
}
