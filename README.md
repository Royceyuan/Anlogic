# 双FPGA双屏博物馆展陈与应急信息终端——副板工程

适用安路HX4S20C（EG4S20BG256）。实现本地展陈、主板状态联动、以太网画面控制、自动/手动同步、说明页、PC HDMI音视频直通及断源回退。2026-10-10用户确认集成现象正常并要求整理推送；未记录的播放时长、冷启动次数不补写为通过。

当前正式版包含USB串口授权播放：HDMI常连接不自动展示桌面，电脑播放器发START才显示视频，STOP或失联自动回本地。主板及MBP1不变。2026-10-11用户确认“目前功能正常，符合预期”，并要求整理推送；只记录这项功能验收，不补写未提供的长测次数或电气裕量结论。

## 1. 唯一入口与已验证bit

- TD入口：`dual_fpga_museum_terminal_secondary_board.al`。
- RTL顶层：`src/secondary/top_secondary_hdmi_museum.v`，模块名`top_secondary_hdmi_museum`。
- 唯一已上板bit：`release/dual_fpga_museum_terminal_secondary_board_uart_video.bit`，654090字节。
- SHA256：`E6C0A247EA0731ACC9FA4182A09A70A814D32BDF6339456FA8EEB2381DD270AF`，校验文件与bit同名，后缀`.sha256`。
- 正式发布信息及成功种子：`release/manifest_secondary_uart_video.json`、`seed/uart_video`，种子7。
- 必要电脑播放器：`tools/PCVideoPlayer/MuseumPCVideoPlayer.exe`；源代码及重编脚本同目录，无需安装Python或第三方播放器。

整理不改变硬件RTL行为；当前bit和播放器的字节及校验值不变。旧入口和旧bit在Git历史/rubbish保留，不作为当前工程入口；不会移出必要播放器、源码、TF素材、字库或成功种子。

当前正式版已完成完整综合、布局布线、STA/DRC和bitgen；setup/hold为+0.106/+0.021ns。历史85E5C239基线的重编等价证据仍保留在`seed/hdmi_museum/cleanup_verification.json`，仅作回溯，不是当前bit的报告。本次只整理发布文件和验收记录，不重新改变布局。

## 2. 接线、视频和优先级

显示器始终接副板 **HDMIB**；电脑自身HDMI输出接 **HDMIA**；双板网线、主板已验证版本保持不变。本地页面也从B输出。电脑选择AnlogicHDMI目标，输出1280×720、60/59.94Hz、RGB8、SDR；不要把独立DP连接的显示器设置当作FPGA输入。电脑解码本地视频，FPGA转发HDMI，不需要以太网视频软件。

声音选择AnlogicHDMI对应HDMI设备，双声道48kHz24-bit LPCM，由B送显示器，不经副板功放。显示器须有音频播放能力。暂不支持1080p输入、HDCP、HDR、深色或压缩音频位流。

无授权或无有效信源时，原轮播、简介、说明页或应急页跟随最新状态。输入连续8帧通过且收到合法UART START后，外部音视频优先，包括应急、说明页状态；FPGA不会替电脑打开逃生视频。直通期间TF、SDRAM刷新、本地扫描、以太网、按键和拨码继续运行，本地页面暂不显示。STOP、断源或3秒未收到有效KEEPALIVE会回到**当前**本地状态，不需KEY4、不重载全部素材；断源取消旧授权，重新连接不自动展示桌面。允许显示器重锁时短暂黑屏，不承诺无缝。已归档的85E5C239基线是输入有效自动优先，不用于当前功能验收。

### 电脑主动播放操作

1. 电脑HDMI→副板HDMIA，副板HDMIB→屏幕；双板以太网仍直连原端口。
2. 电脑USB→副板板载USB-UART Type-C（CH340），不是USB-JTAG；UART RX=F12、TX=D12，与官方第16例一致。需要系统已安装CH340驱动，程序不自动安装驱动。
3. Windows启用AnlogicHDMI为扩展屏，保持1280×720、60/59.94Hz、RGB8、SDR；声音输出选择AnlogicHDMI，双声道48kHz/24-bit PCM。电脑自身视频编码可不同，解码后由GPU按这一路显示格式输出。程序不更改显示器/音频系统设置。
4. 双击电脑播放器，选择副板COM口并连接、选择AnlogicHDMI扩展屏、选择本地视频，点“播放到副屏”。若读不到对应EDID名称，程序拒绝把独立DP或主屏误当成HDMI视频目标。
5. 程序先静音准备全屏首帧，再授权并等待输出稳定后播放。暂停保留画面及保活；停止/结束先撤销授权并确认本地输出，再关闭置顶视频窗。串口失联时保留视频窗至硬件看门狗超时，避免正常停止时露出桌面。强杀程序无法保留窗口，最长约3秒才退回本地，不宣称此异常场景完全无桌面闪现。

Windows10/11 x64、.NET Framework 4.8、系统媒体组件；推荐MP4(H.264/AAC)。不保证任意编解码均支持；媒体失败、不含视频、输入未就绪、串口占用/错误COM均明确提示并保持/恢复本地。视频/音频实时走HDMI，不写TF，不经以太网或副板SDRAM。媒体播放依托[Windows WPF MediaElement](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/graphics-multimedia/multimedia-overview)。本机已验证H.264/AAC含声画解码及结束事件，用户已确认新版本实板功能符合预期。

从远程复现：安装Git LFS，检出`secondary-main5e`后执行`git lfs pull`，确认bit、播放器EXE及BMP是实际文件而非LFS指针。FPGA编译不依赖电脑播放器；完整产品的主动播放演示则需要它，因此EXE、C#源码、manifest、重编脚本及校验值完整保留。软件自带“使用说明”，不能把必要工具当作缓存移走。

### 串口控制协议

115200、8N1、无流控。命令固定5字节`A5 5A CMD SEQ CRC`；应答`5A A5 SEQ FLAGS CRC`。CRC-8/SMBUS：poly=07、init=00、xorout=00、不反射，覆盖前4字节；“123456789”校验为F4。

CMD：01 START（仅输入已有效时接受）、02 STOP、03 QUERY、04 KEEPALIVE。FLAGS bit0输入有效、bit1外部已选择、bit2输出处于静音/复位、bit3已授权、bit7本次命令拒绝，其余为0。QUERY不能授权或延长租约；KEEPALIVE只延长已存在授权。未知命令拒绝，坏CRC/停止位丢弃；帧间断超10ms重新同步。PC每250ms保活，一个未完成事务，250ms超时同序号重试最多3次；停止可取代未完成请求，过期应答不驱动状态。START/STOP重复执行幂等。

重编电脑程序：PowerShell进入`tools/PCVideoPlayer`，执行`./build.ps1`，使用系统csc生成无终端EXE并运行报文自检。EXE可单独运行，其构建不依赖主板打包软件。`--media-test <本地文件>`是静音解码/结束事件核验，`--ui-test <PNG路径>`是无播放、无串口连接的界面渲染核验。

LED/数码管保留原媒体加载意义，不是独立诊断的A/B/C页，LED4也不是外部帧锁定指示。

## 3. TF素材与说明字库

使用FAT32，将下列最终素材按原名放在TF根目录。现有源文件已齐全，不需要Python生成工具：

| 文件 | 工程内来源 | 格式/用途 |
|---|---|---|
| IMAGE0.BMP～IMAGE4.BMP | assets/secondary_exhibit_720p_tf | 轮播，1280×720，24-bit未压缩BMP |
| IMAGE5.BMP～IMAGE9.BMP | assets/secondary_exhibit_720p_tf | 文物简介背景，同上 |
| IMAGEA.BMP | assets/secondary_emergency_720p_v2 | 应急图，同上 |
| IMAGEB.BMP | assets/secondary_help | 说明背景，160×90，24-bit未压缩BMP |

说明文字由FPGA叠加，中文ROM已在`src/secondary/secondary_help_font.vh`中，可直接综合。背景源PNG及辅助生成工具移入rubbish；仅在重新设计字库/背景时需恢复，不影响当前编译。不要混入旧尺寸或压缩BMP；上下方向、行填充和跨簇读取已有回归。

## 4. 副板控制与通信

四键控制主板画面，不选副板轮播素材。主板转场、应急或恢复期间可拒绝当前命令，后续正常状态仍能控制。

| SW2:SW1 | KEY1 | KEY2 | KEY3 | KEY4 |
|---|---|---|---|---|
| 00 | 标准 | 明亮 | 高对比 | 柔和 |
| 01 | 亮度减 | 亮度加 | 对比度减 | 对比度加 |
| 10 | 饱和度减 | 饱和度加 | 色温减 | 色温加 |
| 11 | 左移 | 右移 | 上移 | 下移 |

SW3=0请求自动讲解，=1请求手动浏览；以主板实际回报为准，重连后重新核对模式。SW4=0正常页面，=1操作说明，四键仍有效；不作为通讯开关或大步开关。有已授权外部视频时说明页暂不显示，停止、断源或授权到期后显示当前本地状态。

参数每次一档，当前索引范围亮度0～6、对比度0～4、饱和度0～5、色温0～6，主板显示百分比。平移每次20源像素，基于实际回报发绝对值，X限±240、Y限±135，仅在主板允许的图片状态及1×/2×下请求。手动切图、暂停、退出和恢复由主板已有按键实现；副板四键仍按上表操作。

固定副板`192.168.10.2:5000`，主板`192.168.10.1:5000`，MBP1不变。协议编码见`src/ethernet/mbp1_codec.v`，会话/ACK/去重/重连见`mbp1_secondary_endpoint.v`。控制0x13=预设、0x14=四项参数、0x15=视口、0x17=自动/手动；不按按键次数推测主板状态，使用实际心跳/显示回报。

## 5. 源码结构与切源

| 文件/目录 | 作用 |
|---|---|
| src/secondary/top_secondary_hdmi_museum.v | 产品顶层，终端/接收/输出连接 |
| src/secondary/top_secondary_main5e.v | 原媒体、网络和按键终端 |
| src/secondary/top_secondary_main5e_netdiag.v | 实际MAC/MBP1连接，不能按diag字样删除 |
| src/secondary/secondary_main5e_keys.v | 四键分组和SW3重连同步 |
| src/secondary/secondary_main5e_status_adapter.v | 主板实际状态到本地页 |
| src/memory/sdram_bmp_row_top_v66.v | TF、SDRAM、扫描、叠加；历史模块名top_v66保留 |
| src/storage、src/memory | FAT32、行缓存、打包、SDRAM/FIFO |
| src/secondary/secondary_help_overlay.v、secondary_help_font.vh | 两栏说明、中文ROM、底部状态 |
| src/clock/secondary_media_eth_pll.v | 媒体/以太网共享PLL |
| src/clock/hdmi_relay_clock.v | 输入测频、接收PLL、相位训练 |
| src/secondary/top_secondary_hdmi_relay_diag.v | 集成版接收核，不是无关诊断 |
| src/video/hdmi_relay_phy.v、hdmi_tmds_monitor.v | 四路采样、分组、符号和帧检查 |
| src/video/secondary_hdmi_local_pairs.v | 厂家RGB编码及原toggle/shift发送结构 |
| src/video/secondary_hdmi_source_switch.v | 静音、CSB时钟选择、一套ODDR |
| src/common/uart_byte_io.v、src/secondary/secondary_video_uart_control.v | 复用UART字节收发、CRC/ACK、视频授权及3秒失联回退；不导入字幕系统 |
| vendor | 必需厂家IP、加密RTL、初始化文件和版权 |
| sim | 当前回归源码/夹具，不是额外AL入口 |

本地与外部在一套输出ODDR**之前**选择，不在两套串行GPIO后复用。外部保留原四路TMDS时钟、视频、控制、数据岛、ACR和InfoFrame，不经SDRAM、不单独延迟音频。先输出复位8个50MHz周期，切钟后目标就绪等待至少1ms及空白/控制指示，再经4个串行周期释放。停止在高/低电平的源时钟不阻塞回退，其余系统不跟随复位。

`EXTERNAL_HDMI_PHY`、`EXTERNAL_TRANSMITTER`默认0，保留既有接口语义。不要按历史阶段名删掉AL引用的源文件。sim中的独立AV参考顶层只用于回归。

官方EDID来自`HX4S20_Contest_202606/2_Example/HDMI环出实验/eg4s324_hdmi_loop`中的iic/al_ip，复用已通过握手及ROM，仅适配初始化路径。所需厂家副本均在vendor，保留源码版权；编译不依赖工程外官方例程或rubbish。

## 6. 代码审查、手动构建与生成bit

工具：`D:\TD_6.2.1\bin\td_commands_prompt.exe`（已验证6.2.168116），`D:\Modelsim\win64\vsim.exe`。

1. TD打开唯一AL，进入TOP_MODULE审查RTL，AL列出完整源文件/约束。
2. PowerShell进入工程根目录，运行：

~~~powershell
.\scripts\build.ps1
~~~

执行综合、合法化、布局、布线、hold修复、STA、DRC和bitgen。新bit/报告输出到`build/`，**不自动覆盖已上板release bit**；可用`-TD`指定编译器路径。

3. 手动TD Tcl：从工程根目录执行`source scripts/synthesize_and_route.tcl`，成功后执行`source scripts/generate_bitstream.tcl`。
4. 种子**7**；ADC固定共享PLL x000y000、接收PLL x000y071；DDR lane0/1的2×4局部布局在构建Tcl。GUI默认布局不包含全部步骤，不能当成已验证策略。
5. bitgen拒绝setup/hold违例、TNS非0、多驱动/异常路径、陈旧数据库或缺失依赖。新bit板测后再发布，不把编译成功等同于上板通过。

发布STA：setup +0.106ns、hold +0.021ns，TNS均0；tx_local_serial、tx_external_serial两种模式和各自源到TX都检查。相关50MHz域未作为假CDC屏蔽。功能上板通过不等于完成量化动态眼图/电气裕量验证。原厂SDRAM位置提示PHY-7002及一个局部时钟段PHY-5079保留并披露，重定位后实际路径纳入STA；无多驱动/异常路径，PLL分频/相位未为闭合时序更改。

## 7. 资源、回归与成功种子

| 资源 | 已验证版本占用 |
|---|---:|
| LUT | 11255/19600，57.42% |
| FF | 7254/19600，37.01% |
| Slice | 6455/9800，65.87% |
| BRAM9K | 21/64 |
| BRAM32K | 13/16 |
| DSP | 5/29 |
| PLL | 4/4 |
| GCLK | 10/16 |

`seed/uart_video`保留当前成功种子7及原始资源/时序/DRC/bitgen/回归证据。`seed/hdmi_museum`等目录保留历史成功记录，不移入rubbish；不是额外工程入口。报告旧路径是生成时的记录，不是当前编译依赖。

相对前版增加289 LUT、154 FF、141 Slice，BRAM、DSP、PLL、GCLK不增加；未修改时钟/相位/时序例外。8组27条回归通过，涵盖UART、集成AV、死钟回退、厂家本地发送器等价、按键、MBP1、页面和说明字库。UART新增首级异步同步器按现有板载输入方式处理，仿真不代替实板USB线路和亚稳态验证；用户已确认当前功能符合预期。

回归覆盖切源、AV、本地厂家发送器等价、按键、状态、说明页、切页、MBP1重连、帧缓存、PLL和BMP异常格式。例：

~~~powershell
cd sim
& D:\Modelsim\win64\vsim.exe -c -do .\run_secondary_hdmi_museum.do
& D:\Modelsim\win64\vsim.exe -c -do .\run_secondary_hdmi_source_switch.do
& D:\Modelsim\win64\vsim.exe -c -do .\run_secondary_main5e_endpoint.do
~~~

`sim/run_secondary_frame_store_alignment.do`从工程根目录运行，其余按do中的相对路径从sim运行。仿真库/日志可重新生成。集成AV测试使用缩短几何及媒体/网络时钟模型，实际模块独立回归，不是全系统电气/SDF验证。原厂VHDL启动未知值警告保留，暖机后比较拒绝未知输出；数据岛样式比较不是有效LPCM/BCH包生成，实际声音同步来自用户板测。

## 8. 验收与整理边界

- B接屏幕、A无源：轮播/简介、SW4、应急及退出、双板四键和SW3正常。
- 接A电脑但不授权：保持本地；电脑播放器点击播放才显示视频，暂停保留画面，停止/结束恢复本地。
- 已授权播放时：音视频正常，副板仍控制主板，本地说明/应急不抢占。
- 拔A：重锁后回当前本地页，不按KEY4重载；重插仍保持本地，需要重新点击播放。
- 网线重连后SW3同步；主板暂停/恢复、手动→自动等按原行为检查。
- 已验证bit字节不变；未提供的量化长测/冷启动记录不虚构。

历史入口、旧bit、构建数据库、日志、转储、仿真缓存和辅助工具已移动到rubbish而非删除。成功种子、所有AL依赖、包含文件、TEMAC配置/门级文件、EDID MIF、最终TF素材、回归源码保留。审查代码和完整手动构建不依赖rubbish。

本次发布整理归档：`D:\VSCode\CodeFiles\Git_TD\rubbish\副板发布整理_20261011_372f809`，仅移动旧85E5C239 bit和旧发布清单；移动清单及保留文件校验同目录保存。未改RTL、约束或构建流程，无需因整理重新烧录、改TF卡或替换播放器。

## 9. 电脑视频播放器界面与重建

双击 `tools/PCVideoPlayer/MuseumPCVideoPlayer.exe`，无终端窗口。2026-10-11 桌面 UI 改为墨绿博物馆背景、米白设备/状态卡片和青铜播放图标。串口 CRC/ACK、授权、保活、暂停、停止/结束回本地、断线处理及 HDMI 视频窗口均保持原实现；不修改双板协议或 FPGA bit。

操作仍是：连接 USB-UART → 选择 AnlogicHDMI 扩展屏 → 选择本地视频 → 播放。未授权保持副板本地内容；暂停保留视频画面，停止等待副板撤销授权后回本地。电脑需使用原说明规定的 720p、音频格式及 Windows 媒体组件，UI 更新不增加编解码支持。

在工程根目录执行 `& .\tools\PCVideoPlayer\build.ps1`，使用 Windows 自带 .NET Framework 编译器，嵌入背景和图标，运行 `--self-test` 并更新 EXE 校验文件，无新增 UI 框架。复核命令：

```powershell
Start-Process .\tools\PCVideoPlayer\MuseumPCVideoPlayer.exe -ArgumentList '--self-test' -Wait -PassThru
Start-Process .\tools\PCVideoPlayer\MuseumPCVideoPlayer.exe -ArgumentList '--ui-test',"$PWD\_build_player_preview.png" -Wait -PassThru
# 仅本机解码测试，不发送串口命令；视频应含音轨、短于10秒。
Start-Process .\tools\PCVideoPlayer\MuseumPCVideoPlayer.exe -ArgumentList '--media-test','C:\路径\短视频.mp4' -Wait -PassThru
```

退出码 0 为通过。界面截图与解码测试不代替实板串口/HDMI 验收；本轮协议自检和 H.264/AAC 解码通过，控制/播放状态机与上一版逐段核对不变。只需更换软件，不必重新烧录。

`theme` 是必要重建素材，运行不依赖外部图片。内置 imagegen 与主板软件统一设计：暗墨绿博物馆、右侧青铜暖光、无文字背景；透明外缘、墨绿圆角底、象牙白门廊与青铜播放三角图标。ICO 含 16～256 像素尺寸，不使用字体图标或额外依赖。
