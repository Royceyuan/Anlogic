# 双 FPGA 博物馆双屏展陈终端：副板最终工程介绍

本目录 `Anlogic2` 是副板，`../Anlogic` 是主板。分支 `secondary-main5e`，目标器件 `EG4S20BG256`，使用TD 6.2.168116。本文件是副板唯一工程说明；阶段交接、历史文档与中间产物已归档，第三方许可证仍保留。

## 工程入口与位流

| 项目 | 路径 |
|---|---|
| 唯一TD入口 | `hx4s20_secondary_main5e.al` |
| 顶层 | `src/secondary/top_secondary_main5e.v`，模块 `top_secondary_main5e` |
| 管脚/时序约束 | `constraints/top_secondary_main5e.adc`、`constraints/top_secondary_main5e.sdc` |
| 唯一最新可用bit | `release/hx4s20_secondary_help_v2.bit` |
| 发布记录 | `release/manifest_secondary_help_v2.json` |
| 成功布局种子与原始最终报告 | `seed/`，种子6 |

bit SHA256：`B36B3D6E5E0A4FD77A023F5DB5BF5706127253A54FC7ABC41C37B90484353CDA`。用户已确认双栏说明页正常；整理不改RTL、不重新生成bit，不需要重新烧录或更换TF卡。

## 展示与控制

副屏HDMI输出1280×720。总览轮播文物展示页；接收主板实际状态后切换对应简介，应急优先显示逃生图与路线提示。主板讲解音画字幕在主板处理，副板只显示本地缓存素材和状态，以太网不传媒体文件。

副板SW3=0自动讲解、1静音手动浏览，由以太网同步至主板；两种模式均保留四键画面控制。切回自动采用音频/字幕轻量恢复，保留图片缓存。断线重连后重新获取主板状态并协调SW3，主板自身SW3仍属于预载编号，不可混淆。

副板SW4=0正常展示、1双栏操作说明。说明页左栏显示主板按键与拨码，右栏显示副板四组按键和拨码，底部显示通信与主板实际状态；当前控制组突出显示，字重统一。SW4只切本地页面，不断网、不复位、不重载；说明页中四键仍控制主板。应急优先于说明页，解除后跟随SW4恢复。

副板SW2:SW1控制分组：

| SW2:SW1 | KEY1 | KEY2 | KEY3 | KEY4 |
|---|---|---|---|---|
| 00 | 标准 | 明亮 | 高对比 | 柔和 |
| 01 | 亮度减 | 亮度加 | 对比度减 | 对比度加 |
| 10 | 饱和度减 | 饱和度加 | 色温偏冷 | 色温偏暖 |
| 11 | 左 | 右 | 上 | 下 |

参数按既定档位变化，主板按百分比显示；平移每次20源像素，允许1×/2×和播放/暂停。1×平移露底，2×移动观察窗口。转场、应急、启动或恢复中暂不控制，后续正常状态可继续发送。副板无额外大步拨码功能。

主板KEY1总览循环高亮、展示时1×/2×；KEY2总览进入、自动暂停/继续、手动退出且不重载；KEY3总览切OSD、自动切波形、手动循环全貌和细节1～3；KEY4完整应用恢复。主板SW1～3选择预载0～4，SW4控制应急。主板四键功能不是副板四组按键功能。

## 双板通信

固定UDP/ARP千兆直连：主板 `192.168.10.1:5000`、MAC `02:48:58:34:20:01`；副板 `192.168.10.2:5000`、MAC `02:48:58:34:20:02`，掩码255.255.255.0。TEMAC/RGMII/FIFO使用官方模块，精简UDP位于 `src/ethernet/mbp1_fixed_udp.v`。必须保留IP配置及旁边的综合网表、跨时钟FIFO和约束。

MBP1版本1：魔数4D42，20字节头、N字节业务数据、2字节CRC，总长22+N，多字节整数大端。CRC-16/CCITT-FALSE覆盖头与业务数据，poly=0x1021、init=0xFFFF、xorout=0、不反射。消息编号（十六进制）：HELLO01、心跳02、查询03、ACK04、播放状态12、预设13、四参数14、视口15、画面状态16、浏览模式17、浏览图片18、诊断31。

副板主动握手并每500ms心跳，按主板实际状态产生绝对值控制，等匹配ACK再更新；不能按按键次数猜主板是否暂停或进入讲解。忙请求结束本次事务；重连重新获取状态并同步SW3，同boot_id也须恢复。实际字段定义与发送条件以 `mbp1_codec.v`、`mbp1_secondary_endpoint.v`、`secondary_main5e_keys.v` 和 `secondary_main5e_status_adapter.v` 为准。应急断线保持逃生图，当前应急画面未增加失联提示。

## TF素材与必要工具

FAT32根目录12文件：`IMAGE0.BMP`～`IMAGE9.BMP`（展示及简介）、`IMAGEA.BMP`（应急），均1280×720、24位未压缩BMP；`IMAGEB.BMP`为160×90、24位说明背景。所有规范文件在 `assets` 内，源图也保留以支持素材再制作。

现有11图写卡命令，在工程根目录执行（F按实际副板卡修改；工具拒绝C/D/E以防误写）：

```powershell
./tools/copy_secondary_native720_to_sd.ps1 -DriveLetter F
Copy-Item -LiteralPath ./assets/secondary_help/IMAGEB.BMP -Destination F:\IMAGEB.BMP
Get-FileHash -LiteralPath ./assets/secondary_help/IMAGEB.BMP, F:\IMAGEB.BMP
```

写卡工具逐文件核验11图SHA；IMAGEB须核对两行SHA相等，再安全弹卡。未授权时不要重写卡。`tools/prepare_secondary_help.py` 是说明字库生成源码，需要Python和Pillow，保留以便修改说明页；正常运行、现有源码构建或烧录不需要Python。重生成字库会修改 `secondary_help_font.vh`，必须重新综合并验收。其余历史媒体/电脑诊断脚本已归档。

## 重建与回归

在工程根目录执行：

```powershell
./scripts/build.ps1
```

默认TD路径 `D:/TD_6.2.1/bin/td_commands_prompt.exe`，可通过 `-TD` 指定其他位置。脚本完整综合、布局布线、修hold，检查时序/警告/源文件新鲜度后生成唯一当前bit。所有build目录已移出，下次脚本自动生成 `_build_secondary_help_v2_20261002`；没有PR数据库时不能单独运行bitgen。成功种子6仍在 `build_secondary_main5e_pr.tcl`，并汇总于 `seed/seed_config.json`，改源码后必须重新验证，不保证同种子必定闭合。

保留bit对应最终资源：LUT11867/19600（60.55%）、FF7127/19600（36.36%）、Slice6727/9800（68.64%）、BRAM9K32/64、BRAM32K13/16、DSP9/29、PLL4/4。setup +0.297ns、hold +0.021ns、TNS=0，原始时序、面积、DRC/bitgen依据保存在 `seed`。

ModelSim从 `sim` 目录执行，例如：

```powershell
& D:\Modelsim\win64\vsim.exe -c -do run_secondary_help.do -l help.log
& D:\Modelsim\win64\vsim.exe -c -do run_mbp1_reconnect.do -l reconnect.log
```

检查退出码、PASS及无FAIL/Fatal/Error。用英文日志名，避免本机中文日志路径启动异常。清理后本轮说明/背景3项及重连1项PASS；主板恢复回归也PASS。仿真源码保留，work库和日志可重新生成。

## 目录与回溯

保留唯一工程入口、README、`src`、`vendor`、`constraints`、正式 `scripts`、回归 `sim`、素材 `assets`、必要 `tools`、当前 `release` 和成功种子 `seed`。`.git`、LICENSE及第三方版权不是清理目标。

移出内容位于 `D:\VSCode\CodeFiles\Git_TD\rubbish\双板软件与旧位流整理_20261003`，CSV清单记录原路径、目标路径、长度和SHA256。可按清单移动回原路径，勿覆盖新文件；归档不随普通Git拉取提供。当前工程具备从源码完整重建的依赖。
