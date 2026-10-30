#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ "$#" -gt 0 ] || set -- 4
if [ "$#" -ne 1 ]; then echo "Usage: $0 <streams: 1..6>" >&2; exit 1; fi
case "$1" in 1|2|3|4|5|6) ;; *) echo "Stream count must be 1..6" >&2; exit 1 ;; esac
for asset in model/person_relu.rknn model/helmet_relu.rknn model/callplay_relu.rknn model/coco_80_labels_list.txt 1.mp4 2.mp4 3.mp4 4.mp4; do
    [ -r "$ROOT/$asset" ] || { echo "Missing asset: $ROOT/$asset" >&2; exit 1; }
done
export LD_LIBRARY_PATH="$ROOT/ffmpeg-lite/lib:$ROOT/opencv4-1/lib:$ROOT/rknn/lib:$ROOT/mpp/lib:$ROOT/rga/lib"
cd "$ROOT/demo_multhread_decode_infer_mulmodel/build_tronlong"
exec ./myDemo "$@"
