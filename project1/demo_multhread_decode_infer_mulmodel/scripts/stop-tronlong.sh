#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python3 - "$ROOT" <<'PYTHON'
from pathlib import Path
import os, signal, sys, time
root = Path(sys.argv[1])
pidfile = root / "demo.pid"
if not pidfile.exists():
    raise SystemExit("No demo PID file")
pid = int(pidfile.read_text())
proc = Path(f"/proc/{pid}")
if not proc.exists():
    print("Demo already stopped")
    raise SystemExit(0)
expected = root / "demo_multhread_decode_infer_mulmodel/build_tronlong/myDemo"
if (proc / "exe").resolve() != expected:
    raise SystemExit(f"PID {pid} does not belong to this demo; refusing to stop it")
os.kill(pid, signal.SIGTERM)
for _ in range(50):
    if not proc.exists():
        print(f"Stopped demo PID {pid}")
        break
    time.sleep(0.1)
else:
    raise SystemExit(f"PID {pid} has not exited; inspect it manually")
PYTHON
