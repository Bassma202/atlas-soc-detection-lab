param([ValidateSet('start','inspect','stop','diag')][string]$Action = 'start')
$ErrorActionPreference = 'Continue'
$suri = "C:\Program Files\Suricata\suricata.exe"
$yaml = "C:\Program Files\Suricata\suricata.yaml"
$rules = "C:\Temp\atlas-test.rules"
$logDir = "C:\Program Files\Suricata\log"
$eve = Join-Path $logDir "eve.json"

if ($Action -eq 'diag') {
    Write-Output "=== Npcap Service & Drivers ==="
    Get-Service npcap -ErrorAction SilentlyContinue | Format-Table -AutoSize
    sc.exe query npcap
    Write-Output "=== Suricata Log Directory ==="
    Get-ChildItem $logDir -ErrorAction SilentlyContinue | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
    Write-Output "=== suricata.log ==="
    Get-Content (Join-Path $logDir "suricata.log") -Tail 30 -ErrorAction SilentlyContinue
    Write-Output "=== Live Capture Wrapper Log ==="
    Get-Content "C:\Temp\suricata_live.log" -Tail 30 -ErrorAction SilentlyContinue
}
elseif ($Action -eq 'start') {
    Write-Output "=== Check Existing Suricata Processes ==="
    Get-Process suricata -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # Ensure npcap service is started and WazuhSvc is running
    Start-Service npcap -ErrorAction SilentlyContinue
    Get-Service npcap -ErrorAction SilentlyContinue | Format-Table Status, Name, DisplayName -AutoSize
    if ((Get-Service WazuhSvc).Status -ne 'Running') {
        Start-Service WazuhSvc
        Start-Sleep -Seconds 4
    }
    Get-Service WazuhSvc | Format-Table Status, Name, DisplayName -AutoSize

    # Use UPPERCASE InterfaceGuid matching Windows Npcap device path
    $rawGuid = (Get-NetAdapter -Name "Ethernet").InterfaceGuid
    $device = '\Device\NPF_' + $rawGuid.ToUpper()
    Write-Output "Host-Only Capture Interface: $device"

    # Wrapper script captures stdout/stderr to C:\Temp\suricata_live.log
    $wrapper = @"
& "$suri" -c "$yaml" -i "$device" -S "$rules" -l "$logDir" -v *>&1 | Out-File -FilePath "C:\Temp\suricata_live.log" -Encoding utf8
"@
    Set-Content -Path "C:\Temp\start_suri_bg.ps1" -Value $wrapper -Encoding UTF8
    Remove-Item "C:\Temp\suricata_live.log" -Force -ErrorAction SilentlyContinue

    $act = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\Temp\start_suri_bg.ps1"
    $prin = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "AtlasSuricataCapture" -Action $act -Principal $prin -Force | Out-Null
    Start-ScheduledTask -TaskName "AtlasSuricataCapture"

    # Wait up to 40s for Suricata to log "Engine started" (ignoring non-fatal threshold.config warning)
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Seconds 2
        if (Test-Path "C:\Temp\suricata_live.log") {
            $txt = Get-Content "C:\Temp\suricata_live.log" -Raw -ErrorAction SilentlyContinue
            if ($txt -match "Engine started" -or $txt -match "ERRCODE") {
                break
            }
        }
    }
    Get-Process suricata -ErrorAction SilentlyContinue | Select-Object Name, Id, StartTime | Format-Table -AutoSize
    Write-Output "--- C:\Temp\suricata_live.log ---"
    Get-Content "C:\Temp\suricata_live.log" -Tail 30 -ErrorAction SilentlyContinue
}
elseif ($Action -eq 'inspect') {
    Write-Output "=== Inspect Suricata eve.json ==="
    Write-Output ("eve.json exists: " + (Test-Path $eve))
    if (Test-Path $eve) {
        Write-Output ("eve.json size: " + (Get-Item $eve).Length + " bytes")
        Write-Output "--- Tail 5 Raw JSON Lines ---"
        Get-Content $eve -Tail 5
        Write-Output "--- Filtered Alert Events (event_type=alert) ---"
        Get-Content $eve | Where-Object { $_ -match '"event_type":"alert"' } | Select-Object -Last 10 | ForEach-Object {
            $_ | ConvertFrom-Json | Select-Object timestamp, src_ip, dest_ip, dest_port, @{Name="Signature";Expression={$_.alert.signature}}, @{Name="SID";Expression={$_.alert.signature_id}}
        } | Format-Table -AutoSize
        Write-Output "--- SHA-256 Hash of eve.json ---"
        Get-FileHash $eve -Algorithm SHA256 | Format-List
    }
    Write-Output "--- Recent Wazuh Agent ossec.log (eve.json / suricata / Connected) ---"
    Select-String -Path "C:\Program Files (x86)\ossec-agent\ossec.log" -Pattern "eve\.json|suricata|Connected|Analyzing" | Select-Object -Last 12 | ForEach-Object { $_.Line }
}
elseif ($Action -eq 'stop') {
    Write-Output "=== Stop Suricata Capture Cleanly ==="
    Get-Process suricata -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName "AtlasSuricataCapture" -Confirm:$false -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    $rem = @(Get-Process suricata -ErrorAction SilentlyContinue)
    Write-Output ("Remaining suricata processes: " + $rem.Count)
}
