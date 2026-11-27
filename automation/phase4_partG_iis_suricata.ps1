# Atlas SOC Lab - ATLAS-SRV Phase 4: Optional Network IDS Extensions (Part G - IIS 8088 + Suricata 8.0.8 + Wazuh EVE JSON)
$ErrorActionPreference = 'Stop'

Write-Output "=== G1.1: Install IIS & Basic Authentication ==="
Install-WindowsFeature -Name Web-Server, Web-Basic-Auth, Web-Mgmt-Tools -IncludeManagementTools
Import-Module WebAdministration

Write-Output "=== G1.2: Create Fictional Atlas Staff Timesheets Page ==="
$page = @'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Atlas Staff Timesheets</title></head>
<body><h1>Atlas Staff Timesheets</h1><p>Fictional training portal — no real data.</p></body></html>
'@
Set-Content -Path "C:\inetpub\wwwroot\index.html" -Value $page -Encoding UTF8
Test-Path "C:\inetpub\wwwroot\index.html"
Get-Content "C:\inetpub\wwwroot\index.html"

Write-Output "=== G1.3: Bind Port 8088 on 10.10.20.10 & Enable Basic Auth Only ==="
if (-not (Get-WebBinding -Name "Default Web Site" -Port 8088 -ErrorAction SilentlyContinue)) {
    New-WebBinding -Name "Default Web Site" -Protocol http -IPAddress "10.10.20.10" -Port 8088
}
# Ensure index.html is top Default Document
$defaultDocs = Get-WebConfigurationProperty -Filter "//defaultDocument/files/add" -PSPath "IIS:\Sites\Default Web Site" -Name value | Select-Object -ExpandProperty Value
if ($defaultDocs -notcontains "index.html") {
    Add-WebConfigurationProperty -Filter "//defaultDocument/files" -PSPath "IIS:\Sites\Default Web Site" -Name "." -Value @{value="index.html"} -AtIndex 0
}
# Disable Anonymous Auth, Enable Basic Auth (isolated lab only)
Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/anonymousAuthentication" -PSPath "IIS:\" -Location "Default Web Site" -Name enabled -Value $false
Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/basicAuthentication" -PSPath "IIS:\" -Location "Default Web Site" -Name enabled -Value $true
Start-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
Get-Website -Name "Default Web Site"
Get-WebBinding -Name "Default Web Site"
Get-Service W3SVC

Write-Output "=== G1.4: Narrowly Scoped Inbound Firewall Rule (10.10.20.1 -> 10.10.20.10:8088) ==="
if (-not (Get-NetFirewallRule -DisplayName "Atlas Lab IIS 8088" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName "Atlas Lab IIS 8088" -Direction Inbound `
        -Protocol TCP -LocalPort 8088 -LocalAddress 10.10.20.10 `
        -RemoteAddress 10.10.20.1 -Action Allow -Profile Any | Out-Null
}
Get-NetTCPConnection -LocalPort 8088 -State Listen -ErrorAction SilentlyContinue
Test-NetConnection 10.10.20.10 -Port 8088 | Select-Object ComputerName, RemotePort, TcpTestSucceeded

Write-Output "=== G2.1: Install Suricata 8.0.8 ==="
if (-not (Test-Path "C:\Program Files\Suricata\suricata.exe")) {
    $sp = Start-Process msiexec.exe -Wait -PassThru -ArgumentList '/i "C:\Temp\Suricata-8.0.8-1-64bit.msi" /qn /L*v "C:\Temp\suricata-install.log"'
    Write-Output "Suricata msiexec ExitCode: $($sp.ExitCode)"
}
& "C:\Program Files\Suricata\suricata.exe" -V

Write-Output "=== G2.2: Back up suricata.yaml & Configure HOME_NET = [10.10.20.0/24] ==="
$suriYaml = "C:\Program Files\Suricata\suricata.yaml"
if (-not (Test-Path "$suriYaml.bak")) {
    Copy-Item $suriYaml "$suriYaml.bak"
}
$yaml = Get-Content $suriYaml -Raw
$yaml = $yaml -replace '(?m)^(\s*HOME_NET:\s*).*$', '${1}"[10.10.20.0/24]"'
Set-Content -Path $suriYaml -Value $yaml -Encoding UTF8

$guid = [guid](Get-NetAdapter -Name "Ethernet").InterfaceGuid
$device = '\Device\NPF_' + $guid.ToString("B")
Write-Output "Suricata Capture Device (Host-Only Ethernet): $device"

Write-Output "=== G2.3: Write Harmless Portal TCP Signature & Validate with suricata -T ==="
New-Item -Path "C:\Program Files\Suricata\log" -ItemType Directory -Force | Out-Null
'alert tcp 10.10.20.1 any -> 10.10.20.10 8088 (msg:"ATLAS LAB portal TCP test"; flow:to_server; flags:S; sid:1000001; rev:2;)' | Set-Content "C:\Temp\atlas-test.rules" -Encoding ascii
& "C:\Program Files\Suricata\suricata.exe" -T -c $suriYaml -S "C:\Temp\atlas-test.rules" -l "C:\Program Files\Suricata\log"

Write-Output "=== G2.6: Configure Wazuh Agent to Ingest Suricata eve.json ==="
$conf = "C:\Program Files (x86)\ossec-agent\ossec.conf"
if (-not (Test-Path "C:\Temp\ossec-before-suricata.conf")) {
    Copy-Item $conf "C:\Temp\ossec-before-suricata.conf"
}
$confText = Get-Content $conf -Raw
if ($confText -notmatch 'Suricata\\log\\eve\.json') {
    $block = "`r`n  <localfile>`r`n    <log_format>json</log_format>`r`n    <location>C:\Program Files\Suricata\log\eve.json</location>`r`n  </localfile>`r`n</ossec_config>"
    $lastIdx = $confText.LastIndexOf("</ossec_config>")
    $confText = $confText.Substring(0, $lastIdx) + $block
    Set-Content -Path $conf -Value $confText -Encoding UTF8
}
Select-String -Path $conf -Pattern "eve.json" -Context 3,2
Restart-Service WazuhSvc
Get-Service WazuhSvc
