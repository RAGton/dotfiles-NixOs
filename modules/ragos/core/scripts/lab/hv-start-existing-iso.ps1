# Purpose: Iniciar a VM Hyper-V de laboratorio com uma ISO ja presente no host
# Category: lab
# Safety: destructive
# Expected environment: host Windows com Hyper-V e shell administrativa
# Requires: Hyper-V, Administrator
# Notes: Usa nome de VM e caminho de ISO fixos

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$vm = "SRV-RAGOSTHINK"
$hostIso = "C:\Users\aguia\Documents\ragos-installer-25.11.iso"
$out = "C:\Users\aguia\Documents\ragos-hv-start.txt"
if (Test-Path $out) { Remove-Item $out -Force }
if ((Get-VM -Name $vm).State -ne "Off") { Stop-VM -Name $vm -TurnOff -Force; Start-Sleep -Seconds 3 }
$dvd = Get-VMDvdDrive -VMName $vm -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $dvd) { Add-VMDvdDrive -VMName $vm -Path $hostIso | Out-Null; $dvd = Get-VMDvdDrive -VMName $vm | Select-Object -First 1 } else { Set-VMDvdDrive -VMName $vm -ControllerNumber $dvd.ControllerNumber -ControllerLocation $dvd.ControllerLocation -Path $hostIso; $dvd = Get-VMDvdDrive -VMName $vm | Select-Object -First 1 }
Set-VMFirmware -VMName $vm -EnableSecureBoot Off -FirstBootDevice $dvd
Start-VM -Name $vm | Out-Null
"==VM==" | Out-File -FilePath $out -Encoding utf8
Get-VM -Name $vm | Select-Object Name,State,Generation,Status,Uptime | Format-List | Out-File -FilePath $out -Append -Encoding utf8
"==DVD==" | Out-File -FilePath $out -Append -Encoding utf8
Get-VMDvdDrive -VMName $vm | Select-Object ControllerNumber,ControllerLocation,Path | Format-List | Out-File -FilePath $out -Append -Encoding utf8
"==FW==" | Out-File -FilePath $out -Append -Encoding utf8
Get-VMFirmware -VMName $vm | Select-Object SecureBoot,SecureBootTemplate | Format-List | Out-File -FilePath $out -Append -Encoding utf8
Start-Process vmconnect.exe -ArgumentList "localhost", $vm
