#!/usr/bin/env python3
"""Bundle the four-stream demo and only its private runtime dependencies."""
from pathlib import Path
import hashlib
import tarfile

demo = Path(__file__).resolve().parents[1]
root = demo.parent
build = demo / "build_tronlong"
items = [
    "1.mp4", "2.mp4", "3.mp4", "4.mp4",
    "model/person_relu.rknn", "model/helmet_relu.rknn",
    "model/callplay_relu.rknn", "model/coco_80_labels_list.txt",
    "demo_multhread_decode_infer_mulmodel/build_tronlong/myDemo",
    "ffmpeg-lite/lib/libavcodec.so.60",
    "ffmpeg-lite/lib/libavformat.so.60",
    "ffmpeg-lite/lib/libavutil.so.58",
    "opencv4-1/lib/libopencv_core.so.410",
    "opencv4-1/lib/libopencv_imgproc.so.410",
    "rknn/lib/librknnrt.so", "mpp/lib/librockchip_mpp.so.1",
    "rga/lib/librga.so",
]
for item in items:
    if not (root / item).is_file():
        raise SystemExit(f"Missing deployment asset: {root / item}")
archive = build / "project1-runtime.tar.gz"
with tarfile.open(archive, "w:gz", dereference=True) as package:
    for item in items:
        package.add(root / item, arcname=item, recursive=False)
    package.add(demo / "scripts/run-tronlong.sh", arcname="run-demo.sh", recursive=False)
    package.add(demo / "scripts/start-tronlong.sh", arcname="start-demo.sh", recursive=False)
    package.add(demo / "scripts/stop-tronlong.sh", arcname="stop-demo.sh", recursive=False)
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_suffix(archive.suffix + ".sha256").write_text(f"{digest}  {archive.name}\n")
print(f"Package: {archive}")
print(f"SHA256: {digest}")
