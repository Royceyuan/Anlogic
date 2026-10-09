# 双 FPGA 博物馆双屏展陈终端：副板最终工程介绍

本目录 `Anlogic2` 是副板，`../Anlogic` 是主板。分支 `secondary-main5e`，目标器件 `EG4S20BG256`，使用TD 6.2.168116。本文件是副板唯一工程说明；阶段交接、历史文档与中间产物已归档，第三方许可证仍保留。

## 工程入口与位流

| 项目 | 路径 |
|---|---|
| 唯一TD入口 | `hx4s20_secondary_main5e.al` |
| 顶层 | `src/secondary/top_secondary_main5e.v`，模块 `top_secondary_main5e` |
| 管脚/时序约束 | `constraints/top_secondary_main5e.adc`、`constraints/top_secondary_main5e.sdc` |
| 唯一最新可用bit | `release/hx4s20_secondary_help_fixed720.bit` |
| 发布记录 | `release/manifest_secondary_help_fixed720.json` |
| 成功布局种子与原始最终报告 | `seed/`，种子6 |

bit SHA256：`91A70946F2FA9966D1BAF6466B921C6D6E4C3BE090D8D9C4A62FD0235D5BC25A`。用户已确认双栏说明页正常；清理不改功能RTL；另合并保留远程 `72a8937` 已验收的固定BMP读取和讲解页淡入淡出更新。发布bit来自该远程版本，不用本轮验证输出替换，不更换TF卡。

## 展示与控制

副屏HDMI输出1280×720。总览轮播文物展示页；接收主板实际状态后切换对应简介，应急优先显示逃生图与路线提示。主板讲解音画字幕在主板处理，副板只显示本地缓存素材和状态，以太网不传媒体文件。讲解页约半秒淡出/淡入，应急直接切页并可抢占转场。媒体严格按固定原生尺寸读取，普通图1280×720、说明背景160×90；副板正式入口不启用通用自适应缩放器。

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

FAT32根目录12文件：`IMAGE0.BMP`～`IMAGE9.BMP`（展示及简介）、`IMAGEA.BMP`（应急），均1280×720、24位未压缩BMP；`IMAGEB.BMP`为160×90、24位说明背景。所有规范文件在 `assets` 内；未参与当前工具/构建的11张历史源PNG已归档。说明背景源PNG仍保留，供字库/说明页生成工具使用。

现有11图写卡命令，在工程根目录执行（F按实际副板卡修改；工具拒绝C/D/E以防误写）：

```powershell
./tools/copy_secondary_native720_to_sd.ps1 -DriveLetter F
Copy-Item -LiteralPath ./assets/secondary_help/IMAGEB.BMP -Destination F:\IMAGEB.BMP
Get-FileHash -LiteralPath ./assets/secondary_help/IMAGEB.BMP, F:\IMAGEB.BMP
```

写卡工具逐文件核验11图SHA；IMAGEB须核对两行SHA相等，再安全弹卡。未授权时不要重写卡。`tools/prepare_secondary_help.py` 是说明字库生成源码，需要Python和Pillow，保留以便修改说明页；正常运行、现有源码构建或烧录不需要Python。重生成字库会修改 `secondary_help_font.vh`，必须重新综合并验收。其余历史媒体/电脑诊断脚本已归档。

## 重建与回归

手动全流程：

1. 在TD图形界面打开根目录唯一 `hx4s20_secondary_main5e.al`，确认器件 `EG4S20BG256`、顶层 `top_secondary_main5e`。
2. 从 `src/secondary/top_secondary_main5e.v` 沿实例审核显示、协议、按键及存储逻辑；`secondary_help_font.vh`是实际include，TEMAC的 `_gate.v` 是实际IP依赖，不能因未直接列在文件树而删除。
3. 在PowerShell手动执行完整构建命令：

```powershell
Set-Location -LiteralPath D:\VSCode\CodeFiles\Git_TD\Anlogic2
./scripts/build.ps1
```

4. 该命令使用成功种子6，依次完成综合、布局布线、hold修复和带检查的bitgen。审核 `_build_secondary_help_fixed720_seed6/console.log`、最终 `.ts/.status` 及 `bitgen.log`，要求setup/hold WNS非负、TNS=0、DRC通过且明确生成新bit，再核对SHA256并烧录。GUI默认物理设计策略不能当作已验证脚本的替代；新改源码生成的bit需重新上板验收。

默认TD路径 `D:/TD_6.2.1/bin/td_commands_prompt.exe`，可通过 `-TD` 指定其他位置。脚本完整综合、布局布线、修hold，检查时序/警告/源文件新鲜度后生成唯一当前bit。所有build目录已移出，下次脚本自动生成 `_build_secondary_help_fixed720_seed6`；没有PR数据库时不能单独运行bitgen。成功种子6仍在 `build_secondary_main5e_pr.tcl`，并汇总于 `seed/seed_config.json`，改源码后必须重新验证，不保证同种子必定闭合。

保留bit对应最终资源：LUT9905/19600（50.54%）、FF6468/19600（33.00%）、Slice5775/9800（58.93%）、BRAM9K20/64、BRAM32K13/16、DSP5/29、PLL4/4。setup +0.309ns、hold +0.022ns、TNS=0，原始时序、面积、DRC/bitgen依据保存在 `seed`。

ModelSim从 `sim` 目录执行，例如：

```powershell
& D:\Modelsim\win64\vsim.exe -c -do run_secondary_help.do -l help.log
& D:\Modelsim\win64\vsim.exe -c -do run_mbp1_reconnect.do -l reconnect.log
```

检查退出码、PASS及无FAIL/Fatal/Error。用英文日志名，避免本机中文日志路径启动异常。2026-10-03以远程最新版本为基线整理后，独立源码副本通过9组回归、28条PASS，无仿真错误：说明页、官方RAM原语、双板重连、按键、本地控制、固定720p图片流、固定尺寸说明背景、顶层背景加载及讲解切页。完整综合、布局布线、STA、DRC和bitgen通过，setup +0.309ns、hold +0.022ns、TNS均为0。测试bit留在工程外验证目录，不替换远程已验收bit，不要求因本次整理重新上板。仿真源码保留，work库和日志可重新生成。

## 目录与回溯

逐目录审核结果：

| 目录/文件 | 保留理由及整理结果 |
|---|---|
| 根目录 `.al`、README、LICENSE、Git配置 | 唯一入口、最终介绍、版权及版本控制；保留 |
| `src` | 当前工程源文件和实际include字库；没有可安全移出的源码 |
| `vendor` | 当前工程直接引用和TEMAC隐式网表；全部保留 |
| `constraints` | 当前管脚、时序约束；保留 |
| `scripts` | 完整构建PS1及综合/bitgen两个Tcl；全部保留 |
| `sim` | 当前功能、原语和双板重连回归；全部保留，不依赖旧历史提交；跨板重连需同级 `Anlogic` |
| `assets` | 12张规范TF位图和说明背景源图保留；11张已不用的源PNG和可再生说明媒体manifest归档 |
| `tools` | 安全写卡工具、说明页字体生成源码；均有实际用途，保留 |
| `seed` | 当前fixed720种子6、原始时序/资源/DRC依据；旧v2成功配置另留 `seed_config_help_v2.json`，旧bit和重复报告归档 |
| `release` | 唯一最新已验收bit及发布校验记录；保留 |

历史build数据库不参与源码重建，当前目录不要求预先存在build缓存。回归源码不是中间编译产物。

移出内容位于 `D:\VSCode\CodeFiles\Git_TD\rubbish\双板软件与旧位流整理_20261003`，CSV清单记录原路径、目标路径、长度和SHA256。可按清单移动回原路径，勿覆盖新文件；归档不随普通Git拉取提供。当前工程具备从源码完整重建的依赖。

本轮进一步审核清单及独立重建证据位于 `D:\VSCode\CodeFiles\Git_TD\rubbish\project_audit_20261003`。说明背景/字库生成工具将来可能再次生成预览图与manifest，它们不属于编译必需文件。

副板整理基线功能源码来自远程 `72a8937`；本轮副板只本地提交，不推送远程。

## HDMI直通拓展：共享PLL基线已上板通过

2026-10-08用户确认共享PLL候选上板通过。原正式入口默认关闭共享PLL，原发布bit不变；`hx4s20_secondary_shared_clock.al` 是独立时钟验证入口，不是HDMI直通版本。

```powershell
./scripts/build.ps1 -Variant shared-clock
```

输出 `release/hx4s20_secondary_shared_clock.bit`，SHA256为 `87AD8E62FA57719CBFAD35B9F1A648722CEE1BC4F86AFC7768E7AA90D9C64D82`。该bit保留原副屏功能，HDMIA仍输出，尚未接收HDMIB。

共享PLL保留存储50MHz及相对8ns偏移、以太网125MHz及相对2ns偏移；采用存储时钟反馈补偿和全局缓冲。实际占用LUT10000（51.02%）、FF6466、Slice5805（59.23%）、BRAM9K20、BRAM32K13、DSP5、PLL3；setup +0.245ns、hold +0.027ns，TNS=0。官方PLL模型对照测试和9组原功能回归通过。

闭合报告保留在 `seed/shared_clock`。本次BOARD PASS只适用于共享PLL版本，不能当作HDMI接收通过。后续按 [直通实施计划](../记录文档/副板_HDMI音视频直通实施计划_20261008.md) 推进独立720p音视频直通，再整合自动切源。

## HDMI直通：独立诊断版本，待上板验证

2026-10-09新增 `hx4s20_secondary_hdmi_relay_diag.al`，顶层为 `top_secondary_hdmi_relay_diag`。这是单独验证 **电脑 HDMI → 副板 HDMIB → HDMIA → 显示器** 的入口，不是原副板工程的替代版本。原正式和共享PLL的两个已通过bit均保留；主板工程未改，副板没有push。

```powershell
Set-Location -LiteralPath D:\VSCode\CodeFiles\Git_TD\Anlogic2
./scripts/build.ps1 -Variant relay-diag
```

输出 `release/hx4s20_secondary_hdmi_relay_diag.bit`。当前SHA256：

```text
BF52A11895B45629FC85420FD4E364FE1D518A97842EF345399E93547313EF11
```

### 实现与验证边界

- 使用官方IDDRx2/ODDRx2，四条通道（包括TMDS时钟）共用采样/发送时钟及延迟，原样重发串行位流，音频数据岛不剥离。无需SDRAM帧缓存、DSP或BRAM。
- 内置只读E-DDC：256字节EDID，仅声明720p60/59.94、RGB8及双声道48kHz/16-bit LPCM，不支持HDCP、HDR、深色或1080p。声明能力不是实际音视频通过的证据。
- 约3ms时钟测量就绪后锁定接收PLL；三通道符号对齐一致，连续8帧总时序正确才使能输出。不合格时每约200ms步进采样相位并重新训练；下游断开或源时钟停止会关闭输出。
- 监测器只是使能判据，不是RGB解码、逐像素合法性检查或误码率测量。真实线缆、输入电平、抖动和像素/声音正确性仍需板测。
- 本独立bit没有TF、SDRAM、本地图片、说明页和以太网功能；没有信号时黑屏/显示器无信号属预期。正式版本后续才整合自动切源和回退。

时序边界必须明确：`secondary_hdmi_relay_diag.sdc`只对三根外部TMDS数据输入到首级IOL采样器设置例外，因为运行时动态调整采样相位，没有固定外部建立/保持关系。**串行输入眼图余量未由STA证明**，不能称为全链路时序已证明。DDR并行输出、接收监测、发送器及复位的内部路径仍接受STA；50MHz与外部接收域的真实CDC使用同步器。该边界和板测依据应随最终作品保留。

独立诊断实际资源：LUT1064/19600（5.43%）、FF501/19600（2.56%）、Slice609/9800（6.21%）、PLL1/4、GCLK4/16、BRAM9K/BRAM32K/DSP均0。**这些不是完整副板集成后的资源用量。** 内部setup +0.075ns、hold +0.030ns、TNS均0，无多驱动及异常时序路径。50MHz板载时钟存在工具PHY-5079局部布线提示，路径已被STA覆盖，没有新增忽略内部路径的例外。种子6和原始报告/日志保存在 `seed/hdmi_relay_diag`。

五组HDMI仿真共13条PASS：EDID校验、重复起始/连续读取/分段边界/NACK；官方DDR模型四通道位级一致；官方PLL联合模型60/59.94、相移、失源和错误频率拒绝；含音频数据岛的控制同步、错误总时序/不同通道位偏移拒绝；顶层使能、强制重训及输入/显示器重连。顶层测试缩短计数窗口及帧尺寸，生产参数不变。TD自带PLL仿真模型的load_reg端口宽度与综合原语不同，有一条已知宽度警告；连接恒为0，不启用动态参数加载。

从 `sim` 运行 `run_hdmi_edid_720p.do`、`run_hdmi_relay_phy.do`、`run_hdmi_relay_clock.do`、`run_hdmi_tmds_monitor.do`、`run_hdmi_relay_diag.do`，均需退出码0、PASS且无Fatal/Error。

### 上板操作及预期现象

1. 优先通过JTAG临时加载上述诊断bit，不先覆盖已经稳定的Flash版本；主板不用改。
2. 显示器接副板 **HDMIA**，电脑输出接副板 **HDMIB**，勿接反。电脑选复制或扩展，活动信号设1280×720、60Hz或59.94Hz，RGB8；禁用HDR和受保护视频。首次可先测试桌面/自制彩条。
3. 显示器插入后副板B口HPD有效，电脑应识别 `FPGA-720P`。稳定输入经8帧判定后，显示器应显示电脑画面。相位重训可能多等几个约200ms周期。实际HDMI输入尚未上板验收，不能保证本机自动选择的分辨率。
4. 测音频时电脑播放设备选该HDMI设备，设置双声道、48kHz、16-bit LPCM；显示器须能接收HDMI音频并有扬声器或音频输出。声音不经过副板本地功放。用闪屏与短音同步的本地视频检查音画相对同步。
5. 检查连续5分钟画面/声音、10次B口拔插、3次冷启动；拔源时停止输出，重插后应重新训练，无需整板复位。不支持的时序应保持无输出。

诊断数码管低四位定义：`P S FF`。`P`为相位扫描编号；`S`位2为正在相移，位1为三通道对齐一致，位0为帧格式有效；`FF`是每1ms源边沿计数的高8位，正常约`12`，不是分辨率/频率的十进制值。稳定时通常为 `P312`，无源通常为 `0000`；显示器未接入时源可能不输出。LED按ADC信号定义：`led[0]`/A4心跳，`led[1]`/A3时钟频段有效，`led[2]`/C10 PLL锁定，`led[3]`/B12格式有效，不沿用旧正式bit的LED含义。

请回报电脑是否识别、画面/声音是否正常以及数码管低四位。独立直通上板通过后再接入原副板自动切源；该诊断阶段通过不等于整套副板新增功能通过。
