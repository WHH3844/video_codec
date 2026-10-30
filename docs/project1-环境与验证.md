# project1 环境与验证

记录日期：2026-09-06。本轮仅静态读取文件、检查路径与文档格式，没有编译或运行视频程序。

## 已确认事实

- 仓库根为 `video_codec`；开始工作时 `git status --short` 无输出。
- 当前会话执行 `uname -m` 得到 `x86_64`；不据此推断用户目标板环境。
- 当前仓库和检查到的父目录没有 `AGENTS.md`/`AGENTS.override.md`；默认 `~/.codex` 下也未找到这两个文件。原有 `.agents/`、`.codex/` 为空，`docs/` 不存在。
- `project1` 有三个独立 `CMakeLists.txt`，都定义 `myDemo`，不能在仓库根假设存在统一构建入口。
- 本地检查未找到多模型入口所引用的 `project1/model/{person,helmet,callplay}_relu.rknn`、`project1/{1,2,3,4}.mp4`，以及 CMake 引用的 `rknn/lib/librknnrt.so`、`rknn/lib/librknn_api.so`、`mpp/lib/librockchip_mpp.so`、`rga/lib/librga.so`（这些库路径均相对 project1）。
- `.gitignore` 排除了 `.so`、`.rknn`、`.mp4` 等，因此源码中有路径、仓库中有头文件不能证明运行资源齐全。

## 从构建文件确认的配置

| demo | 源码入口 | 依赖选择 |
| --- | --- | --- |
| `demo_multhread_decode_infer` | `demo_multhread_decode_infer.cpp` 和 `lib/*.cpp` | `find_package(OpenCV REQUIRED)`；FFmpeg 按库名链接；RKNN/RGA 还引用 demo 内路径及外部 runtime 路径，需逐项核实 |
| `demo_multhread_decode_infer_mulmodel` | `main.cpp` 和 `lib/*.cpp` | 同级 `ffmpeg-lite`、`opencv4-1`、`rknn`、`mpp`、`rga`；OpenCV 通过本地 `.so` glob 获取 |
| `demo_camera_infer` | `main.cpp` 和 `lib/*.cpp` | 与多模型 demo 相同的依赖目录配置，本轮未验证二者运行差异 |

三份 CMake 都要求 C++17，并设置 `-pthread`。其中 `aarch64` 变量或 `/usr/lib/aarch64-linux-gnu` RPATH 不是交叉编译工具链配置；不能因此认定 x86_64 主机上的默认编译器会生成 ARM 程序。

多模型和 camera 的 RPATH 包含本地库目录及 `/usr/lib/aarch64-linux-gnu`。这只说明配置意图，不证明动态库及传递依赖可加载。

## 原说明与实际文件的差异

根目录 `文件说明.txt` 提及 `./buildDemo.sh` 和 `multhread_decode_infer_mulmodel`；本地未找到该脚本，实际目录为 `demo_multhread_decode_infer_mulmodel`。

存在的 `project1/lib.sh` 仅解压 `ffmpeg7-1/lib.tar.gz` 和 `opencv4-1/lib.tar.gz`，不是下载脚本，而且处理的 FFmpeg 目录不是多模型 CMake 选择的 `ffmpeg-lite`。本轮只读取，未执行。

## 有依据的构建命令（未执行）

下面以多模型 demo 为例。前提是已选定可用的 aarch64 编译环境并补齐兼容依赖；仅供后续构建任务使用，不是本机已验证的步骤。

从仓库根目录执行：

```bash
cmake -S project1/demo_multhread_decode_infer_mulmodel -B project1/demo_multhread_decode_infer_mulmodel/build
cmake --build project1/demo_multhread_decode_infer_mulmodel/build --parallel 4
```

交叉编译还需实际可用的 toolchain/sysroot，当前没有为它编造路径。其他 demo 必须使用各自构建目录。

多模型源码的模型路径为 `../../model/...`，输入为 `../../1.mp4` 等；以该 demo 的 `build/` 为运行工作目录时才对应到 `project1` 下这些资源。入口直接读取 `argv[1]` 作为通道数，当前未做参数存在性和范围检查；URL、images、mutexes 当前均只有 6 个槽位。

本轮不提供直接启动命令：`main` 默认启用 RTMP，初始化时就会连接配置地址，且退出流程未闭合。后续运行任务需先确认输入、通道数、脱敏输出配置和停止方法。

## 待确认项

- 实际 RK3588 板型、系统、内核、MPP/RGA/RKNN 驱动及 runtime 版本。
- 采用目标板原生构建还是主机交叉编译，以及编译器、sysroot、各库 ABI 与传递依赖。
- 模型、视频和所需动态库的真实位置；FFmpeg/OpenCV 版本和启用能力。
- 优先学习哪个 demo；当前详细架构文档以多模型版本为样本，并不替用户锁定学习顺序。
- 板端 DMA/NPU/编解码设备权限、显示环境、允许使用的推流服务及退出行为。

## 验证分层与后续记录

| 层次 | 本轮状态 | 后续任务应记录 |
| --- | --- | --- |
| 静态阅读与路径检查 | 已执行 | 入口/CMake/调用链、路径存在性；不等于完整静态分析 |
| 编译 | 未执行 | 位置、架构、完整命令、配置及构建结果 |
| 主机测试 | 未执行 | 测试范围、依赖、模拟边界 |
| RK3588 目标板运行 | 未执行 | 输入、通道数、实际输出、资源占用、停止与重连结果 |

未来每次验证记录“执行位置—命令（脱敏）—结果—未覆盖内容”。编译通过不能代替硬件运行成功；未复现不能写成没有风险。

## 2026-10-29 创龙板实测更新
已在 WSL 交叉编译并在创龙 RK3588 跑通四路检测推流，详见 [创龙 project1 部署与验收](RK3588_project1部署与验收.md)。上述 2026-09-06 环境缺项保留为历史快照。
