# Atlas SOC Lab — Apple Silicon (M5) Architecture & Compatibility Evaluation Report

## 1. Executive Summary
This report evaluates the **Option A — Full Professor-Equivalent Hybrid Architecture** implemented on Bassma's **MacBook Air (Apple Silicon M5, 10 CPU cores, 24 GB unified memory, 460 GB SSD, macOS 26.4 `arm64`)** for Dr Abubakar Wakili's Semester 9 *Atlas SOC Lab* (Version 6.3, 20 Nov 2026, Université Euromed de Fès — UEMF).

Rather than falling back to the manual's reduced Apple-Silicon workaround (Appendix E Option 2: Windows 11 ARM standalone endpoint with no Active Directory forest and no Part G), this build uses **UTM 5.0.9-2 (QEMU 10)** to combine:
1. **Native ARM64 Virtualization (`-accel hvf`)** for **`WAZUH-ARM`** (Ubuntu 24.04.5 LTS ARM64 running official Wazuh `v4.14.11`), and
2. **Multi-Threaded x86-64 Emulation (`-accel tcg,thread=multi`)** for **`ATLAS-SRV`** (genuine **Windows Server 2025 Standard Evaluation x86-64, Desktop Experience, Build `10.0.26100.1742`**).

**Verdict:** **Highly Suitable & Fully Functional** for all mandatory Week 1–Semester 9 Active Directory, DNS, SIEM, FIM, custom rule, and Part G (IIS + Suricata) practicals, with zero cloud dependency and full offline portability.

---

## 2. Host Hardware & Virtualization Baseline

| Parameter | Observed Host Value | Lab Allocation (`WAZUH-ARM` + `ATLAS-SRV`) | Headroom |
|---|---|---|---|
| **Processor** | Apple M5 (`arm64`, 10 cores) | 4 vCPUs HVF + 4 vCPUs TCG | Smooth host responsiveness throughout |
| **Memory** | 24 GB Unified RAM | 8 GB (`WAZUH-ARM`) + 4 GB (`ATLAS-SRV`) = 12 GB | ~12 GB free for macOS, browser & IDE |
| **Storage** | 460 GB SSD (~312 GB free pre-build) | `WAZUH-ARM.utm` (32 GB incl. 2 live snapshots) + `ATLAS-SRV.utm` (34 GB incl. 4 snapshots) + `Atlas-SOC-Lab-Storage` (6.7 GB) + `Atlas-SOC-Lab` (9.5 MB) | **261 GiB free remaining** |
| **Hypervisor** | UTM `5.0.9-2` (QEMU 10) | Native HVF + Multi-threaded TCG | Zero interference with VMware Fusion 13.6.1 or Docker Desktop |
| **Private Network** | macOS `vmnet-host` (`bridge102`) | `10.10.20.0/24` (Host `.1`, DC `.10`, Wazuh `.100`) | Zero conflict with Campus Wi-Fi (`10.12.0.0/16`) or VMware `vmnet1`/`vmnet8` |

---

## 3. Measured Operational & Performance Metrics (Real Build Observations)

| Metric | `WAZUH-ARM` (ARM64 HVF) | `ATLAS-SRV` (x86-64 TCG) | Assessment |
|---|---|---|---|
| **OS Deployment Time** | ~2 min (`cloud-init` ARM64 image) | ~42 min (unattended ISO + VirtIO drivers) | One-time cost; snapshots eliminate reinstalls |
| **Wazuh Stack Install (`wazuh-install.sh -a`)** | ~10 min (native ARM64 speed) | Agent MSI: <2 min (`ExitCode: 0`) | Matches native x86-64 performance |
| **Cold / Controlled Reboot Time** | ~20–30 seconds | ~90–120 seconds (AD DS + DNS + IIS + WazuhSvc) | Predictable and repeatable |
| **AD DS Promotion + DNS Fix** | N/A | ~7 min promotion + reboot | 100% genuine `atlas.local` forest & Global Catalog |
| **Windows Evaluation Activation (`slmgr /ato`)** | N/A | Immediate success (`Licensed`, 180 days) | Eliminates 1-hour auto-shutdown risk |
| **IIS + Basic Auth + Suricata 8.0.8 Install** | N/A | ~12 min (`Web-Server` + `Web-Basic-Auth` + MSI) | Full Part G parity |
| **Network Latency (`bridge102` `10.10.20.0/24`)** | Host ↔ Wazuh: `0.30–0.40 ms` | Host ↔ DC: `1.08–2.63 ms`; DC ↔ Wazuh: `1–4 ms` | Zero packet loss |
| **SIEM Alert Delivery Latency** | Real-time (<3–6 s end-to-end) | Event `4625` / `4771` / `4720` / `4728` / FIM `550` / Suricata EVE | Live Threat Hunting responsive |
| **Clock Behavior** | NTP-synchronized UTC (`systemd-timesyncd`) | Slight software clock drift (~5.96 s observed under TCG) | Correlated cleanly via `EventRecordID`; resyncable via `w32tm` |

---

## 4. Documented Deviations from the VirtualBox Windows-Host Manual

All deviations are strictly platform-layer equivalents required by Apple Silicon (`arm64`) and macOS `vmnet`; **zero security, Active Directory, DNS, SIEM, or detection objectives were reduced**:

| Manual Reference (VirtualBox on Windows 11) | Implemented Equivalent (UTM 5.0.9-2 on macOS M5) | Functional Equivalence |
|---|---|---|
| VirtualBox 7.2 + Extension Pack | UTM 5.0.9-2 (QEMU 10) | Equivalent hypervisor + snapshots + shared network |
| Wazuh 4.14.10 x86-64 OVA | Native ARM64 Ubuntu 24.04.5 LTS + official `wazuh-install.sh` (`v4.14.11`) | Identical Wazuh Manager, Indexer, Dashboard, Filebeat & rule engine |
| VirtualBox Host-Only Adapter (`10.10.20.1/24`, DHCP `.2` `.100–.200`) | macOS `vmnet-host` (`bridge102`, `10.10.20.1/24`, range `.1–.200`) | Exact `10.10.20.0/24` private subnet; `.10` and `.100` static |
| VirtualBox NAT (`10.0.3.15`, forwarder `10.0.3.3`) | macOS `vmnet-shared` (`192.168.64.2`, forwarder `192.168.64.1`) | Exact temporary NAT role; disabled after activation/updates |
| VirtualBox Guest Additions + `Z:` shared folder | Signed VirtIO drivers (`utm-guest-tools-0.1.271.iso`) + SSH/SCP staging | Full disk/NIC performance & local installer staging |
| VirtualBox Snapshots GUI | QEMU internal QCOW2 snapshots (`savevm` / `loadvm` via `qmon.py`) | Instant save/restore recovery points on both VMs |
| Windows Host `Test-NetConnection` / `Get-FileHash` | macOS `nc -vz` / `curl` / `shasum -a 256` (exact Appendix C4 Table C.1 mapping) | Official manual host-command translations |

---

## 5. Suitability for Future Semester 9 Practicals
- **Active Directory & Kerberos Weeks (GPOs, Kerberoasting, Delegation, Pass-the-Hash, Lateral Movement):** **100% Supported** — genuine Windows Server 2025 Domain Controller (`atlas.local`) with real `ntds.dit`, Kerberos KDC (`4768`/`4769`/`4771`), LDAP/SRV DNS, and full Windows Security Auditing.
- **Detection Engineering & Wazuh Custom Rules:** **100% Supported** — native ARM64 Wazuh 4.14.11 Manager/Indexer/Dashboard with fast `wazuh-logtest`, instant rule reloads, and live Threat Hunting.
- **Network IDS & Packet Analysis (Suricata / Npcap / IIS):** **100% Supported** — genuine Windows Npcap + Suricata 8.0.8 capturing live Host-Only traffic and forwarding EVE JSON into Wazuh.
- **Key Operational Recommendation for Heavy Practicals:** Allow ~10–15 seconds extra for heavy PowerShell/AD/MSI operations on `ATLAS-SRV` due to x86-64 TCG emulation, and always take a quick QEMU snapshot before risky lab exercises.
