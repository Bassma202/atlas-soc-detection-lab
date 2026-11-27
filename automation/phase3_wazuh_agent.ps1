# Atlas SOC Lab - ATLAS-SRV Phase 3: Connect Windows Server 2025 to Wazuh Manager (Part E) + FIM (Appendix E)
param(
    [string]$WazuhManagerIp = "10.10.20.100",
    [string]$AgentName = "ATLAS-SRV",
    [string]$AgentMsi = "C:\Temp\wazuh-agent-4.14.10-1.msi"
)
$ErrorActionPreference = 'Stop'

Write-Output "=== E1: Test Wazuh Manager Ports 1515 & 1514 ==="
Test-NetConnection $WazuhManagerIp -Port 1515 | Select-Object ComputerName, RemotePort, SourceAddress, TcpTestSucceeded
Test-NetConnection $WazuhManagerIp -Port 1514 | Select-Object ComputerName, RemotePort, SourceAddress, TcpTestSucceeded

Write-Output "=== E2/E3: Install Wazuh Windows Agent ==="
if (-not (Test-Path $AgentMsi)) { throw "Missing MSI: $AgentMsi" }
$p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/i `"$AgentMsi`" /qn WAZUH_MANAGER=`"$WazuhManagerIp`" WAZUH_AGENT_NAME=`"$AgentName`" /L*v `"C:\Temp\wazuh-install.log`""
Write-Output "msiexec ExitCode: $($p.ExitCode)"
if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { throw "Wazuh Agent MSI install failed with code $($p.ExitCode)" }

Write-Output "=== Configure Realtime File Integrity Monitoring (FIM) on C:\AtlasShare ==="
$conf = "C:\Program Files (x86)\ossec-agent\ossec.conf"
Copy-Item $conf "C:\Temp\ossec-initial.conf" -Force
$xmlText = Get-Content $conf -Raw
if ($xmlText -notmatch 'C:\\AtlasShare') {
    $fimEntry = "    <directories check_all=`"yes`" realtime=`"yes`" report_changes=`"yes`">C:\AtlasShare</directories>`r`n  </syscheck>"
    $xmlText = $xmlText -replace '</syscheck>', $fimEntry
    Set-Content -Path $conf -Value $xmlText -Encoding UTF8
}

Write-Output "=== E4: Start and Verify WazuhSvc ==="
Restart-Service WazuhSvc -ErrorAction SilentlyContinue
Start-Service WazuhSvc -ErrorAction SilentlyContinue
Start-Sleep -Seconds 8
Get-Service WazuhSvc
Select-String -Path "C:\Program Files (x86)\ossec-agent\wazuh-agent.state" -Pattern "^status"
