#!/usr/bin/env python3
"""Atlas SOC Lab - Local QEMU HMP Monitor helper (127.0.0.1:4444 / 4445)."""
import argparse
import os
import socket
import subprocess
import sys
import time

PORTS = {
    "atlas-srv": 4444,
    "wazuh-arm": 4445,
}
UTM_GROUP = "/Users/bassma/Library/Group Containers/WDNLXAD4W8.com.utmapp.UTM"


def qmon_cmd(port: int, cmd: str, wait: float = 0.6) -> str:
    s = socket.create_connection(("127.0.0.1", port), timeout=5)
    s.settimeout(1.0)
    try:
        s.recv(4096)
    except Exception:
        pass
    s.sendall((cmd + "\n").encode())
    time.sleep(wait)
    out = b""
    try:
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            out += chunk
    except Exception:
        pass
    s.close()
    return out.decode(errors="replace")


def screendump(vm: str, png_path: str) -> None:
    port = PORTS[vm]
    ppm = os.path.join(UTM_GROUP, f"{vm}_dump.ppm")
    qmon_cmd(port, f'screendump "{ppm}"', wait=0.8)
    os.makedirs(os.path.dirname(os.path.abspath(png_path)), exist_ok=True)
    subprocess.check_call(["sips", "-s", "format", "png", ppm, "--out", png_path],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"Saved {png_path}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("vm", choices=list(PORTS.keys()))
    ap.add_argument("action", choices=["cmd", "screendump", "sendkey", "savevm", "snapshots"])
    ap.add_argument("arg", nargs="?", default="")
    args = ap.parse_args()
    port = PORTS[args.vm]
    if args.action == "screendump":
        screendump(args.vm, args.arg)
    elif args.action == "sendkey":
        print(qmon_cmd(port, f"sendkey {args.arg}"))
    elif args.action == "savevm":
        print(qmon_cmd(port, f"savevm {args.arg}", wait=5.0))
    elif args.action == "snapshots":
        print(qmon_cmd(port, "info snapshots", wait=1.0))
    else:
        print(qmon_cmd(port, args.arg))


if __name__ == "__main__":
    main()
