# WSL 直接部署创龙测试记录

日期：2026-10-29。开发目录 /home/whh/projects/rk3588_media/video_codec，板端 /opt/project1-demo-20261029。通过 WSL 原生 /usr/bin/ssh 和 /usr/bin/scp 直接传输，省去复制 Windows 运行包及手工登录解压步骤。

## 实测结果

| 命令 | 结果 |
|---|---|
| bash project1/demo_multhread_decode_infer_mulmodel/scripts/deploy-tronlong.sh | 编译、上传程序、校验、启动四路通过 |
| NOBUILD=1 bash project1/demo_multhread_decode_infer_mulmodel/scripts/deploy-tronlong.sh bin 2 | 跳过编译、替换运行中的旧程序、启动两路通过 |
| bash project1/demo_multhread_decode_infer_mulmodel/scripts/deploy-tronlong.sh full 4 | 编译、完整包上传、校验、解压、启动四路通过 |

WSL 和板端程序 SHA256 一致：
7695d33de7d4a8346debbd81aa8456e07de1a7bd01a0fb2552df34ac85326059

最后一次完整包 SHA256：
29225ba9116427261b155f6b89e00805c4f23e82348546e5ce9e3ebaec3b08eb

完整包内 20 个文件逐一与板端实文件比较 SHA256，全部一致。覆盖程序、四路视频、三个模型、标签、私有库与三个启停脚本。

VLC 静默解码得到两路和四路 PNG；完整包部署后的四路画面另经浏览器实际确认，具有检测框。VLC scene 抓帧测试日志有格式转换警告，截图只作为可解码证据，未操作用户已最小化的 VLC 主窗口。MediaMTX 确认收到 H.264 发布。

## 脚本修正

开始时工程脚本与 D:\Linux\deploy-tronlong.sh 已一致，板端程序路径没有多余的 project1 层，无需再次复制旧版本。

修正了当前部署脚本：

- 完整包哈希与板端程序哈希分别打印，避免把包哈希误标成 myDemo 哈希。
- 停止脚本报错时立即退出，保留原进程身份检查的拒绝行为。
- 显式使用严格主机密钥校验。
- 非交互 SSH 不读取调用方标准输入，适用于流水线调用。

两份脚本已同步：
- /home/whh/projects/rk3588_media/video_codec/project1/demo_multhread_decode_infer_mulmodel/scripts/deploy-tronlong.sh
- D:\Linux\deploy-tronlong.sh

原始备份：
- 当前 demo 的 build_tronlong/deploy-tronlong.before-test.sh
- D:\Linux\deploy-tronlong.before-test.sh

脚本语法、CRLF 格式下 Git 差异空白检查通过。未修改本轮用户已有 C++ 改动，未提交 Git。

## 使用方式

在 WSL 仓库根目录：

~~~bash
cd /home/whh/projects/rk3588_media/video_codec
bash project1/demo_multhread_decode_infer_mulmodel/scripts/deploy-tronlong.sh
~~~

两路且跳过编译：

~~~bash
NOBUILD=1 bash project1/demo_multhread_decode_infer_mulmodel/scripts/deploy-tronlong.sh bin 2
~~~

库、模型或启停脚本更新时：

~~~bash
bash project1/demo_multhread_decode_infer_mulmodel/scripts/deploy-tronlong.sh full 4
~~~

当前启动脚本日志文件名固定，不随通道数改变；两路也使用 demo-4ch-final.log：

~~~bash
ssh tronlong tail -f /opt/project1-demo-20261029/demo-4ch-final.log
~~~

别名 tronlong 与 root@192.168.1.129 都已验证免密登录，并使用原板主机密钥别名 172.27.64.214。

## 测试结束状态与边界

本次按此前散热暂停意图，测试结束后停止了最后一个四路进程 PID 29022，已核验其退出。停止时 SoC 传感器约 56.4°C，测试期间最高采样约 58.2°C。MediaMTX 保留运行。

没有修改 SSH 授权密钥、系统驱动或项目运行逻辑。没有执行断网、哈希不匹配或停止拒绝等故障注入，也没有进行长期负载或准确率测试。

运行包以 WSL build_tronlong 下的新文件为准。旧 Windows 手动部署归档保留为历史快照，本次未把它当作上传来源。

证据位于本记录同目录的 wsl-deploy-*-test.log、wsl-deploy-full-verification.json、bin2.png、bin4.png、full4-preview.png。
