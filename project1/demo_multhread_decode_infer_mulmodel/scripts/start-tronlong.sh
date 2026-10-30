#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ "$#" -gt 0 ] || set -- 4
[ "$#" -eq 1 ] || { echo "Usage: $0 <streams: 1..6>" >&2; exit 1; }
case "$1" in 1|2|3|4|5|6) ;; *) echo "Stream count must be 1..6" >&2; exit 1 ;; esac
python3 - "$ROOT" "$1" <<'PYTHON'
from pathlib import Path
import subprocess, sys, os, resource, time
root = Path(sys.argv[1])
pidfile = root / "demo.pid"
if pidfile.exists():
    old = int(pidfile.read_text())
    if Path(f"/proc/{old}").exists():
        raise SystemExit(f"PID {old} still exists; inspect it before starting another demo")
log = open(root / "demo-4ch-final.log", "ab", buffering=0)
def limits():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
p = subprocess.Popen([str(root / "run-demo.sh"), sys.argv[2]],
    stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
    start_new_session=True, preexec_fn=limits)
pidfile.write_text(str(p.pid) + chr(10))
time.sleep(1)
if p.poll() is not None:
    raise SystemExit(f"Demo exited with {p.returncode}; read {root / 'demo-4ch-final.log'}")
print(f"Demo running, PID {p.pid}; log: {root / 'demo-4ch-final.log'}")
PYTHON
