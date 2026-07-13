# Purpose: Forcar o desligamento da VM Hyper-V de laboratorio e registrar estado
# Category: lab
# Safety: destructive
# Expected environment: host Windows com Hyper-V e shell administrativa
# Requires: Hyper-V, Administrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$vm = "SRV-RAGOSTHINK"
$out = "C:\Users\aguia\Documents\ragos-hv-stop.txt"

if (Test-Path $out) {
  Remove-Item $out -Force
}

if ((Get-VM -Name $vm).State -ne "Off") {
  Stop-VM -Name $vm -TurnOff -Force
  Start-Sleep -Seconds 3
}

Get-VM -Name $vm | Select-Object Name,State,Generation,Status,Uptime | Format-List | Out-File -FilePath $out -Encoding utf8
