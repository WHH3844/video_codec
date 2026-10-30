#!/usr/bin/env bash
set -euo pipefail
board=192.168.1.129
if [ "$#" -gt 0 ]; then board="$1"; fi
demo=$(cd -- "$(dirname -- "$0")/.." && pwd)
build="$demo/build_tronlong"
for tool in cmake aarch64-linux-gnu-g++ aarch64-linux-gnu-gcc python3; do
    command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }
done
mkdir -p "$build/board-libs"
# Link against the board's zlib without installing or replacing any system library.
if [ ! -f "$build/board-libs/libz.so.1" ]; then
    command -v scp.exe >/dev/null
    scp.exe -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlias=172.27.64.214 \
        "root@$board:/lib/libz.so.1.2.11" "$(wslpath -w "$build/board-libs/libz.so.1")"
fi
cmake -S "$demo" -B "$build" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
    -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
    "-DCMAKE_EXE_LINKER_FLAGS=-Wl,-rpath-link,$build/board-libs"
cmake --build "$build" --parallel 4
python3 "$demo/scripts/package-tronlong.py"
