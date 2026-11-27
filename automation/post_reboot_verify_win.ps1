$ErrorActionPreference = 'Continue'
Write-Output "=================================================================="
Write-Output ("POST-REBOOT ACCEPTANCE VALIDATION — ATLAS-SRV (" + (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC") + ")")
Write-Output "=================================================================="

Write-Output "`n--- 1. Computer Name (hostname) ---"
hostname

Write-Output "`n--- 2. Network Configuration & Strict Isolation (Ethernet = 10.10.20.10, No GW; Ethernet 2 Disabled) ---"
Get-NetAdapter | Select-Object Name, Status, MacAddress, InterfaceGuid | Format-Table -AutoSize
Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway, DNSServer | Format-List

Write-Output "`n--- 3. Domain & DNS (nslookup must return ONLY 10.10.20.10) ---"
Get-ADForest | Select-Object Name, RootDomain, ForestMode | Format-Table -AutoSize
nslookup -type=A ATLAS-SRV.atlas.local 10.10.20.10
Resolve-DnsName ATLAS-SRV.atlas.local -Type A -Server 10.10.20.10 -DnsOnly | Format-Table Name, Type, IPAddress -AutoSize
Resolve-DnsName _ldap._tcp.dc._msdcs.atlas.local -Type SRV -Server 10.10.20.10 -DnsOnly | Format-Table Name, NameTarget, Port -AutoSize

Write-Output "`n--- 4. Windows Evaluation Activation (slmgr /dlv) ---"
cscript //Nologo C:\Windows\System32\slmgr.vbs /dlv

Write-Output "`n--- 5. Security Auditing (auditpol) ---"
auditpol /get /subcategory:"Logon","Logoff","Kerberos Authentication Service","User Account Management","Other System Events"

Write-Output "`n--- 6. Staff Accounts & Least-Privilege SMB Share ---"
Get-ADUser -Filter * | Where-Object { $_.SamAccountName -in 'k.amrani','y.benali','s.tahiri','admin.it','svc_backup' } | Select-Object SamAccountName, Enabled, PasswordNeverExpires | Format-Table -AutoSize
Get-SmbShareAccess -Name Staff | Format-Table Name, AccountName, AccessControlType, AccessRight -AutoSize

Write-Output "`n--- 7. Wazuh Ports (1515 & 1514) & Agent Service ---"
Test-NetConnection 10.10.20.100 -Port 1515 | Select-Object ComputerName, RemotePort, SourceAddress, TcpTestSucceeded | Format-Table -AutoSize
Test-NetConnection 10.10.20.100 -Port 1514 | Select-Object ComputerName, RemotePort, SourceAddress, TcpTestSucceeded | Format-Table -AutoSize
Get-Service WazuhSvc | Format-Table Status, Name, DisplayName -AutoSize
Select-String -Path "C:\Program Files (x86)\ossec-agent\wazuh-agent.state" -Pattern "^status"

Write-Output "`n--- 8. Verify Temporary Provisioning Controls Disabled ---"
winrm get winrm/config/service | Select-String "Basic|AllowUnencrypted"
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon, DefaultPassword -ErrorAction SilentlyContinue | Select-Object AutoAdminLogon, DefaultPassword | Format-List

Write-Output "`n--- 9. Part G Components Present (IIS 8088 + Suricata 8.0.8 + Npcap) ---"
Import-Module WebAdministration -ErrorAction SilentlyContinue
Get-Service W3SVC, npcap -ErrorAction SilentlyContinue | Format-Table Status, Name, DisplayName -AutoSize
Get-WebBinding -Name "Default Web Site" -ErrorAction SilentlyContinue | Format-Table protocol, bindingInformation -AutoSize
& "C:\Program Files\Suricata\suricata.exe" -V 2>&1
