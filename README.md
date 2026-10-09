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
4A8B63438D991249D80CA5DA47A06AB76C7D9821BCC0905434F6D1D07C077BF4
```

### 实现与验证边界

- 使用官方IDDRx2/ODDRx2，四条通道（包括TMDS时钟）共用采样/发送时钟及延迟，原样重发串行位流，音频数据岛不剥离。无需SDRAM帧缓存、DSP或BRAM。
- 内置只读E-DDC：256字节EDID，仅声明720p60/59.94、RGB8及双声道48kHz/16-bit LPCM，不支持HDCP、HDR、深色或1080p。声明能力不是实际音视频通过的证据。
- 接收端在配置后先保持上游HPD低约200ms，再拉高；EDID服务独立于输出显示器HPD。下游HPD只控制实际输出，使电脑枚举不被下游握手卡住。EDID请求/读地址被记录为诊断标志，标志并不证明电气层已经完整读出EDID。
- 约3ms时钟测量就绪后锁定接收PLL；三通道符号对齐一致，连续8帧总时序正确才使能输出。不合格时每约200ms步进采样相位并重新训练；下游断开或源时钟停止会关闭输出。
- 诊断版时钟识别范围为74.0～75.1MHz，覆盖标准74.25/74.176MHz以及当前已通过主板的整数PLL 75MHz输出。75MHz只是辅助板间测试能力，EDID不变，仍仅声明标准720p；行/帧总时序仍检查1650×750，没有取消格式拒绝。STA按上限75.1MHz而非较慢的74.25MHz约束。
- 监测器只是使能判据，不是RGB解码、逐像素合法性检查或误码率测量。真实线缆、输入电平、抖动和像素/声音正确性仍需板测。
- 本独立bit没有TF、SDRAM、本地图片、说明页和以太网功能；没有信号时黑屏/显示器无信号属预期。正式版本后续才整合自动切源和回退。

时序边界必须明确：`secondary_hdmi_relay_diag.sdc`只对三根外部TMDS数据输入到首级IOL采样器设置例外，因为运行时动态调整采样相位，没有固定外部建立/保持关系。**串行输入眼图余量未由STA证明**，不能称为全链路时序已证明。DDR并行输出、接收监测、发送器及复位的内部路径仍接受STA；50MHz与外部接收域的真实CDC使用同步器。该边界和板测依据应随最终作品保留。

独立诊断实际资源：LUT1126/19600（5.74%）、FF635/19600（3.24%）、Slice656/9800（6.69%）、PLL1/4、GCLK4/16、BRAM9K/BRAM32K/DSP均0。**这些不是完整副板集成后的资源用量。** 内部setup +0.135ns、hold +0.057ns、TNS均0，无多驱动及异常时序路径。50MHz板载时钟存在工具PHY-5079局部布线提示，路径已被STA覆盖，没有新增忽略内部路径的例外。种子6和原始报告/日志保存在 `seed/hdmi_relay_diag`。

五组HDMI仿真共29条PASS：EDID校验、重复起始/连续读取/分段边界/NACK及诊断标志，另覆盖空闲/上电卡低/实际边沿检测；官方DDR模型四通道位级一致；官方PLL联合模型60/59.94/75MHz、相移、失源及75.4/148.5MHz拒绝；含音频数据岛的控制同步、错误总时序/不同通道位偏移拒绝；顶层用74.25、75MHz及带逐通道时钟偏斜的75MHz三种案例验证HPD、B页、使能、重训、插拔，偏斜案例另检查1000次四通道逐位输出一致。顶层测试缩短HPD/时钟计数窗口及帧尺寸，生产参数不变。TD自带PLL仿真模型的load_reg端口宽度与综合原语不同，有一条已知宽度警告；连接恒为0，不启用动态参数加载。

从 `sim` 运行 `run_hdmi_edid_720p.do`、`run_hdmi_relay_phy.do`、`run_hdmi_relay_clock.do`、`run_hdmi_tmds_monitor.do`、`run_hdmi_relay_diag.do`，均需退出码0、PASS且无Fatal/Error。

### 上板操作及预期现象

1. 优先通过JTAG临时加载上述诊断bit，不先覆盖已经稳定的Flash版本；主板不用改。
2. 显示器接副板 **HDMIA**，电脑输出接副板 **HDMIB**，勿接反。电脑选复制或扩展，活动信号设1280×720、60Hz或59.94Hz，RGB8；禁用HDR和受保护视频。首次可先测试桌面/自制彩条。
3. 烧录后拔插一次电脑到B口的HDMI线，使其重新枚举。FPGA自身EDID名称为 `FPGA-720P`，并非要求给实体显示器改名。稳定输入经8帧判定后，显示器应显示电脑画面；相位重训可能多等几个约200ms周期。实际HDMI输入尚未通过板测，不能保证本机自动选择的分辨率。
4. 测音频时电脑播放设备选该HDMI设备，设置双声道、48kHz、16-bit LPCM；显示器须能接收HDMI音频并有扬声器或音频输出。声音不经过副板本地功放。用闪屏与短音同步的本地视频检查音画相对同步。
5. 检查连续5分钟画面/声音、10次B口拔插、3次冷启动；拔源时停止输出，重插后应重新训练，无需整板复位。不支持的时序应保持无输出。

诊断数码管低四位每约0.67秒按 `A页 → 时钟页 → B页 → 时钟页` 轮换，记下A、B及计数三组数；不方便录像可直接文字回复：

- 状态页 `A H R P`：`A`固定页标识；`H`的位3=上游HPD就绪、位2=下游显示器HPD、位1=收到EDID读地址、位0=收到DDC起始；`R`的位3=输入时钟频段有效、位2=PLL锁定、位1=三通道对齐、位0=帧格式有效；`P`为相位扫描编号。它们都是十六进制。
- 时钟页显示每1ms源边沿计数除以16的十六进制值，标准74.25MHz约为 `1220`，主板75MHz约为 `124F`；不是分辨率。如果仍为 `0000`，表示计数不足16，不能武断地认定就是完全零边沿。
- 总线页 `B X Y S`：`XY`是一字节掩码：位7=SCL当前高/低，位6=SDA当前高/低，位5=SCL曾低，位4=SDA曾低，位3=SCL曾跳变，位2=SDA曾跳变，位1=FPGA当前请求拉低SDA，位0=曾测到非零源时钟计数；`S`为EDID状态机编号（0空闲，1收地址，7发送数据，B忽略）。低电平/边沿标志在烧录启动后累计，跳变记录排除了同步器复位填充的假边沿；SDA跳变可能来自电脑也可能来自FPGA应答，不能单凭标志证明电脑通信正常。
- 总线例子：`BC00`=SCL/SDA均高，未记录低电平、跳变或源时钟计数；`B300`=SCL/SDA均低且曾低，但未记录实际跳变；`BFD0`=当前均高，两线曾低且跳变，曾有源时钟计数，解析器空闲。B页只是数字逻辑电平观察，不是电压/波形测量；FPGA引脚没看到跳变不等于电脑插口绝对没发信号。
- 例：`AC00`表示内部请求向电脑输出HPD高、显示器侧HPD输入采样高，但没看到EDID访问/接收锁定；它不证明电脑插口实际收到HPD，也不是电脑插线检测。`AF00`表示收到EDID读请求但输入接收未锁定；`AFF0`表示EDID请求、时钟、PLL、对齐及格式均有效（相位0）。没有EDID读取也可能是电脑使用缓存，需结合时钟页判断。

LED按ADC信号定义：`led[0]`/A4心跳，`led[1]`/A3时钟频段有效，`led[2]`/C10 PLL锁定，`led[3]`/B12格式有效，不沿用旧正式bit的LED含义。

实板记录：`BF52A118`/`94d0726`未通过，LED1心跳、其余灭、数码管0000。`9E7502AC`/`3ff1753`仍为AC00/0000，尚未修好实板故障。后续用户明确：G52 Max同时通过Type-C→DP连接电脑，之前的2560×1440/180Hz及改为720p60截图属于独立DP通道，不能作为PC→FPGA HDMI输入格式证据；此前据此排查分辨率的判断撤回。用户确认电脑自身HDMI口→副板HDMIB，副板HDMIA→显示器HDMI。当前版只增加现有同步器上的被动DDC/时钟观测，不改音视频转发、按键、EDID内容、电平标准或显示器设置，仍待定位根因。

板级疑点记录：提供的HDMI原理图将DDC转换器标为TXB0104PWR，配置1kΩ/1.5kΩ上拉；[TI数据手册7.3.5](https://www.ti.com/lit/ds/symlink/txb0104.pdf)明确其不适用于I²C开漏接口，外部上拉应大于50kΩ。这仅说明原理图存在值得核实的兼容性疑点，**实物型号、模拟电平与波形均未确认，不能判定该器件就是故障根因**。不擅自要求焊接改板，不把SDA改为推挽输出。

旧定位版`3B43B732`/`2c630e2`用电脑作源时为`AC00 → 0000 → BC00 → 0000`，插拔后用户报告不变。旁路同一电脑HDMI口/线直连屏幕可以显示，排除该源口/线/屏幕基本输出故障。改用主板HDMIA→副板HDMIB，副板HDMIA→屏幕时为`AD00 → 124F → BFD0 → 124F`：已看到75MHz时钟和DDC引脚低电平/跳变，但没有读地址标志，不能称作成功EDID通信；旧版74.0～74.5MHz门槛使PLL保持复位，解释了这次板间测试无信号，不解释电脑作源时为何没有输入。主板源码`hdmi_pixel_clock_pll.v`明确配置75MHz，与计数一致。

75MHz兼容版`D0E16F2E`/`356ba58`板测仍无信号：A页为ADCx且x持续0～F，计数124F，LED2/3常亮、LED4灭，B页用户记录为“db50”（未将此读数擅自解释成其他值）。时钟与PLL已通过，当前停在通道对齐之前。

本次仿真复现：给三个IOL的串行/并行时钟加入相反方向的0.25ns路径差，旧同相配置出现`clock=1 PLL=1 lane_locks=111 offsets=353 aligned=0 format=0`。这只是一个可复现且与现场阶段相符的失效场景，**不是实测板上偏斜，也不能据此宣布已确认全部根因**。将并行时钟细相位由4改为0，使其在75MHz下领先串行时钟约0.667ns，避开捕获临界边沿；两路运行时相移仍保持相同增量。该案例修正后可对齐、通过帧判定，并保持四通道逐位一致，共同延迟11UI。前/后证据保留在 `seed/hdmi_relay_diag/capture_skew_before.log` 与 `capture_skew_after.log`。

同时将IOL采样复位在串行域两级释放，发送允许在串行下降沿采样、上升沿释放复位，避免新相位关系下不足一个周期的复位恢复路径。格式、同偏移及8帧判定未绕过，SDA/HPD/EDID、主板及正式副板/共享PLL bit均不变。

当前版仍按75.1MHz闭合内部时序，待板测。保持主板正式bit和当前接线，只更新副板诊断bit。预期计数仍124F，A页R从C推进到E/F，LED4亮且相位编号停止连续扫描；典型完整就绪为`ADF?`。没有画面则回报新A/B/计数及LED。板间通过仍不等于PC EDID/输入电气问题已经解决。

请回报电脑是否识别、画面/声音是否正常以及数码管低四位。独立直通上板通过后再接入原副板自动切源；该诊断阶段通过不等于整套副板新增功能通过。
