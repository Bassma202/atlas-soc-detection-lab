# Atlas SOC Lab - ATLAS-SRV Phase 2: Post-Promotion DNS Fix (D7), Activation (D8), Staff Users (D9), Auditing (D10), SMB Share (D11)
param(
    [Parameter(Mandatory=$true)][string]$StaffPasswordPlain
)
$ErrorActionPreference = 'Stop'

Write-Output "=== D7: Fix DNS on Two-Card Domain Controller ==="
Set-DnsClient -InterfaceAlias "Ethernet 2" -RegisterThisConnectionsAddress $false
Set-DnsClient -InterfaceAlias "Ethernet" -RegisterThisConnectionsAddress $true
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses "10.10.20.10","127.0.0.1"
Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ServerAddresses "10.10.20.10"

# Make DNS Server listen ONLY on 10.10.20.10 (Manual Part D7 Step 2)
$dnsSettings = Get-DnsServerSetting -All
$dnsSettings.ListeningIpAddress = @([System.Net.IPAddress]::Parse("10.10.20.10"))
Set-DnsServerSetting -InputObject $dnsSettings
Restart-Service DNS
Start-Sleep -Seconds 10
Get-Service DNS | Format-Table Name, Status

# Remove any NAT A records in atlas.local (non-10.10.20.x) (Manual Part D7 Step 3)
$badRecords = Get-DnsServerResourceRecord -ZoneName "atlas.local" -RRType A | Where-Object { $_.RecordData.IPv4Address.ToString() -notlike "10.10.20.*" }
if ($badRecords) {
    Write-Output "Removing unwanted NAT A records:"
    $badRecords | Format-Table HostName, @{N='IP';E={$_.RecordData.IPv4Address}}
    $badRecords | Remove-DnsServerResourceRecord -ZoneName "atlas.local" -Force
}
ipconfig /registerdns | Out-Null
Start-Sleep -Seconds 3

Write-Output "=== D7 Step 4: DNS Validation ==="
nslookup -type=A ATLAS-SRV.atlas.local 10.10.20.10
Resolve-DnsName ATLAS-SRV.atlas.local -Type A -Server 10.10.20.10 -DnsOnly
Resolve-DnsName _ldap._tcp.dc._msdcs.atlas.local -Type SRV -Server 10.10.20.10 -DnsOnly

Write-Output "=== D8: Configure DNS Forwarder & Windows Evaluation Activation ==="
$natGw = (Get-NetIPConfiguration -InterfaceAlias "Ethernet 2" -ErrorAction SilentlyContinue).IPv4DefaultGateway.NextHop
if ($natGw) {
    Write-Output "Adding DNS Forwarder: $natGw"
    try { Add-DnsServerForwarder -IPAddress $natGw -ErrorAction Stop } catch { Write-Output "Forwarder note: $_" }
}
try {
    Resolve-DnsName www.microsoft.com -ErrorAction Stop | Select-Object -First 3
} catch {
    Write-Output "External DNS test note: $_"
}
cscript //nologo C:\Windows\System32\slmgr.vbs /ato
cscript //nologo C:\Windows\System32\slmgr.vbs /dlv

Write-Output "=== D9: Create Fictional Atlas Staff Users & AtlasStaff Group ==="
$pw = ConvertTo-SecureString $StaffPasswordPlain -AsPlainText -Force
$users = @("k.amrani","y.benali","s.tahiri","admin.it","svc_backup")
foreach ($u in $users) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$u'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name $u -SamAccountName $u -UserPrincipalName "$u@atlas.local" -AccountPassword $pw -Enabled $true -PasswordNeverExpires $true
    }
}
if (-not (Get-ADGroup -Filter "Name -eq 'AtlasStaff'" -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name "AtlasStaff" -GroupScope Global
}
Add-ADGroupMember -Identity "AtlasStaff" -Members "k.amrani","y.benali","s.tahiri"
Add-ADGroupMember -Identity "Domain Admins" -Members "admin.it"
Get-ADUser -Filter * | Select-Object SamAccountName, Enabled | Format-Table -AutoSize
Get-ADGroupMember -Identity "AtlasStaff" | Select-Object SamAccountName | Format-Table -AutoSize
Get-ADGroupMember -Identity "Domain Admins" | Select-Object SamAccountName | Format-Table -AutoSize

Write-Output "=== D10: Configure Windows Security Auditing ==="
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
auditpol /set /category:"Account Logon" /success:enable /failure:enable
auditpol /set /category:"Account Management" /success:enable /failure:enable
auditpol /set /subcategory:"Other System Events" /success:enable /failure:enable
auditpol /get /subcategory:"Logon"

Write-Output "=== D11: Create C:\AtlasShare, payroll.txt, and Staff SMB Share ==="
New-Item -Path "C:\AtlasShare" -ItemType Directory -Force | Out-Null
"Payroll demo - fictional data only" | Out-File "C:\AtlasShare\payroll.txt" -Encoding utf8
# Configure NTFS filesystem ACLs aligned with least privilege: AtlasStaff = Modify, Domain Users = ReadAndExecute
icacls "C:\AtlasShare" /inheritance:r /grant "SYSTEM:(OI)(CI)F" /grant "BUILTIN\Administrators:(OI)(CI)F" /grant "ATLAS\AtlasStaff:(OI)(CI)M" /grant "ATLAS\Domain Users:(OI)(CI)RX" | Out-Null
if (-not (Get-SmbShare -Name "Staff" -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name "Staff" -Path "C:\AtlasShare" -ChangeAccess "ATLAS\AtlasStaff" -ReadAccess "ATLAS\Domain Users"
}
Get-SmbShareAccess -Name "Staff" | Format-Table -AutoSize
icacls "C:\AtlasShare"
