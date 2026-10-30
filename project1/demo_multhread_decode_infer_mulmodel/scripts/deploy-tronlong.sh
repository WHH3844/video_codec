#!/usr/bin/env bash
# WSL 一键编译并部署到创龙 RK3588。
# 用法：
#   ./deploy-tronlong.sh            编译，只更新 myDemo，重启 4 路
#   ./deploy-tronlong.sh bin 2      编译，只更新 myDemo，重启 2 路
#   ./deploy-tronlong.sh full 4     编译，上传完整运行包（库、模型、脚本有改动时用）
#   NOBUILD=1 ./deploy-tronlong.sh  跳过编译，直接部署现有产物
set -euo pipefail

MODE="${1:-bin}"
CH="${2:-4}"
BOARD="${BOARD:-root@192.168.1.129}"
REMOTE_DIR="${REMOTE_DIR:-/opt/project1-demo-20261029}"
REPO="${REPO:-/home/whh/projects/rk3588_media/video_codec}"
DEMO_REL="project1/demo_multhread_decode_infer_mulmodel"
OUT="$REPO/$DEMO_REL/build_tronlong"
# 板端解包后没有 project1/ 这一层，路径与 WSL 源码树不同
REMOTE_BIN="$REMOTE_DIR/demo_multhread_decode_infer_mulmodel/build_tronlong/myDemo"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes)

case "$MODE" in bin|full) ;; *) echo "MODE 只能是 bin 或 full"; exit 1;; esac
[[ "$CH" =~ ^[1-6]$ ]] || { echo "通道数必须是 1..6"; exit 1; }

echo "[1/4] 检查板子连接 $BOARD"
ssh -n "${SSH_OPTS[@]}" "$BOARD" true || { echo "WSL 无法免密登录板子，先完成一次性配置"; exit 1; }

if [[ "${NOBUILD:-0}" != 1 ]]; then
    echo "[2/4] 交叉编译"
    (cd "$REPO" && bash "$DEMO_REL/scripts/build-tronlong.sh")
else
    echo "[2/4] 跳过编译"
fi

sha() { sha256sum "$1" | cut -d' ' -f1; }

echo "[3/4] 上传（$MODE）"
if [[ "$MODE" == bin ]]; then
    LOCAL_SHA=$(sha "$OUT/myDemo")
    # 先传到同目录的 .new，停掉旧进程后再 mv，同一文件系统上替换是原子的
    scp "${SSH_OPTS[@]}" -q "$OUT/myDemo" "$BOARD:$REMOTE_BIN.new"
    REMOTE_CMD="
        set -e
        cd '$REMOTE_DIR'
        GOT=\$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],\"rb\").read()).hexdigest())' '$REMOTE_BIN.new')
        [ \"\$GOT\" = '$LOCAL_SHA' ] || { echo 'SHA256 不一致，已中止'; rm -f '$REMOTE_BIN.new'; exit 1; }
        ./stop-demo.sh
        chmod +x '$REMOTE_BIN.new'
        mv -f '$REMOTE_BIN.new' '$REMOTE_BIN'
        ./start-demo.sh $CH"
else
    PKG="$OUT/project1-runtime.tar.gz"
    LOCAL_SHA=$(sha "$PKG")
    scp "${SSH_OPTS[@]}" -q "$PKG" "$BOARD:/tmp/project1-update.tar.gz"
    REMOTE_CMD="
        set -e
        cd '$REMOTE_DIR'
        GOT=\$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],\"rb\").read()).hexdigest())' /tmp/project1-update.tar.gz)
        [ \"\$GOT\" = '$LOCAL_SHA' ] || { echo 'SHA256 不一致，已中止'; exit 1; }
        ./stop-demo.sh
        python3 -m tarfile -e /tmp/project1-update.tar.gz '$REMOTE_DIR'
        chmod +x run-demo.sh start-demo.sh stop-demo.sh '$REMOTE_BIN'
        rm -f /tmp/project1-update.tar.gz
        ./start-demo.sh $CH"
fi

echo "[4/4] 板端停止、替换、启动"
ssh -n "${SSH_OPTS[@]}" "$BOARD" "$REMOTE_CMD"
if [[ "$MODE" == full ]]; then
    echo "已校验运行包 SHA256 = $LOCAL_SHA"
fi
REMOTE_BIN_SHA=$(ssh -n "${SSH_OPTS[@]}" "$BOARD" "python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],\"rb\").read()).hexdigest())' '$REMOTE_BIN'")
echo "完成。板端 myDemo SHA256 = $REMOTE_BIN_SHA"
echo "看日志：ssh $BOARD tail -f $REMOTE_DIR/demo-4ch-final.log"
