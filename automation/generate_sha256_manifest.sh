#!/usr/bin/env bash
set -euo pipefail
BASE="$HOME/Atlas-SOC-Lab"
OUT="$BASE/evidence/hashes/SHA256SUMS.txt"
mkdir -p "$BASE/evidence/hashes"

{
  echo "# Atlas SOC Lab — Cryptographic Evidence Manifest (SHA-256)"
  echo "# Generated UTC: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "# Verify with: cd $HOME/Atlas-SOC-Lab && shasum -a 256 -c evidence/hashes/SHA256SUMS.txt"
  cd "$BASE"
  shasum -a 256 \
    evidence/windows-events/* \
    evidence/wazuh-alerts/* \
    evidence/suricata/* \
    evidence/screenshots/*.png \
    configurations/*
} > "$OUT"

echo "Wrote $OUT"
cd "$BASE" && shasum -a 256 -c evidence/hashes/SHA256SUMS.txt | tail -n 10
