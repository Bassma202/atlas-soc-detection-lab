# Atlas SOC Lab — Operating & Live Demonstration Guide

This guide explains how to start, verify, manage snapshots, access credentials safely, and run a smooth live demonstration of the **Atlas SOC Lab** on Bassma's MacBook Air (Apple Silicon M5) for Dr Abubakar Wakili's Semester 9 practical evaluation.

---

## 1. Lab Components & Quick Reference

| Component | Hostname / Role | Private Lab IP (`10.10.20.0/24`) | Hypervisor / Mode | Credentials Vault Key |
|---|---|---|---|---|
| **Mac Host** | MacBook Air M5 (`bridge102`) | `10.10.20.1` | macOS `vmnet-host` | — |
| **Wazuh SIEM** | `WAZUH-ARM` (Ubuntu 24.04.5 ARM64) | `10.10.20.100` | UTM 5.0.9-2 (`-accel hvf`, native ARM64) | `wazuh_user`, `wazuh_dashboard_user` (`admin`) |
| **Domain Controller** | `ATLAS-SRV.atlas.local` (Win Server 2025 Eval x64) | `10.10.20.10` | UTM 5.0.9-2 (`-accel tcg,thread=multi`) | `atlas_win_admin_password`, `atlas_staff_password` |

- **Credentials Vault (Restricted `0600`):** `$HOME/Atlas-SOC-Lab-Storage/vault/atlas-lab-credentials.json`
- **SSH Private Key (Restricted `0600`):** `$HOME/Atlas-SOC-Lab-Storage/vault/atlas_ed25519`
- **Wazuh Dashboard URL:** `https://10.10.20.100` (accept self-signed lab certificate; sign in as `admin` using `wazuh_dashboard_password` from the vault).
- **Isolated Lab Storage (ISOs / Installers / Vault):** `$HOME/Atlas-SOC-Lab-Storage/`
- **Deliverables Workspace:** `$HOME/Atlas-SOC-Lab/`

---

## 2. Starting and Stopping the Laboratory

### Startup Sequence (Always Start Wazuh First)
1. Open **UTM** (`/Applications/UTM.app`).
2. Start **`WAZUH-ARM`** first and wait ~30–45 seconds until the Wazuh services are ready.
   - Verify from macOS Terminal:
     ```bash
     nc -vz 10.10.20.100 443
     nc -vz 10.10.20.100 1514
     ```
3. Start **`ATLAS-SRV`** and wait ~90–120 seconds for Windows Server 2025 AD DS, DNS, and `WazuhSvc` to initialize.
   - Verify from macOS Terminal:
     ```bash
     ping -c 3 10.10.20.10
     ```
4. Confirm `bridge102` is active on `10.10.20.1` (`ifconfig bridge102`). *(Note: macOS creates `bridge102` automatically once at least one VM attached to the Host-Only network is running.)*

### Clean Shutdown & Restart Sequence
1. Shut down **`ATLAS-SRV`** first (Windows Start → Power → Shut down, or via SSH: `Stop-Computer -Force`).
2. Shut down **`WAZUH-ARM`** second (via SSH: `sudo shutdown -h now`). *(Tip: Under UTM ARM64 UEFI `-accel hvf`, prefer shutting down and starting `WAZUH-ARM` cleanly from UTM — or `qmon.py wazuh-arm cmd "system_reset"` — rather than in-guest `sudo reboot`, which can occasionally stall at UEFI warm-reset.)*
3. Wait until both VMs show **Stopped** in UTM before closing the laptop lid or taking offline disk copies.

---

## 3. Managing Snapshots

Both VMs have verified QEMU QCOW2 internal snapshots stored directly inside their disk images and controllable via the local QEMU monitor helper (`automation/qmon.py`) while running:

```bash
# List snapshots on both VMs
$HOME/Atlas-SOC-Lab/automation/qmon.py wazuh-arm snapshots
$HOME/Atlas-SOC-Lab/automation/qmon.py atlas-srv snapshots

# Create a new named snapshot
$HOME/Atlas-SOC-Lab/automation/qmon.py atlas-srv savevm <snapshot-name>

# Restore a snapshot (via QEMU monitor while VM is running)
$HOME/Atlas-SOC-Lab/automation/qmon.py atlas-srv cmd "loadvm <snapshot-name>"
```

**Recorded Clean Recovery Points:**
- **`WAZUH-ARM`:** `Wazuh-clean`, `Wazuh-agent-connected`
- **`ATLAS-SRV`:** `ATLAS-SRV-fresh-windows-2025` (offline qcow2 snapshot), `ATLAS-SRV-domain-DNS-fixed`, `ATLAS-SRV-agent-connected`, `ATLAS-SRV-before-Part-G`, `ATLAS-SRV-PartG-verified`

---

## 4. Step-by-Step Live Demonstration Walkthrough (For Instructor Evaluation)

Follow this 10-minute sequence to demonstrate every mandatory and optional requirement cleanly:

1. **Private Network & Host Isolation (Part B — 1 min):**
   - Run `ifconfig bridge102` on macOS → show `inet 10.10.20.1 netmask 0xffffff00`.
   - Show `ip -br a && ip r` on `WAZUH-ARM` → `eth-atlas 10.10.20.100/24`, `eth-nat DOWN`, no default route.
   - Show `Get-NetIPConfiguration` on `ATLAS-SRV` → `Ethernet = 10.10.20.10`, no default gateway, `Ethernet 2` disabled.
2. **Active Directory, DNS, Activation, Auditing & Least-Privilege Share (Part D — 2 min):**
   - On `ATLAS-SRV` PowerShell (Admin):
     ```powershell
     hostname
     nslookup -type=A ATLAS-SRV.atlas.local 10.10.20.10
     slmgr /dlv
     auditpol /get /subcategory:"Logon"
     Get-ADUser -Filter * | Select-Object SamAccountName, Enabled
     Get-SmbShareAccess -Name Staff
     ```
   - Point out that `nslookup` returns **only `10.10.20.10`** (Part D7 multihomed DC fix), Windows Server 2025 is **Licensed (180 days)**, and `Staff` grants `Change` only to `AtlasStaff` and `Read` to `Domain Users`.
3. **Wazuh SIEM & Active Windows Agent (Parts C & E — 2 min):**
   - Open `https://10.10.20.100` in Safari/Chrome → **Endpoints Summary** → show Agent `001` (`ATLAS-SRV`, `10.10.20.10`, Windows Server 2025 Standard Evaluation, `v4.14.10`, **Active**).
   - Open **Threat Hunting → Events**, filter `agent.name: ATLAS-SRV` → show live Windows logon (`60106`) and logoff (`60137`) alerts.
4. **Incident Investigation & Custom Rule `100100` (Part F & Appendix E — 3 min):**
   - Filter `data.win.system.eventID:4625` in Threat Hunting → show `ATLAS\k.amrani` (`Rule 60122`, lvl 5, `Status 0xC000006D`, `SubStatus 0xC000006A`) and `ATLAS\svc_backup` (**Custom Rule `100100`**, lvl 10).
   - Filter `rule.groups:syscheck` → show realtime FIM **Rule `550`** (lvl 7) on `C:\AtlasShare\payroll.txt`.
   - Present `reports/SOC-Investigation-Ticket-ATLAS-001.md` and verify `shasum -a 256 evidence/windows-events/ATLAS-SRV_Security.evtx`.
5. **Optional Part G — IIS 8088 + Suricata 8.0.8 → Wazuh Integration (2 min):**
   - From macOS Terminal: `nc -vz 10.10.20.10 8088` and `curl -i http://10.10.20.10:8088/index.html` → show `HTTP/1.1 401 Unauthorized` + `WWW-Authenticate: Basic` (never submit real credentials).
   - Filter `rule.groups:suricata` in Wazuh Threat Hunting → show `ATLAS LAB portal TCP test` (`src_ip: 10.10.20.1`, `dest_ip: 10.10.20.10`, `dest_port: 8088`, `sid: 1000001`).

---

## 5. Safety & Isolation Rules
- **Never** expose `ATLAS-SRV` port `8088` (HTTP Basic Auth) or bridge either VM onto the campus/home Wi-Fi (`en0`).
- **Never** authenticate to `http://10.10.20.10:8088` with `ATLAS\Administrator`, domain service accounts, or any real password.
- **Never** commit `$HOME/Atlas-SOC-Lab-Storage/vault/` or push any lab files to external/public repositories.
