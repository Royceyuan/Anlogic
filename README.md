# 双FPGA双屏博物馆展陈与应急信息终端——副板工程

适用安路HX4S20C（EG4S20BG256）。包含本地轮播/简介、应急图、两栏说明页、双板以太网控制、自动/手动同步，以及USB串口授权的PC HDMI音视频联动。

2026-10-13，用户上板反馈换源黑屏“确实减少了，在我接受范围内”。当前共用载波版本据此记录为本项上板验收通过；不宣称零黑屏、量化光学延迟或未经执行的长测通过。本轮仅精简播放器调试界面及整理发布文件，不修改已验收硬件。

## 1. 唯一入口与已验证bit

- TD入口：`dual_fpga_museum_terminal_secondary_board.al`。
- RTL顶层：`src/secondary/top_secondary_hdmi_museum.v`，模块名`top_secondary_hdmi_museum`。
- 当前已验收bit：`release/dual_fpga_museum_terminal_secondary_board_continuous_carrier.bit`，654090字节。
- SHA256：`656CD6BE5EC64411918EC60A1FDF29C05F011AB5C5A69478748177AAF08ED588`；校验文件为bit路径加`.sha256`。
- 发布清单：`release/manifest_secondary_continuous_carrier.json`；成功种子7及最终证据在`seed/continuous_carrier`。
- 必要播放器：`tools/PCVideoPlayer/MuseumPCVideoPlayer.exe`，源码、重编脚本、图标、壁纸及校验值同目录，无需Python或第三方播放器。
- release只保留当前bit；旧bit和旧播放器已归档到rubbish，可从Git历史回溯。历史成功种子及原始报告均保留，历史清单集中在`seed/release_history`，其中旧路径只表示当时产物，不是当前编译依赖。

## 2. 接线、视频和优先级

显示器始终接副板 **HDMIB**；电脑自身HDMI输出接 **HDMIA**；双板网线、主板已验证版本保持不变。本地页面也从B输出。当前使用AnlogicHDMI75、1280×720、推荐约60.61Hz（75MHz像素时钟）。均使用RGB8、SDR；不要把独立DP连接的显示器设置当作FPGA输入。电脑解码本地视频，FPGA转发HDMI，不需要以太网视频软件。

声音选择AnlogicHDMI对应HDMI设备，双声道48kHz24-bit LPCM，由B送显示器，不经副板功放。显示器须有音频播放能力。暂不支持1080p输入、HDCP、HDR、深色或压缩音频位流。

无授权或无有效信源时，原轮播、简介、说明页或应急页跟随最新状态。应急撤销所有普通视频，只允许新CMD06应急专用授权；有应急授权和有效信源时显示应急视频，否则显示原应急图。应急解除撤销应急授权，不恢复旧文物视频。普通联动仍检查实际文物、新鲜状态和恢复状态。FPGA只转发HDMI，不解码MP4；应急视频的文件选择、解码、静音循环由PC软件完成。

直通期间TF、SDRAM刷新、本地扫描、以太网、按键和拨码继续运行。STOP、断源或3秒未收到有效KEEPALIVE回到当前本地状态，不需KEY4、不重载全部素材。断源取消旧授权；普通联动失联后须重新进入或重新勾选。若重连后主板仍应急，软件重新申请应急专用授权，失联时仍保持原已知应急图。允许显示器切源重锁时短暂黑屏，不承诺无缝或未经实测的应急响应时间；强杀PC可能在3秒看门狗期间露出其桌面，不能作为认证消防系统。网络失联不是火警，尚未收到的应急不能被副板凭空推断。

### 电脑主动播放操作

1. 电脑HDMI→副板HDMIA，副板HDMIB→屏幕；双板以太网仍直连原端口。
2. 电脑USB→副板板载USB-UART Type-C（CH340），不是USB-JTAG；UART RX=F12、TX=D12，与官方第16例一致。需要系统已安装CH340驱动，程序不自动安装驱动。
3. Windows启用FPGA的AnlogicHDMI扩展屏，保持1280×720、RGB8、SDR；当前EDID目标为AnlogicHDMI75，推荐约60.61Hz。声音输出选择此HDMI目标，双声道48kHz/24-bit PCM。电脑自身视频编码可不同，解码后由GPU按这一路显示格式输出。程序不更改独立显示器/音频系统设置。
4. 双击电脑播放器，选择副板COM口并连接、选择AnlogicHDMI扩展屏、选择本地视频，点“播放到副屏”。若读不到对应EDID名称，程序拒绝把独立DP或主屏误当成HDMI视频目标。
5. 程序先静音准备全屏首帧，再授权并等待输出稳定后播放。暂停保留画面及保活；停止/结束先撤销授权并确认本地输出，再关闭置顶视频窗。串口失联时保留视频窗至硬件看门狗超时，避免正常停止时露出桌面。强杀程序无法保留窗口，最长约3秒才退回本地，不宣称此异常场景完全无桌面闪现。

Windows10/11 x64、.NET Framework 4.8、系统媒体组件；推荐MP4(H.264/AAC)。不保证任意编解码均支持；媒体失败、不含视频、输入未就绪、串口占用/错误COM均明确提示并保持/恢复本地。视频/音频实时走HDMI，不写TF，不经以太网或副板SDRAM。媒体播放依托[Windows WPF MediaElement](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/graphics-multimedia/multimedia-overview)。本机已验证原生H.264/AAC解码/结束事件；当前共用载波bit的换源黑屏已由用户确认缩短至可接受范围，不据此推断所有显示器均无缝。

### 五件文物自动联动操作

1. 烧录第1节的当前已验收bit，主板继续使用已验收版本，原双板网线不变。电脑只用HDMI和USB-UART，不需要电脑以太网IP或UDP5000端口。
2. 打开播放器，点击“文物与应急视频配置”，分别给文物0～4及应急指引选择视频，点击保存。任意本地可访问路径都可使用；五支文物短片在`../素材`，新应急片在`assets/emergency_video/06_博物馆应急疏散指引.mp4`，也已交付到`../素材/06_博物馆应急疏散指引.mp4`，不强制固定名字或路径。
3. 配置保存在`%LOCALAPPDATA%/DualFPGAMuseum/VideoPlayer.xml`，包含六个视频绝对路径和上次串口选择；下次启动恢复。程序目录可只读。损坏配置提示错误并保留原文件，配置写入先用临时文件再原子替换，保存失败不切换当前映射。
4. 连接正确串口，选择720p AnlogicHDMI扩展屏，勾选“联动模式”。程序启动默认不勾选，不自动连接串口或设置开机启动，避免意外授权显示。
5. 总览时按当前高亮文物静音准备视频首帧，但不会授权输出电脑画面。软件显示“首帧已准备”后，主板KEY2进入实际展示即可申请视频授权，不再等待主屏入场转场结束；文件播放完自动循环，视频始终静音，暂停/继续跟随主板。主板手动浏览也按实际文物联动，不把副板SW3请求值当成主板已经应用的状态。
6. 主板SW4进入应急时，硬件先撤销普通视频；软件优先接管后台已缓存的应急首帧、用CMD06申请授权；尚未缓存时先准备应急片，静音循环，不跟随讲解暂停。缺片或失效保留原应急图。应急解除退回本地，不复播旧文物片。主板退出、KEY4恢复、失联或断源仍撤销播放；普通联动重试需重新进入/勾选，当前应急在通信恢复后可以重新申请新授权。
7. 路径未配置、文件移动/删除、媒体失败时提示重新配置，该文物不反复自动重试；不永久阻塞其他文物。播放中也检查路径可访问性，失效先撤销授权再关视频窗。配置可以在停止或首帧准备期间修改，不可在播放中修改。软件“停止并回本地”会关闭联动并释放首帧文件；重新勾选才继续联动，移动视频文件前请先停止。
8. 不勾选联动时仍可按原方式选择任意视频并有声播放；主板正常讲解期间如需独立有声短片，请先暂停主板，避免混声。旧副板bit可继续手动播放，但状态查询会明确提示不支持联动。

这是**文物和操作状态联动**，不是两板逐采样音画同步。五支40.4秒短片循环陪衬现有主板讲解，不改主板音频/SUB时间轴。电脑、播放器、串口和HDMI扩展屏须持续可用，板卡不能在电脑关机或软件未运行时读取电脑本地视频。PC作为外部信源参与竞赛的合规边界仍需向组委会确认；离线展陈完整保留。

从远程复现：安装Git LFS，检出`secondary-main5e`后执行`git lfs pull`，确认bit、播放器EXE及BMP是实际文件而非LFS指针。FPGA编译不依赖电脑播放器；完整产品的主动播放演示则需要它，因此EXE、C#源码、manifest、重编脚本及校验值完整保留。软件自带“使用说明”，不能把必要工具当作缓存移走。

### 串口控制协议

115200、8N1、无流控。命令固定5字节`A5 5A CMD SEQ CRC`；应答`5A A5 SEQ FLAGS CRC`。CRC-8/SMBUS：poly=07、init=00、xorout=00、不反射，覆盖前4字节；“123456789”校验为F4。

CMD：01 START（输入有效且没有已知应急）、02 STOP、03 QUERY、04 KEEPALIVE。FLAGS bit0输入有效、bit1外部已选择、bit2输出处于静音/复位、bit3已授权、bit4视频首帧保持提示有效、bit5应急视频授权、bit7本次命令拒绝，其余为0。QUERY不能授权或延长租约；KEEPALIVE只延长已存在授权或首帧提示，不创建授权。未知命令拒绝，坏CRC/停止位丢弃；帧间断超10ms重新同步。一个未完成PC事务，250ms超时同序号重试最多3次；STOP可替代未完成请求，过期序号和旧串口实例的应答被忽略。START/STOP重复幂等。

新增CMD **05**查询展陈快照；请求仍5字节，应答为8字节`5A A6 SEQ FLAGS ARTIFACT STATE PHASE CRC8`，CRC覆盖前7字节。原01～04应答继续保持`5A A5`的5字节格式；新软件兼容旧bit的拒绝应答，仅关闭不支持的联动功能，不影响手动播放。

| STATE位 | 含义/来源 |
|---|---|
| 0 | 已收到主板心跳且peer_alive，新鲜有效；断线清0 |
| 1 | 实际已进入展示，主板mode=2且图片阶段0～4；不是预载/高亮 |
| 2 | 主板真实暂停标志（心跳bit68），包括转场暂停 |
| 3 | 最近已知应急；断线不自行清除 |
| 4 | 主板确认的手动浏览模式，DISPLAY_STATUS bit42 |
| 5 | 主板转场中；首次启动不等待转场结束，已播放时不因图片转场重启 |
| 6 | 启动、媒体故障或非应急的应用恢复；主板mode=3、应急有效且无媒体错误时，bit70的持续忙标志属于应急保持，不置此位 |
| 7 | 最终全貌结束停留状态 |

ARTIFACT为主板心跳中的文物0～4，启动未收到心跳时FF；失联保留最近已知编号但STATE bit0清0，软件不可据此启动。总览时该编号是当前高亮，STATE bit1为0；进入后才是实际展示文物。PHASE为实际图片槽0～4或总览FF。快照三个字段在应答开头锁存，避免串行发送期间被新心跳污染。

新增CMD **10～14（十六进制）**分别请求文物0～4的联动授权，继续返回原5字节ACK。硬件要求信源就绪、主板新鲜且实际展示该文物、无应急/恢复；把文物编号编码进命令，避免查询之后文物改变却授权旧文件。联动租约在实际文物改变、展示退出、心跳失效或恢复时撤销；旧01手动播放不要求双板在线，但仍受应急覆盖。

新增CMD **06**为应急专用START，原5字节请求/ACK，必须同时满足HDMI有效、主板状态新鲜、STATE bit3应急、无bit6恢复/故障；普通状态、失联、无源都拒绝。成功置FLAGS bit5，保持应急租约；应急解除、失联、恢复、断源、STOP、07释放或3秒看门狗到期立即作废。恢复后不复用旧授权。应急期间01/10～14仍拒绝，不允许普通视频替换应急片。06是播放类别限制，不验证HDMI像素内容；可信PC软件须选择正确应急文件，不能描述为媒体内容认证或安全认证。

新增CMD **20～24（十六进制）**：PC已经准备好文物0～4静音首帧的提示，不授权HDMI输出；必须信源有效、主板在线、编号匹配、无应急/恢复。提示生效时，讲解不加载本地简介，并冻结原轮播页供退出后直接恢复；总览仍轮播。02撤销播放但保留提示，**07**同时释放提示及播放；关闭联动、退出软件、普通停止使用07。提示随失联、信源失效、文物变化、应急/恢复或3秒看门狗失效清除，不影响离线简介。原始01～05包格式不变，MBP1不变；旧bit拒绝新提示时提示升级并降级运行，完整提速需要新bit。

PC约每50ms交替查询05和发03/04，授权或首帧准备期间KEEPALIVE约每100ms，硬件看门狗仍3秒；Windows调度和串口响应会影响实际间隔。PC快照超过1.5秒视为不可用；FPGA的主板在线性复用既有MBP1超时机制，不是新网络连接。软件短片循环不重新切钟或授权；正常停止仍确认本地输出后才关闭覆盖桌面的播放窗。首帧解码后的软件等待由300ms减到120ms，联动切源确认后等待由700ms减到100ms；手动播放仍保留700ms。

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

当前采用共用载波和统一序列化出口：PC已稳定连接时，本地画面和外部视频跟随同一恢复时钟/光栅，UART授权在帧边界改变内容，不切换输出时钟、不复位序列化器。视频和音频符号按同一条链路传递，未授权时替换为本地像素和有效静音包。物理断源仍需切回本地时钟，可能重锁；具体实现与边界见第10节。旧独立切源模块保留供兼容分支和回归，不是当前正常授权路径。

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
4. 种子**7**；ADC固定共享PLL x000y000、接收PLL x000y071。当前共用出口已移除旧DDR发送pair bank，构建Tcl只在旧bank实际存在时应用局部布局。GUI默认流程不包含全部门禁，完整复现以脚本为准。
5. bitgen拒绝setup/hold违例、TNS非0、多驱动/异常路径、陈旧数据库或缺失依赖。新bit板测后再发布，不把编译成功等同于上板通过。

发布STA：setup +0.023ns、hold +0.022ns，TNS均0；共用载波两种实际时钟模式均检查。相关50MHz域未作为假CDC屏蔽。功能上板通过不等于完成量化动态眼图/电气裕量验证。原厂SDRAM位置提示PHY-7002及一个局部时钟段PHY-5079保留并披露，重定位后实际路径纳入STA；无多驱动/异常路径，PLL分频/相位未为闭合时序更改。

## 7. 资源、回归与成功种子

| 资源 | 当前已验收版本 |
|---|---:|
| LUT | 12421/19600，63.37% |
| FF | 8207/19600，41.87% |
| Slice | 7073/9800，72.17% |
| BRAM9K | 28/64 |
| BRAM32K | 13/16 |
| DSP | 5/29 |
| PLL | 4/4 |
| GCLK | 11/16 |

setup +0.023ns、hold +0.022ns，TNS均0；现有PHY7002位置提示和PHY5079局部时钟布线提示保留披露。完整报告及96项构建输入校验在`seed/continuous_carrier`。本轮播放器界面变化不增加FPGA资源。

最新硬件回归共79条PASS，覆盖缓冲、公共输出、实际I/O和PLL模型、页面字形、UART及按键；具体命令和仿真边界见第10节。其他已有回归源码保留在sim，ModelSim工作库和日志可重新生成；`run_secondary_frame_store_alignment.do`从工程根目录运行，其余以do脚本内相对路径为准，通常从sim运行。历史成功seed不删除，报告旧路径不是重编依赖。

## 8. 验收与整理边界

- PC未接入或未授权：本地轮播、简介、应急图和副板SW4说明页正常；双板四键及SW3仍按第4节工作。
- 普通联动：主板确认进入后显示对应视频，暂停/继续跟随主板，退出后恢复本地；视频首帧未准备好时保持本地。
- 应急联动：主板SW4触发后撤销普通视频，使用新应急授权播放已配置指引；解除后回本地，不恢复旧片。
- 手动有声视频：正常播放/暂停/停止；断HDMI、串口或授权到期后回本地，重连重新申请授权。
- 普通换源黑屏已获本次用户认可；物理插拔、格式改变仍可能让显示器重锁，不宣称所有异常无黑屏。未报告的冷启动次数和长测结果不补写。
- 本轮未重编FPGA。所有RTL、约束、IP、MIF、必要素材和构建输入均保留，已验收bit校验不变。
- 归档位置：`D:\VSCode\CodeFiles\Git_TD\rubbish\secondary_player_release_20261013`。只移动旧候选bit/校验、旧播放器、旧README及诊断输出，不删除；移动清单保留各文件SHA256。正常工程编译和软件运行不依赖rubbish。

## 9. 电脑视频播放器界面与重建

双击 `tools/PCVideoPlayer/MuseumPCVideoPlayer.exe`，无终端窗口。墨绿背景、米白卡片及图标保留，窗口内容随缩放统一适配。已移除固定图黑屏对照、屏幕确认、切换计时与复制记录；只保留“联动模式”选项及正常连接、视频配置、播放、暂停、停止和状态。

操作仍是：连接 USB-UART → 选择 AnlogicHDMI 扩展屏 → 选择本地视频 → 播放。未授权保持副板本地内容；暂停保留视频画面，停止等待副板撤销授权后回本地。电脑需使用原说明规定的 720p、音频格式及 Windows 媒体组件，UI 更新不增加编解码支持。

在工程根目录执行 `& .\tools\PCVideoPlayer\build.ps1`，使用 Windows 自带 .NET Framework 编译器，嵌入背景和图标，运行 `--self-test` 并更新 EXE 校验文件，无新增 UI 框架。复核命令：

```powershell
Start-Process .\tools\PCVideoPlayer\MuseumPCVideoPlayer.exe -ArgumentList '--self-test' -WindowStyle Hidden -Wait -PassThru
Start-Process .\tools\PCVideoPlayer\MuseumPCVideoPlayer.exe -ArgumentList '--ui-test',"$PWD\_build_player_preview.png" -WindowStyle Hidden -Wait -PassThru
# 仅本机解码测试，不发送串口命令；视频应含音轨、短于10秒。
Start-Process .\tools\PCVideoPlayer\MuseumPCVideoPlayer.exe -ArgumentList '--media-test','C:\路径\短视频.mp4' -WindowStyle Hidden -Wait -PassThru
```

退出码 0 为通过。`--self-test`还检查配置XML保存/恢复、坏格式拒绝、未配置视频不反复重试、文物互不阻塞、应急再确认和过期状态处理；不连接真实串口。界面截图与解码测试不代替实板USB/HDMI验收。本轮仅整理界面及调试专用代码，当前已验收bit字节不变，无需重新烧录；主板和TF素材不换。

## 10. 共用载波、同一序列化出口

正式顶层默认 `COMMON_OUTPUT=1`。PC信号稳定存在时，本地简介和PC视频使用同一组恢复时钟、实际PC行场及四通道序列化器。UART开始、停止和应急授权只改变内容选择；开始交接等待对齐的垂直消隐，等待期间继续显示本地画面。PC物理插拔或输入失效时才更换载波时钟，因此该异常场景仍可能触发显示器重锁。

### 实现与边界

- `secondary_hdmi_carrier_clock`复用现有PLL，通过像素/串行时钟选择器跟随已确认的PC输入。增加两种输出时钟模式的实际SDC关系，未降低时钟频率、扩大输入支持范围或增加PLL。
- `secondary_hdmi_symbol_buffer`接收对齐的30bit符号，复用512深度官方FIFO；只在安全普通控制区调整水位，保护有效视频、前导、保护带和音频包。写侧水位寄存切断长组合路径。官方FIFO新增默认关闭的下降沿同步选项，仅本缓冲启用，其他FIFO调用保持原行为。
- `secondary_hdmi_pc_raster`解析实际行场，原媒体渲染跟随该扫描。实际本地像素流水线25级加TMDS编码3级；`secondary_hdmi_common_symbols`使用28拍BRAM延迟对齐PC原始流，再由同一个`secondary_hdmi_symbol_pairs`发送。
- 未授权时用本地画面替换PC有效像素，保留必要AVI等信息及ACR参考；双声道layout-0 LPCM样本改为零，重算奇偶/BCH。授权后原始音视频符号逐位保留。撤销发生在包中间时，该单个包可能失效；后续完整包为有效静音，不能描述为所有异常时刻均包无损。输入仍限定EDID约定的RGB8/SDR/720p及双声道LPCM。
- 物理载波更换只复位像素域，图片缓存、TF读取、SDRAM刷新和网络继续运行；缓存发布标志为零时也能恢复读图，先等待旧读响应结束。新增FIFO故障恢复会清理接收缓存及解析器，撤销旧授权后重新获取；它不会把普通视频权限扩展到应急。
- 状态文字改成固定字形计算后的单bit选择，逐像素等价，未增加像素流水线级数。本轮仅整理播放器调试界面；主板、RTL、TF卡及音画字幕时间轴不变。

### 编译与复现

使用唯一 `.al` 入口，或在副板根目录运行 `powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1`。脚本完整执行综合、布局布线、STA及bitgen；时序和依赖门禁拒绝不合格或过期数据库。当前成功布局种子为7，证据保存在 `seed/continuous_carrier`，`source_hashes.json`记录96项源码/依赖/构建脚本校验值。

最终布局布线：setup +0.023ns、hold +0.022ns，TNS均0。LUT12421/19600（63.37%），FF8207/19600（41.87%），Slice7073/9800（72.17%），BRAM9K28/64，BRAM32K13/16，DSP5/29，PLL4/4，GCLK11/16。相对28ADB40F本地HDMI流候选，LUT+58、FF−61、Slice−24、BRAM9K−1、GCLK+1。无多驱动/异常时序路径；保留原PHY7002位置提示和SDRAM时钟本地布线PHY5079提示，均详见console及timing报告。

回归命令位于 `sim`：

```powershell
& D:\Modelsim\win64\vsim.exe -c -do run_secondary_hdmi_symbol_buffer.do
& D:\Modelsim\win64\vsim.exe -c -do run_secondary_local.do
& D:\Modelsim\win64\vsim.exe -c -do run_secondary_hdmi_common_output.do
& D:\Modelsim\win64\vsim.exe -c -do run_secondary_hdmi_carrier_clock.do
& D:\Modelsim\win64\vsim.exe -c -do run_secondary_hdmi_pll_model.do
& D:\Modelsim\win64\vsim.exe -c -do run_secondary_hdmi_common_ingress.do
```

已完成：缓冲7项、实际渲染/音视频包6项、载波/四通道序列化5项、完整输入I/O至输出I/O 5项、PLL模型精度复现1项、本地页4项（含四种链路状态245760个文字像素等价）、原HDMI路径26项、帮助页加载1项、UART23项及按键1项，共79条PASS。完整I/O测试验证授权/停止无物理时钟间断或数据输出复位、输入仍有效时FIFO异常自行恢复且旧授权撤销、真实停钟回到本地；错误数0。所有最终日志保存在`seed/continuous_carrier`。

音频包测试使用完整1650×750光栅、实际本地渲染和TMDS编码，但媒体/SDRAM读取采用响应模型；完整I/O测试使用实际厂商I/O/PLL功能模型和UART，媒体/网络为stub，输入向量不含音频岛。两项共同提供图像/包/物理串行链的功能证据，不能合称真实TF/网络/PC声音系统的全部实板验证。初始化时的厂商未知值和测试未接端口提示保留。

厂商PLL功能模型对`$realtime`周期差乘1e8后取整判断失锁。独立复现确认，13.33ns测试时钟在约2^26ns后出现浮点舍入误判；改用二进制精确可表示的13.34375ns（约74.941MHz）周期后不再误判。完整输入测试采用1fs精度和该周期，仍在接收范围内；不改厂商模型、不强制锁定信号，也不修改生产PLL/EDID/SDC。最终完整重跑至68.186ms模拟时间通过全部5项，未把此前的模型误报计为通过。

### 当前验收结论与限制

仿真验证板内时钟、数据复位和符号连续性，不能测得实体显示器内部锁定时间。当前bit的实屏黑屏已由用户确认缩短至可接受范围，`board_pass=true`；未实测零黑屏，故`seamless_switch_verified=false`。以后更换显示器、输入格式或修改RTL仍需重新验收。

本轮仅替换播放器EXE，原视频路径配置沿用；重新打开软件、连接COM口、选择AnlogicHDMI75并勾选联动即可。主板、当前副板bit和TF素材无需更换。
