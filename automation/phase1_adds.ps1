# Atlas SOC Lab - ATLAS-SRV Phase 1: Verify Network (D5) + Install AD DS & Promote Forest atlas.local (D6)
param(
    [Parameter(Mandatory=$true)][string]$DsrmPasswordPlain
)
$ErrorActionPreference = 'Stop'

Write-Output "=== Baseline Hostname & Network ==="
hostname
Get-NetAdapter | Format-Table Name, MacAddress, Status, InterfaceGuid -AutoSize
Get-NetIPConfiguration

# Ensure Host-Only card (MAC 52-54-00-10-20-0A) is named 'Ethernet' with 10.10.20.10/24, no gateway, DNS 127.0.0.1
$hostNic = Get-NetAdapter | Where-Object { ($_.MacAddress -replace '[:-]','').ToUpper() -eq '52540010200A' }
if ($hostNic -and $hostNic.Name -ne 'Ethernet') {
    Rename-NetAdapter -Name $hostNic.Name -NewName 'Ethernet'
}
$natNic = Get-NetAdapter | Where-Object { ($_.MacAddress -replace '[:-]','').ToUpper() -eq '5254001020F2' }
if ($natNic -and $natNic.Name -ne 'Ethernet 2') {
    Rename-NetAdapter -Name $natNic.Name -NewName 'Ethernet 2'
}

Write-Output "=== Installing AD-Domain-Services and DNS Roles (Part D6 Step 1) ==="
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

Write-Output "=== Promoting ATLAS-SRV to Domain Controller for atlas.local (Part D6 Step 2) ==="
$dsrmSec = ConvertTo-SecureString $DsrmPasswordPlain -AsPlainText -Force
Import-Module ADDSDeployment
Install-ADDSForest `
    -DomainName "atlas.local" `
    -DomainNetbiosName "ATLAS" `
    -InstallDns:$true `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SysvolPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $dsrmSec `
    -NoRebootOnCompletion:$false `
    -Force:$true
