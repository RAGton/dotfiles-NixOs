# Purpose: Desabilitar Secure Boot, anexar ISO e iniciar a VM Hyper-V de laboratorio
# Category: lab
# Safety: destructive
# Expected environment: host Windows com Hyper-V e shell administrativa
# Requires: Hyper-V, Administrator
# Notes: Altera firmware e midia da VM

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$vm = "SRV-RAGOSTHINK"
$iso = "C:\Users\aguia\Documents\ragos-installer-25.11.iso"
$out = "C:\Users\aguia\Documents\ragos-hv-restart.txt"

if (Test-Path $out) {
  Remove-Item $out -Force
}

if ((Get-VM -Name $vm).State -ne "Off") {
  Stop-VM -Name $vm -TurnOff -Force
  Start-Sleep -Seconds 3
}

$dvd = Get-VMDvdDrive -VMName $vm | Select-Object -First 1
if (-not $dvd) {
  Add-VMDvdDrive -VMName $vm -Path $iso | Out-Null
  $dvd = Get-VMDvdDrive -VMName $vm | Select-Object -First 1
} else {
  Set-VMDvdDrive -VMName $vm -ControllerNumber $dvd.ControllerNumber -ControllerLocation $dvd.ControllerLocation -Path $iso
}

Set-VMFirmware -VMName $vm -EnableSecureBoot Off
Set-VMFirmware -VMName $vm -FirstBootDevice $dvd
Start-VM -Name $vm | Out-Null

"==VM==" | Out-File -FilePath $out -Encoding utf8
Get-VM -Name $vm | Select-Object Name,State,Generation,Status,Uptime | Format-List | Out-File -FilePath $out -Append -Encoding utf8

"==FW==" | Out-File -FilePath $out -Append -Encoding utf8
Get-VMFirmware -VMName $vm | Select-Object SecureBoot,SecureBootTemplate,PreferredNetworkBootProtocol | Format-List | Out-File -FilePath $out -Append -Encoding utf8

"==DVD==" | Out-File -FilePath $out -Append -Encoding utf8
Get-VMDvdDrive -VMName $vm | Select-Object ControllerNumber,ControllerLocation,Path | Format-List | Out-File -FilePath $out -Append -Encoding utf8
