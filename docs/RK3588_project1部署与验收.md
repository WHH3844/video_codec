# 创龙 RK3588：project1 部署与验收

2026-10-29，WSL Ubuntu-22.04 开发，创龙 RK3588-Tronlong 运行。

已实际跑通四路 MP4 → FFmpeg 解封装 → MPP 硬解码 → RKNN 三模型 → 检测画框与拼图 → MPP H.264 硬编码 → Windows MediaMTX → VLC / 浏览器。

## 路径和连接

- WSL 源码：/home/whh/projects/rk3588_media/video_codec
- 当前 demo：project1/demo_multhread_decode_infer_mulmodel
- 创龙：root@192.168.1.129
- 板端目录：/opt/project1-demo-20261029
- Windows：192.168.1.28
- 推流：rtmp://192.168.1.28/live/livestream
- VLC：rtmp://127.0.0.1/live/livestream
- [浏览器预览](http://127.0.0.1:8888/live/livestream/)

Windows PowerShell 登录：

~~~powershell
ssh -o HostKeyAlias=172.27.64.214 root@192.168.1.129
~~~

直接 ssh root@192.168.1.129 也已验证。Windows SSH 配置已有该 Host 和 root 用户；VS Code Remote-SSH 可选择此地址，源码开发继续使用现有 WSL 窗口。本次验证 SSH 登录，没有操作 VS Code 连接界面。

## 板端启停和日志

~~~sh
cd /opt/project1-demo-20261029
cat demo.pid
tail -f demo-4ch-final.log
~~~

Ctrl+C 只退出日志查看。后台启停：

~~~sh
./stop-demo.sh
./start-demo.sh 4
~~~

停止脚本核验 PID 对应的可执行文件路径；启动脚本拒绝重复启动。前台调试先停后台，再运行 ./run-demo.sh 4。启动器检查资源、切换工作目录、设置私有库路径。

## Windows 接收与播放

MediaMTX 使用原有 D:\software\MediaMTX 安装，本次版本 1.20.0，未重新安装。

~~~powershell
& 'D:\software\MediaMTX\mediamtx.exe' 'D:\software\MediaMTX\mediamtx.yml'
Get-NetTCPConnection -LocalPort 1935 -State Listen
~~~

本次后台日志在该目录的 project1-20261029.stdout.log 和 project1-20261029.stderr.log。未修改防火墙；板端访问 1935 已通过。

VLC 打开网络串流。默认启动无窗口时，本次显式指定 Qt 可正常显示：

~~~powershell
& 'C:\Program Files\VideoLAN\VLC\vlc.exe' --intf=qt --no-one-instance --network-caching=400 rtmp://127.0.0.1/live/livestream
~~~

## WSL 重新编译和打包

~~~bash
cd /home/whh/projects/rk3588_media/video_codec
bash project1/demo_multhread_decode_infer_mulmodel/scripts/build-tronlong.sh
~~~

使用现有 aarch64-linux-gnu-g++ 11.4.0 和 CMake，输出在 demo 的 build_tronlong：myDemo、project1-runtime.tar.gz、project1-runtime.tar.gz.sha256。myDemo 为 ARM64，不能直接在 x86_64 WSL 运行。

交叉链接需要的板子 zlib 保存在 build_tronlong/board-libs/libz.so.1；首次缺少时，脚本调用 Windows scp.exe 从板子 /lib/libz.so.1.2.11 获取，沿用已有 SSH 密钥与主机校验。

视频、模型与动态库由 D:\MCU\Linux project\AVCODE\4.17\项目\project1 补齐，仅复制运行资源，保留 WSL 已有源码修改。这些资源被 Git 忽略，只有源码不够运行。包内库独立于系统库，RUNPATH 为 $ORIGIN 相对路径，启动器设置 LD_LIBRARY_PATH 供传递依赖使用。

## 更新板端

先将 WSL 新包复制到 Windows 本地路径再上传。本次 Windows 归档不会随源码自动更新。

~~~powershell
scp -o HostKeyAlias=172.27.64.214 'D:\MCU\Linux project\AVCODE\resume_output\project1-tronlong-20261029\project1-runtime.tar.gz' root@192.168.1.129:/tmp/project1-update.tar.gz
~~~

创龙执行：

~~~sh
cd /opt/project1-demo-20261029
./stop-demo.sh
python3 -m tarfile -e /tmp/project1-update.tar.gz /opt/project1-demo-20261029
chmod +x run-demo.sh start-demo.sh stop-demo.sh demo_multhread_decode_infer_mulmodel/build_tronlong/myDemo
./start-demo.sh 4
~~~

板载 BusyBox tar 没有 -z，故用 Python 解压。更新后 VLC 重新打开流，浏览器刷新。接收端 IP 变化时，可在启动前 export PROJECT1_RTMP_URL=rtmp://新地址/live/livestream，无需重新编译。

## 修改、验证与边界

保留原有 MPP 编码参数、推理间隔、模型核心绑定修改，新增：

- 标签加载失败返回错误，修复空指针段错误；初始化改为线程安全。
- 写入检测置信度，无目标帧清零旧计数。
- 校验通道数 1..6，预留 loader vector 容量，避免扩容和推理读取并发。
- 四路拼图使用 1280×720，画布高度随通道数变化，去掉无效黑行引起的压缩。
- 取消拼接输出上误导性的全零统计层，各路检测框保留。
- 编码前 RGA BGR→I420 首次失败后使用 OpenCV 回退，避免逐帧重复失败。
- 增加可迁移库路径及构建、打包、运行、后台启停脚本。

已验证 ARM64 Release 编译、板端依赖解析、严格校验 SSH 登录、板端到 1935 TCP、MediaMTX H.264 发布，以及 VLC 和浏览器实际四路画面。连续运行超过两分钟，发送计数超过 3300；抽样常驻内存约 390 MiB，NPU 三核负载约 85%～88%，并非性能基准。

主机后处理回归覆盖标签缺失不崩溃、置信度写入、空帧清零；均通过。0、7、bad、4x 参数拒绝，后台启停及重复启动拒绝通过。脚本语法与 Git 空白检查（按仓库 CRLF 格式）通过。

创龙为 Buildroot 2021.11、Linux 5.10.160-rt77、aarch64，没有板端 C++ 编译器，不能照搬香橙派 Ubuntu 的 apt 和本地 CMake。NPU 驱动 0.9.0，程序使用私有 RKNN Runtime 1.5.2 和项目 MPP/RGA。MPP 编解码和 RKNN 推理已实测；编码前 BGR→I420 由 OpenCV 回退，解码后转换及拼图缩放仍保留 RGA 调用，不是全程零拷贝或所有操作硬件加速。

未做长期稳定性、断网恢复、准确率、全部 1～6 路组合或 VS Code GUI 连接测试。原有 char* 和 FFmpeg 弃用 API 警告仍存在。停止采用 SIGTERM，未重构线程级优雅退出。

未删除文件、提交 Git、修改 project2、替换驱动或影响原 UAV/Qoder 服务。未设置固定 IP 或开机自启；192.168.1.129 仍为 DHCP 地址，重启后需确认地址并启动接收端与程序。

## 最终连续播放修复
发现拼图线程和推流线程同时补帧，导致实际发送频率超过 24 fps，MediaMTX 丢帧并使 VLC 断开。已让拼图线程使用微秒间隔统一按 24 fps 出帧，推流线程只消费队列，停止超时补帧。最终版本重新编译部署并复测。Buildroot 的 libstdc++ 最高支持 GLIBCXX_3.4.29，因此采用兼容的带超时条件变量等待，避免引入 GLIBCXX_3.4.30。

最终帧率验证：观察 700 帧耗时 29.144 秒，实测发送频率 24.018 fps；最终进程已运行超过两分钟，VLC 保持播放，MediaMTX 没有新增读取过慢记录。板端和 WSL 可执行文件 SHA256 一致：2a3f329ccc4953d80846b1311797ae7a4854edb02af9abd800c514d0a4b972e7。证据保存在同目录 pacing-check.json、demo-4ch-final.log、mediamtx.log 和 four-channel-vlc.png。
