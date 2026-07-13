# Purpose: Atualizar a ISO local do laboratorio e iniciar a VM Hyper-V
# Category: lab
# Safety: destructive
# Expected environment: host Windows com Hyper-V e shell administrativa
# Requires: Hyper-V, Administrator
# Notes: Sobrescreve a copia local da ISO e altera a VM

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$vm = "SRV-RAGOSTHINK"
$repoIso = "C:\Users\aguia\OneDrive\Documents\GitHub\ragos\result-iso\iso"
$hostIso = "C:\Users\aguia\Documents\ragos-installer-25.11.iso"
$out = "C:\Users\aguia\Documents\ragos-hv-refresh.txt"

if (Test-Path $out) {
  Remove-Item $out -Force
}

if ((Get-VM -Name $vm).State -ne "Off") {
  Stop-VM -Name $vm -TurnOff -Force
  Start-Sleep -Seconds 3
}

$builtIso = Get-ChildItem -Path $repoIso -Filter *.iso | Select-Object -First 1
if (-not $builtIso) {
  throw "Nenhuma ISO encontrada em $repoIso"
}

Copy-Item -Path $builtIso.FullName -Destination $hostIso -Force

$dvd = Get-VMDvdDrive -VMName $vm -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $dvd) {
  Add-VMDvdDrive -VMName $vm -Path $hostIso | Out-Null
  $dvd = Get-VMDvdDrive -VMName $vm | Select-Object -First 1
} else {
  Set-VMDvdDrive -VMName $vm -ControllerNumber $dvd.ControllerNumber -ControllerLocation $dvd.ControllerLocation -Path $hostIso
}

Set-VMFirmware -VMName $vm -EnableSecureBoot Off -FirstBootDevice $dvd
Start-VM -Name $vm | Out-Null

"==ISO==" | Out-File -FilePath $out -Encoding utf8
Get-Item $hostIso | Select-Object FullName,Length,LastWriteTime | Format-List | Out-File -FilePath $out -Append -Encoding utf8

"==VM==" | Out-File -FilePath $out -Append -Encoding utf8
Get-VM -Name $vm | Select-Object Name,State,Generation,Status,Uptime | Format-List | Out-File -FilePath $out -Append -Encoding utf8

"==DVD==" | Out-File -FilePath $out -Append -Encoding utf8
Get-VMDvdDrive -VMName $vm | Select-Object ControllerNumber,ControllerLocation,Path | Format-List | Out-File -FilePath $out -Append -Encoding utf8

"==FW==" | Out-File -FilePath $out -Append -Encoding utf8
Get-VMFirmware -VMName $vm | Select-Object SecureBoot,SecureBootTemplate,PreferredNetworkBootProtocol | Format-List | Out-File -FilePath $out -Append -Encoding utf8

Start-Process vmconnect.exe -ArgumentList "localhost", $vm
