# Atlas SOC Lab — Software Version & Dependency Manifest

All software components, operating system images, and vendor installers were obtained from official vendor sources and cryptographically verified prior to deployment. Large binaries are stored outside the deliverables folder under `/Users/bassma/Atlas-SOC-Lab-Storage/` without duplication.

---

## 1. Host & Virtualization Infrastructure

| Component | Exact Installed Version | Architecture | Source / Storage Location | SHA-256 Verification |
|---|---|---|---|---|
| **Host OS** | macOS 26.4 | `arm64` (Apple M5, 10 cores, 24 GB RAM) | Local MacBook Air M5 | N/A |
| **UTM Hypervisor** | `5.0.9-2` (bundled QEMU `10.0.12`) | Universal (`arm64` HVF + `x86_64` TCG) | `/Applications/UTM.app` (`Atlas-SOC-Lab-Storage/installers/UTM-5.0.9-2.dmg`) | `1a76ddcf61ab424a5ae1d1b68a16a9b2e84b748716afce905ee77740d8e86127` |
| **Guest VirtIO Drivers** | UTM Guest Tools `0.1.271` (`2k25/amd64` signed) | `x86_64` | `Atlas-SOC-Lab-Storage/isos/utm-guest-tools-0.1.271.iso` (121 MB) | `65b6a69b392ee01dd314c10f3dad9ebbf9c4160be43f5f0dd6bb715944d9095b` |

## 2. Virtual Machine Operating Systems

| VM Name | Operating System | Exact Build / Release | Architecture / Accel | Source Image | SHA-256 Verification |
|---|---|---|---|---|---|
| **`WAZUH-ARM`** | Ubuntu Server 24.04.5 LTS (Noble Numbat) | Cloud Image (`arm64`) | `arm64` (Apple `hvf`) | `Atlas-SOC-Lab-Storage/isos/noble-server-cloudimg-arm64.img` (588 MB) | Verified `OK` against official Canonical `noble-SHA256SUMS` |
| **`ATLAS-SRV`** | Windows Server 2025 Standard Evaluation (Desktop Experience) | `10.0.26100.1742` (`ge_release.240331-1435`), **Licensed 180 days** | `x86_64` (QEMU `tcg,thread=multi`, `q35`, UEFI + `swtpm` TPM 2.0) | `Atlas-SOC-Lab-Storage/isos/WinServer2025_Eval_x64_26100.iso` (5.6 GB) | `d0ef4502e350e3c6c53c15b1b3020d38a5ded011bf04998e950720ac8579b23d` |

## 3. Security, Monitoring & Network IDS Software

| Component | Target VM | Installed Version | Official Package / Installer | SHA-256 Checksum | Notes |
|---|---|---|---|---|---|
| **Wazuh Stack** (Manager, Indexer, Dashboard, Filebeat) | `WAZUH-ARM` | **`v4.14.11`** | `wazuh-install.sh` (`packages.wazuh.com/4.14/`) | `562387455e91b7bad06e7cb6fb21fc1cc3666c7e4dce7500c93c5286785ebf35` | Upstream 4.14 channel updated from `4.14.10` to `4.14.11`; fully compatible with `4.14.10` agent |
| **Wazuh Windows Agent** | `ATLAS-SRV` | **`v4.14.10-1`** | `wazuh-agent-4.14.10-1.msi` (5.8 MB) | `446bd5434a463f64c498f31240caabbb654091ea461131a31e71821a0261e823` | Installed via `msiexec /qn`, `ExitCode: 0`, Agent ID `001` |
| **Suricata NIDS** (Part G) | `ATLAS-SRV` | **`8.0.8 RELEASE`** | `Suricata-8.0.8-1-64bit.msi` (35 MB) | `7c6b302e51a166c5b87b383ff2550406bc72faba9d690bd3a0532869a95dd084` | Installed to `C:\Program Files\Suricata`; `suricata -T` passed (`ExitCode 0`) |
| **Npcap Packet Driver** (Part G) | `ATLAS-SRV` | **`1.90`** | `npcap-1.90.exe` (1.3 MB) | `682b57e1c05ef375931975c9d6ded40888f4bfdf9f4b11571e654f962f1199b6` | WinPcap API-compatible mode; service `npcap` `Running`, `wpcap.dll` verified |
| **Microsoft IIS** (Part G) | `ATLAS-SRV` | **IIS 10.0** (`Web-Server`, `Web-Basic-Auth`, `Web-Mgmt-Tools`) | Windows Server 2025 built-in feature | OS-native signed role | Bound to `10.10.20.10:8088`; isolated via narrow FW rule from `10.10.20.1` |

## 4. Local Automation & Documentation Dependencies (Host Only)
- **Python 3.9** (`/usr/bin/python3`) + isolated venv `/Users/bassma/Atlas-SOC-Lab-Storage/doc-venv/` (`python-docx 1.2.0`, `Pillow`, `PyMuPDF / fitz`) — used exclusively for local report generation and PDF visual QA.
- **Node.js** (`/Users/bassma/.local/bin/node`) + **Google Chrome** headless CDP — used for isolated `1920×1080` Wazuh Dashboard screenshots, SVG→PNG rendering, and A4 PDF generation.
- **Git** (`/usr/bin/git`) & **GitHub CLI (`gh`)** (`/Users/bassma/.local/bin/gh`, authenticated as `Bassma202`) — used for private repository publication.
