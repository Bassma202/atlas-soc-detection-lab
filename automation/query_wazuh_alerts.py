#!/usr/bin/env python3
"""Query and export real Wazuh alerts from WAZUH-ARM (/var/ossec/logs/alerts/alerts.json) via SSH."""
import argparse
import csv
import json
import subprocess
import sys

SSH_KEY = "$HOME/Atlas-SOC-Lab-Storage/vault/atlas_ed25519"
WAZUH_HOST = "wazuh-user@10.10.20.100"


def fetch_alerts(limit: int = 2000) -> list[dict]:
    raw = subprocess.check_output([
        "ssh", "-i", SSH_KEY, "-o", "StrictHostKeyChecking=no", WAZUH_HOST,
        f"sudo tail -n {limit} /var/ossec/logs/alerts/alerts.json"
    ]).decode("utf-8", errors="replace")
    alerts = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            alerts.append(json.loads(line))
        except Exception:
            pass
    return alerts


def get_nested(d: dict, dotted: str, default=""):
    cur = d
    for part in dotted.split("."):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            return default
    return cur


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--agent", default="")
    ap.add_argument("--rule-id", default="")
    ap.add_argument("--event-id", default="")
    ap.add_argument("--group", default="")
    ap.add_argument("--tail", type=int, default=2000)
    ap.add_argument("--out-json", default="")
    ap.add_argument("--out-csv", default="")
    args = ap.parse_args()

    alerts = fetch_alerts(args.tail)
    filtered = []
    for a in alerts:
        if args.agent and get_nested(a, "agent.name") != args.agent:
            continue
        if args.rule_id and str(get_nested(a, "rule.id")) != str(args.rule_id):
            continue
        if args.event_id and str(get_nested(a, "data.win.system.eventID")) != str(args.event_id):
            continue
        if args.group and args.group not in (get_nested(a, "rule.groups", []) or []):
            continue
        filtered.append(a)

    print(f"Matched {len(filtered)} alerts (from last {len(alerts)} total)")
    for a in filtered[-15:]:
        print(
            f"{a.get('timestamp','')} | agent={get_nested(a,'agent.name')} | "
            f"rule={get_nested(a,'rule.id')} (lvl {get_nested(a,'rule.level')}) | "
            f"ev={get_nested(a,'data.win.system.eventID')} | "
            f"user={get_nested(a,'data.win.eventdata.targetUserName')} | "
            f"desc={get_nested(a,'rule.description')}"
        )

    if args.out_json:
        with open(args.out_json, "w", encoding="utf-8") as f:
            json.dump(filtered, f, indent=2)
        print("Wrote JSON:", args.out_json)

    if args.out_csv:
        fields = [
            "timestamp", "id", "agent.id", "agent.name", "rule.id", "rule.level",
            "rule.description", "rule.groups", "data.win.system.eventID",
            "data.win.system.eventRecordID", "data.win.system.systemTime",
            "data.win.eventdata.targetUserName", "data.win.eventdata.targetDomainName",
            "data.win.eventdata.logonType", "data.win.eventdata.ipAddress",
            "data.win.eventdata.status", "data.win.eventdata.subStatus",
            "syscheck.path", "syscheck.event", "data.alert.signature", "data.src_ip",
            "data.dest_ip", "data.dest_port"
        ]
        with open(args.out_csv, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(fields)
            for a in filtered:
                row = []
                for k in fields:
                    v = get_nested(a, k, "")
                    if isinstance(v, list):
                        v = ",".join(str(x) for x in v)
                    row.append(v)
                w.writerow(row)
        print("Wrote CSV:", args.out_csv)


if __name__ == "__main__":
    main()
