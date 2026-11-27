$ErrorActionPreference = 'Continue'
Write-Output "=== Disabling Temporary Provisioning Controls & NAT Adapter ==="
# 1. Disable temporary WinRM insecure settings (keep SSH key auth for local admin)
winrm set winrm/config/service/auth '@{Basic="false"}'
winrm set winrm/config/service '@{AllowUnencrypted="false"}'
# 2. Clean up temporary scheduled tasks
Unregister-ScheduledTask -TaskName "AtlasCleanAutoLogon" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "AtlasEvidenceView" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "AtlasInstallNpcap" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "AtlasInstallNpcapUIA" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "AtlasSuricataCapture" -Confirm:$false -ErrorAction SilentlyContinue
# 3. Verify Winlogon AutoAdminLogon is disabled and DefaultPassword absent
Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultPassword, AutoLogonCount -ErrorAction SilentlyContinue
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon -Value "0"
# 4. Disable temporary NAT adapter (Ethernet 2) so ATLAS-SRV is 100% isolated on 10.10.20.0/24
Disable-NetAdapter -Name "Ethernet 2" -Confirm:$false -ErrorAction SilentlyContinue
# 5. Remove stale NAT A-record from DNS if re-registered while Ethernet 2 was active
Remove-DnsServerResourceRecord -ZoneName "atlas.local" -RRType "A" -Name "ATLAS-SRV" -RecordData "192.168.64.2" -Force -ErrorAction SilentlyContinue
Remove-DnsServerResourceRecord -ZoneName "atlas.local" -RRType "A" -Name "@" -RecordData "192.168.64.2" -Force -ErrorAction SilentlyContinue
ipconfig /registerdns | Out-Null
Restart-Service DNS
Start-Sleep -Seconds 6
Write-Output "=== Isolation & Cleanup Summary ==="
Get-NetAdapter | Select-Object Name, Status, MacAddress | Format-Table -AutoSize
winrm get winrm/config/service | Select-String "Basic|AllowUnencrypted"
nslookup -type=A ATLAS-SRV.atlas.local 10.10.20.10
