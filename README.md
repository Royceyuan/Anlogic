# 双 FPGA 博物馆双屏展陈终端：主板最终工程介绍

本目录 `Anlogic` 是主板工程，`../Anlogic2` 是副板工程。目标器件为安路HX4S20板载 `EG4S20BG256`，使用TD 6.2.1。本文件是主板唯一工程说明；历史阶段文档、交接、试验报告和中间产物已移入工程外rubbish。

## 工程入口与当前位流

| 项目 | 路径 |
|---|---|
| 唯一TD入口 | `dual_fpga_museum_terminal_main_board.al` |
| 顶层模块 | `dual_fpga_museum_terminal_main_board`，定义于 `src/top/museum_main_board_top.v` |
| 系统集成 | `src/top/museum_main_board_top.v` |
| 管脚约束 | `constraints/museum_main_board_pins.adc` |
| 时序约束 | `constraints/museum_main_board_timing.sdc` |
| 唯一保留bit | `release/dual_fpga_museum_terminal_main_board_flash_startup_repair.bit` |
| bit校验值 | `release/dual_fpga_museum_terminal_main_board_flash_startup_repair.sha256` |
| 成功种子及最终报告 | `seed/`，布局种子1 |

bit SHA-256：`4409952619964B9FB2D138E2D3FB9006DB005E53278404412D8A7F92AB876BE5`。

这是用户反馈整体可用的Flash启动修复版。极低概率80C6仍作为待观察项，不宣称完全消除。整理没有修改功能RTL，发布bit不变，不需要重新烧录或写卡。保留了用户原有未提交源码修改；本轮独立重建使用待提交源码副本，不包含这些修改，不能将它们宣称为该bit的新综合结果。

## 已实现功能

主屏HDMI展示五栏文物总览，按拨码预载图片、音频、字幕与名称；讲解中可以后台准备下一件素材。图片按照全貌、细节1、细节2、细节3、最终全貌展示，采用既定平滑转场，音频与TF字幕按时间轴推进。支持按比例自适应、1×/2×、暂停、视口平移、四档预设及亮度/对比度/饱和度/色温调节。

左上角OSD显示实际文物、图像阶段、源分辨率、自动/手动、倍率和实际画面参数；名称来自TF卡。字幕带描边，音频波形随PCM变化，总览及暂停不保留静止波形。静音手动浏览保留图片缓存；切回自动只恢复音频/字幕会话。KEY4提供应用级恢复，SW4控制应急抢占及退出。

主板通过以太网向副板上报实际状态，接收远程画面控制；副板展示本地文物信息、应急路线和操作说明。以太网不传图片、音频或字幕文件。

## 按键与拨码

| 主板按键 | 总览 | 自动讲解 | 静音手动看图 |
|---|---|---|---|
| KEY1 | 循环高亮文物0～4 | 循环1×/2× | 循环1×/2× |
| KEY2 | 确认进入当前模式 | 暂停/继续 | 退出总览，不重载图片 |
| KEY3 | 显示/隐藏OSD | 显示/隐藏波形 | 循环全貌、细节1～3 |
| KEY4 | 应用软复位并重载 | 应用软复位并重载 | 应用软复位并重载 |

SW1～3组成预载编号0～4；无效编号不允许误入讲解。KEY1高亮不触发读卡，KEY2要求高亮与就绪素材一致。SW4=1应急，SW4=0退出应急。SW4是拨码开关，不是长按按键。

副板SW3=0自动讲解、1静音手动；两种模式下四个副板按键均保留画面控制。副板SW4=0正常展示、1双栏使用说明，不断网、不复位。副板SW2:SW1分组如下：

| SW2:SW1 | KEY1 | KEY2 | KEY3 | KEY4 |
|---|---|---|---|---|
| 00 | 标准 | 明亮 | 高对比 | 柔和 |
| 01 | 亮度减 | 亮度加 | 对比度减 | 对比度加 |
| 10 | 饱和度减 | 饱和度加 | 色温偏冷 | 色温偏暖 |
| 11 | 左 | 右 | 上 | 下 |

现副板平移固定20源像素；主板支持20/40测试步长，不把40宣称为当前副板拨码功能。平移在播放/暂停、1×/2×均允许；1×露底，2×内部观察。转场、应急和恢复期间拒绝控制，但不能永久锁住后续请求。

## TF素材及电脑软件

FAT32卡根目录需要31个规范文件：`IMAGE0.BMP`～`IMAGE4.BMP`、每件 `ARTnD1.BMP`～`ARTnD3.BMP`、`AUDIO0.WAV`～`AUDIO4.WAV`、`SUB0.BIN`～`SUB4.BIN`及 `OSDNAME.BIN`。图片为规范24位未压缩BMP，软件处理上限1920×1080，保持宽高比；板内使用RGB565和SDRAM缓存。音频为PCM16、48kHz、双声道。不要把SRT、模型或软件直接放进TF根目录。

打包软件已由用户独立移动，不再属于本工程目录，也不是FPGA构建依赖。在实际软件目录双击 `MuseumTFPackager.exe`，无需Python、不弹终端。选择五个文物文件夹的根目录，每件放全貌、细节1～3、WAV和SRT；必要时勾选本地字幕校准，在“设置切图句”指定四个阶段开始的字幕句，再生成素材包。试听后将输出 `TF_CARD` 内31文件写卡；名称位图自动生成。软件内置“使用说明”。

完整运行目录中的 `AlignmentWorker`、`models`、`ffmpeg`、DLL与许可证不可拆散，不能只留EXE。校准本机运行、保留原字幕文字，不保证每句绝对准确；检查输出提示并试听。软件源码、开发环境和重复ZIP已归档，修改软件时按清单恢复原路径。

当前五件新女声源素材在 `../素材`，已用实际软件校准并写卡回读。图片顺序不变；第5、9、13、17句分别作为细节1～3及最终全貌切点。软件检查不替代真实音画/字幕上板验收。

## 双板网络接口

直连千兆以太网，固定IPv4/24、UDP/ARP；主板 `192.168.10.1:5000`、MAC `02:48:58:34:20:01`，副板 `192.168.10.2:5000`、MAC `02:48:58:34:20:02`。不支持IP分片、options或网络传媒体。固定UDP及MBP1位于 `src/ethernet`，TEMAC/RGMII/FIFO来自官方示例；不要删跨时钟FIFO或更改IP配置文件旁的综合网表。

MBP1版本1，20字节头、业务payload及2字节CRC，总长 `22+N`，多字节整数大端。魔数 `4D42`；CRC-16/CCITT-FALSE，poly=0x1021、init=0xFFFF、xorout=0、不反射，覆盖头与业务数据。消息包括HELLO(01)、心跳(02)、状态查询(03)、ACK(04)、播放状态(12)、预设(13)、四参数(14)、视口(15)、实际画面状态(16)、浏览模式(17)、浏览图片(18)、诊断(31)，十六进制编号。

副板主动握手、每500ms心跳；控制按实际状态发送绝对值，并等待匹配ACK及实际状态。忙/无效请求结束本次事务，不盲目重放旧增量。重连后重新取得新状态并同步SW3；同boot_id断线不能永久丢失已知能力。应急断线保持逃生图，重连新状态确认解除后恢复；当前应急页未显示失联提示，此项不是已完成的显示功能。完整字段定义以当前 `mbp1_codec.v`、两板endpoint和keys源码为准，历史详细协议已归档。

## 构建、时序与验证

手动全流程：

1. 用 `D:\TD_6.2.1\bin` 中的TD图形界面打开根目录唯一 `.al`，确认器件为 `EG4S20BG256`、顶层为 `dual_fpga_museum_terminal_main_board`。
2. 在工程文件树审核 `src/top/museum_main_board_top.v`，沿模块实例检查 `src/memory`、`src/video`、`src/audio`、`src/ethernet` 等源码；IP及约束同样必须保留。
3. 在PowerShell中按下列顺序手动启动完整综合/布局布线，再生成bit。正式构建使用脚本中的成功种子和修hold步骤；不要以GUI默认物理设计策略代替后宣称结果等价。

```powershell
Set-Location -LiteralPath D:\VSCode\CodeFiles\Git_TD\Anlogic
& D:\TD_6.2.1\bin\td_commands_prompt.exe scripts/build_flash_startup_repair.tcl
# 确认上一步成功，检查 _build_flash_startup_repair/museum_main_board_final.ts
# setup/hold WNS非负，TNS均为0，再执行：
& D:\TD_6.2.1\bin\td_commands_prompt.exe scripts/bitgen_flash_startup_repair.tcl
Get-FileHash -LiteralPath ./release/dual_fpga_museum_terminal_main_board_flash_startup_repair.bit -Algorithm SHA256
```

4. 检查TD输出无ERROR，完整构建的DRC通过，bitgen明确输出 `Generate bits file`；确认新bit的文件时间和SHA256后再烧录。只看进程退出码或目录里有旧bit不能证明生成成功。自行修改后产生的新bit不自动继承当前发布bit的上板验收。

启动修复构建包装器复用 `build_museum_main_board.tcl` 及bitgen，四个Tcl都必须保留。所有现有build目录和数据库均已归档；下次生成bit必须先执行第一条完整构建，再执行bitgen，脚本会重新建立构建目录。成功布局种子1及其参数原样保留在构建脚本，并在 `seed/seed_config.json` 汇总；这里只保存原始最终报告，不是可直接bitgen的数据库。种子不保证修改后的源码仍然闭合时序。

保留bit对应报告：LUT16960/19600（86.53%）、FF11427/19600（58.30%）、Slice9540/9800（97.35%）、BRAM9K43/64、BRAM32K10/16、DSP13/29、PLL4/4。setup +0.107ns、hold +0.023ns，TNS=0。原始依据在 `seed/` 的final.area、final.qor、final.ts、final.timing及bitgen.log；余量较紧，不放宽时序来宣称通过。

`sim` 保留产品回归源码和 `.do`。ModelSim从 `sim` 目录执行，例如：

```powershell
& D:\Modelsim\win64\vsim.exe -c -do run_application_recovery.do -l recovery.log
& D:\Modelsim\win64\vsim.exe -c -do run_remote_controls.do -l controls.log
```

检查退出码、PASS及无FAIL/Fatal/Error；仅退出码0不够。采用英文日志名，避免本机ModelSim中文日志路径启动异常。仿真生成的work目录、modelsim.ini、日志不属于产品源码。2026-10-03整理后独立源码副本通过6组回归、13条PASS（应用恢复、远程控制、本地手动浏览、名称、字幕叠加、应急恢复），无仿真错误；完整综合、布局布线、STA、DRC及bitgen通过，setup +0.107ns、hold +0.023ns、TNS均为0。测试bit留在工程外验证目录，不替换已上板发布bit。

## 目录与回溯

逐目录审核结果：

| 目录/文件 | 保留理由及整理结果 |
|---|---|
| 根目录 `.al`、README、LICENSE、Git配置 | 工程入口、唯一介绍、版权及版本控制；保留 |
| `src` | 49个当前工程源文件均被工程入口引用，保留，不改RTL |
| `constraints` | 当前管脚与时序约束，保留 |
| `vendor` | 保留工程直接引用、PLL的隐式生成HDL、TEMAC网表、SDRAM include；移出36个未引用例程/重复模块/旧备份 |
| `scripts` | 四个正式Tcl构成完整综合→布局布线→DRC→bitgen链，全部保留 |
| `sim` | 保留当前功能回归；8个依赖旧提交的历史对比脚本及7个专用测试台归档 |
| `seed` | 已闭合种子1、实际参数和原始最终报告，完整保留 |
| `release` | 唯一已验收bit及校验值；`media/OSDNAME.BIN`作为名称媒体模板保留 |
| 原 `assets` | 单张历史图片源图不参与构建/仿真，已归档；实际TF素材由卡或独立打包软件提供 |
| `tools` | 用户独立整理的软件不参与FPGA编译、不上传；旧Python启动BAT已失去调用目标，不属于当前流程 |

工程里没有要求保留任何历史build数据库；重新编译自动生成build目录。回归测试源码不是中间产物，保留便于审核后验证修改。

所有移出内容位于 `D:\VSCode\CodeFiles\Git_TD\rubbish\双板软件与旧位流整理_20261003`；软件、仿真、构建和最终文档整理分别有CSV清单，记录原/目标路径、长度和SHA256。旧文档在 `finalization/Anlogic/docs`，旧工程介绍也留有备份。需要恢复时移动回清单中的原路径，勿覆盖当前文件。归档不随普通Git拉取提供；当前工程自身具备构建所需全部硬件依赖。

本轮进一步审核移出清单及独立重建证据位于 `D:\VSCode\CodeFiles\Git_TD\rubbish\project_audit_20261003`。主板工作区原有未提交源码改动不在本次整理提交中；核验重建以整理后的Git提交内容为准。
