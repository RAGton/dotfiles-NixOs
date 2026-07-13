# Purpose: Coletar diagnostico de boot da VM Hyper-V de laboratorio
# Category: lab
# Safety: lab-only
# Expected environment: host Windows com Hyper-V e shell administrativa
# Requires: Hyper-V, Administrator
# Notes: Usa nome de VM e caminhos fixos do laboratorio

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$vm = "SRV-RAGOSTHINK"
$out = "C:\Users\aguia\Documents\ragos-hv-bootdiag.txt"

if (Test-Path $out) {
  Remove-Item $out -Force
}

"==VM==" | Out-File -FilePath $out -Encoding utf8
Get-VM -Name $vm | Select-Object Name,State,Generation,Status | Format-List | Out-File -FilePath $out -Append -Encoding utf8

"==DVD==" | Out-File -FilePath $out -Append -Encoding utf8
Get-VMDvdDrive -VMName $vm | Select-Object ControllerNumber,ControllerLocation,Path | Format-List | Out-File -FilePath $out -Append -Encoding utf8

"==FW==" | Out-File -FilePath $out -Append -Encoding utf8
Get-VMFirmware -VMName $vm | Select-Object SecureBoot,SecureBootTemplate,PreferredNetworkBootProtocol | Format-List | Out-File -FilePath $out -Append -Encoding utf8

"==BOOTORDER==" | Out-File -FilePath $out -Append -Encoding utf8
Get-VMFirmware -VMName $vm | Select-Object -ExpandProperty BootOrder | Select-Object BootType,FirmwarePath,Device | Format-Table -AutoSize | Out-File -FilePath $out -Append -Encoding utf8
