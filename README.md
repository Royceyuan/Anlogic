# 双FPGA双屏博物馆展陈与应急信息终端——副板工程

适用安路HX4S20C（EG4S20BG256）。实现本地展陈、主板状态联动、以太网画面控制、自动/手动同步、说明页、PC HDMI音视频直通及断源回退。2026-10-10用户确认集成现象正常并要求整理推送；未记录的播放时长、冷启动次数不补写为通过。

当前正式版包含USB串口授权播放：HDMI常连接不自动展示桌面，电脑播放器发START才显示视频，STOP或失联自动回本地。主板及MBP1不变。2026-10-11用户确认“目前功能正常，符合预期”，并要求整理推送；只记录这项功能验收，不补写未提供的长测次数或电气裕量结论。

**当前源码与电脑播放器已增加五件文物视频配置及自动联动；新副板bit已完成仿真、综合、布局布线和bitgen，尚待上板验收。** 主板、TF素材和MBP1不修改。保留上述已验收版本用于回退，不能把旧版验收转用于新联动功能。

## 1. 唯一入口与已验证bit

- TD入口：`dual_fpga_museum_terminal_secondary_board.al`。
- RTL顶层：`src/secondary/top_secondary_hdmi_museum.v`，模块名`top_secondary_hdmi_museum`。
- 唯一已上板bit：`release/dual_fpga_museum_terminal_secondary_board_uart_video.bit`，654090字节。
- SHA256：`E6C0A247EA0731ACC9FA4182A09A70A814D32BDF6339456FA8EEB2381DD270AF`，校验文件与bit同名，后缀`.sha256`。
- 正式发布信息及成功种子：`release/manifest_secondary_uart_video.json`、`seed/uart_video`，种子7。
- 必要电脑播放器：`tools/PCVideoPlayer/MuseumPCVideoPlayer.exe`；源代码及重编脚本同目录，无需安装Python或第三方播放器。
- 新联动提速候选：`release/dual_fpga_museum_terminal_secondary_board_linked_video.bit`，SHA256 `5BDAA5478EAFA2E5E40B43F85B59FCA7F81FBA9C4C9F6570AEC6BE57F4561C9F`；使用当前播放器，主板bit不用更换。
- 当前源码的资源/时序及协议记录：`release/manifest_secondary_linked_video.json`、`seed/linked_video_fast_switch`。旧`seed/linked_video`和`manifest_secondary_uart_video.json`保留历史组合，历史播放器哈希不是当前新EXE。

工程入口仍唯一。本轮只更改副板状态导出、UART授权/回报和播放器，不改HDMI物理数据路径、PLL、管脚或时序约束。旧入口和历史文件在Git/rubbish回溯；必要工具、素材及成功种子保留。

已验收UART版setup/hold为+0.106/+0.021ns；当前联动提速候选为+0.105/+0.021ns，TNS均0。历史85E5C239基线证据仍保留在`seed/hdmi_museum/cleanup_verification.json`，仅作回溯，不是当前源码的报告。

## 2. 接线、视频和优先级

显示器始终接副板 **HDMIB**；电脑自身HDMI输出接 **HDMIA**；双板网线、主板已验证版本保持不变。本地页面也从B输出。电脑选择AnlogicHDMI目标，输出1280×720、60/59.94Hz、RGB8、SDR；不要把独立DP连接的显示器设置当作FPGA输入。电脑解码本地视频，FPGA转发HDMI，不需要以太网视频软件。

声音选择AnlogicHDMI对应HDMI设备，双声道48kHz24-bit LPCM，由B送显示器，不经副板功放。显示器须有音频播放能力。暂不支持1080p输入、HDCP、HDR、深色或压缩音频位流。

无授权或无有效信源时，原轮播、简介、说明页或应急页跟随最新状态。当前候选优先级为**已收到的主板应急 > 获授权外部视频 > 本地展陈**；应急撤销手动/联动视频授权，解除不会自行恢复旧授权。联动授权还检查主板状态新鲜、实际展示文物及恢复状态，失联或文物变化自动撤销；普通手动授权在非应急时保留原行为。FPGA不会替电脑生成/解码视频或打开逃生视频。

直通期间TF、SDRAM刷新、本地扫描、以太网、按键和拨码继续运行。STOP、断源或3秒未收到有效KEEPALIVE回到**当前**本地状态，不需KEY4、不重载全部素材。断源取消旧授权；联动遇到应急/失联后先回本地，需新一次总览→展示或重新勾选联动才能重试。允许显示器切源重锁时短暂黑屏，不承诺无缝、零桌面闪现或未经实测的应急响应时间。网络失联不是火警，已知应急在失联期间保持；尚未收到的应急不能被副板凭空推断。

### 电脑主动播放操作

1. 电脑HDMI→副板HDMIA，副板HDMIB→屏幕；双板以太网仍直连原端口。
2. 电脑USB→副板板载USB-UART Type-C（CH340），不是USB-JTAG；UART RX=F12、TX=D12，与官方第16例一致。需要系统已安装CH340驱动，程序不自动安装驱动。
3. Windows启用AnlogicHDMI为扩展屏，保持1280×720、60/59.94Hz、RGB8、SDR；声音输出选择AnlogicHDMI，双声道48kHz/24-bit PCM。电脑自身视频编码可不同，解码后由GPU按这一路显示格式输出。程序不更改显示器/音频系统设置。
4. 双击电脑播放器，选择副板COM口并连接、选择AnlogicHDMI扩展屏、选择本地视频，点“播放到副屏”。若读不到对应EDID名称，程序拒绝把独立DP或主屏误当成HDMI视频目标。
5. 程序先静音准备全屏首帧，再授权并等待输出稳定后播放。暂停保留画面及保活；停止/结束先撤销授权并确认本地输出，再关闭置顶视频窗。串口失联时保留视频窗至硬件看门狗超时，避免正常停止时露出桌面。强杀程序无法保留窗口，最长约3秒才退回本地，不宣称此异常场景完全无桌面闪现。

Windows10/11 x64、.NET Framework 4.8、系统媒体组件；推荐MP4(H.264/AAC)。不保证任意编解码均支持；媒体失败、不含视频、输入未就绪、串口占用/错误COM均明确提示并保持/恢复本地。视频/音频实时走HDMI，不写TF，不经以太网或副板SDRAM。媒体播放依托[Windows WPF MediaElement](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/graphics-multimedia/multimedia-overview)。本机已验证原生H.264/AAC解码/结束事件；用户确认的是旧UART主动播放版，当前联动候选尚待实板验证。

### 五件文物自动联动操作

1. 烧录上文`linked_video.bit`，主板继续使用已验收版本，原双板网线不变。电脑只用HDMI和USB-UART，不需要电脑以太网IP或UDP5000端口。
2. 首次打开播放器，点击“五件文物视频配置”，分别给文物0～4选择视频，点击保存。可从任何本地可访问位置选择；当前五支短片在`../素材/01_越王勾践剑.mp4`～`05_长信宫灯.mp4`，不强制使用这些名字或路径。
3. 配置保存在`%LOCALAPPDATA%/DualFPGAMuseum/VideoPlayer.xml`，包含五个绝对路径和上次串口选择；下次启动恢复。程序目录可只读。损坏配置提示错误并保留原文件，配置写入先用临时文件再原子替换，保存失败不切换当前映射。
4. 连接正确串口，选择720p AnlogicHDMI扩展屏，勾选“联动模式”。程序启动默认不勾选，不自动连接串口或设置开机启动，避免意外授权显示。
5. 总览时按当前高亮文物静音准备视频首帧，但不会授权输出电脑画面。软件显示“首帧已准备”后，主板KEY2进入实际展示即可申请视频授权，不再等待主屏入场转场结束；文件播放完自动循环，视频始终静音，暂停/继续跟随主板。主板手动浏览也按实际文物联动，不把副板SW3请求值当成主板已经应用的状态。
6. 主板退出、KEY4恢复、应急、双板状态失联、HDMI或串口断源，退回本地。应急由FPGA撤销授权，不等待电脑执行STOP。应急解除/重连不复播旧片；回总览后新一次KEY2进入，或明确关闭再开启联动，才重试。
7. 路径未配置、文件移动/删除、媒体失败时提示重新配置，该文物不反复自动重试；不永久阻塞其他文物。播放中也检查路径可访问性，失效先撤销授权再关视频窗。配置可以在停止或首帧准备期间修改，不可在播放中修改。软件“停止并回本地”会关闭联动并释放首帧文件；重新勾选才继续联动，移动视频文件前请先停止。
8. 不勾选联动时仍可按原方式选择任意视频并有声播放；主板正常讲解期间如需独立有声短片，请先暂停主板，避免混声。旧副板bit可继续手动播放，但状态查询会明确提示不支持联动。

这是**文物和操作状态联动**，不是两板逐采样音画同步。五支40.4秒短片循环陪衬现有主板讲解，不改主板音频/SUB时间轴。电脑、播放器、串口和HDMI扩展屏须持续可用，板卡不能在电脑关机或软件未运行时读取电脑本地视频。PC作为外部信源参与竞赛的合规边界仍需向组委会确认；离线展陈完整保留。

从远程复现：安装Git LFS，检出`secondary-main5e`后执行`git lfs pull`，确认bit、播放器EXE及BMP是实际文件而非LFS指针。FPGA编译不依赖电脑播放器；完整产品的主动播放演示则需要它，因此EXE、C#源码、manifest、重编脚本及校验值完整保留。软件自带“使用说明”，不能把必要工具当作缓存移走。

### 串口控制协议

115200、8N1、无流控。命令固定5字节`A5 5A CMD SEQ CRC`；应答`5A A5 SEQ FLAGS CRC`。CRC-8/SMBUS：poly=07、init=00、xorout=00、不反射，覆盖前4字节；“123456789”校验为F4。

CMD：01 START（输入有效且没有已知应急）、02 STOP、03 QUERY、04 KEEPALIVE。FLAGS bit0输入有效、bit1外部已选择、bit2输出处于静音/复位、bit3已授权、bit4视频首帧保持提示有效、bit7本次命令拒绝，其余为0。QUERY不能授权或延长租约；KEEPALIVE只延长已存在授权或首帧提示，不创建授权。未知命令拒绝，坏CRC/停止位丢弃；帧间断超10ms重新同步。一个未完成PC事务，250ms超时同序号重试最多3次；STOP可替代未完成请求，过期序号和旧串口实例的应答被忽略。START/STOP重复幂等。

新增CMD **05**查询展陈快照；请求仍5字节，应答为8字节`5A A6 SEQ FLAGS ARTIFACT STATE PHASE CRC8`，CRC覆盖前7字节。原01～04应答继续保持`5A A5`的5字节格式；新软件兼容旧bit的拒绝应答，仅关闭不支持的联动功能，不影响手动播放。

| STATE位 | 含义/来源 |
|---|---|
| 0 | 已收到主板心跳且peer_alive，新鲜有效；断线清0 |
| 1 | 实际已进入展示，主板mode=2且图片阶段0～4；不是预载/高亮 |
| 2 | 主板真实暂停标志（心跳bit68），包括转场暂停 |
| 3 | 最近已知应急；断线不自行清除 |
| 4 | 主板确认的手动浏览模式，DISPLAY_STATUS bit42 |
| 5 | 主板转场中；首次启动不等待转场结束，已播放时不因图片转场重启 |
| 6 | 启动、故障或应用恢复 |
| 7 | 最终全貌结束停留状态 |

ARTIFACT为主板心跳中的文物0～4，启动未收到心跳时FF；失联保留最近已知编号但STATE bit0清0，软件不可据此启动。总览时该编号是当前高亮，STATE bit1为0；进入后才是实际展示文物。PHASE为实际图片槽0～4或总览FF。快照三个字段在应答开头锁存，避免串行发送期间被新心跳污染。

新增CMD **10～14（十六进制）**分别请求文物0～4的联动授权，继续返回原5字节ACK。硬件要求信源就绪、主板新鲜且实际展示该文物、无应急/恢复；把文物编号编码进命令，避免查询之后文物改变却授权旧文件。联动租约在实际文物改变、展示退出、心跳失效或恢复时撤销；旧01手动播放不要求双板在线，但仍受应急覆盖。

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
- 已授权播放时：旧UART版音视频正常，副板仍控制主板，本地说明/应急不抢占；当前候选改为应急必须抢占，验收按第10节执行。
- 拔A：重锁后回当前本地页，不按KEY4重载；重插仍保持本地，需要重新点击播放。
- 网线重连后SW3同步；主板暂停/恢复、手动→自动等按原行为检查。
- 已验证bit字节不变；未提供的量化长测/冷启动记录不虚构。

历史入口、旧bit、构建数据库、日志、转储、仿真缓存和辅助工具已移动到rubbish而非删除。成功种子、所有AL依赖、包含文件、TEMAC配置/门级文件、EDID MIF、最终TF素材、回归源码保留。审查代码和完整手动构建不依赖rubbish。

本次发布整理归档：`D:\VSCode\CodeFiles\Git_TD\rubbish\副板发布整理_20261011_372f809`，仅移动旧85E5C239 bit和旧发布清单；移动清单及保留文件校验同目录保存。未改RTL、约束或构建流程，无需因整理重新烧录、改TF卡或替换播放器。

## 9. 电脑视频播放器界面与重建

双击 `tools/PCVideoPlayer/MuseumPCVideoPlayer.exe`，无终端窗口。此前2026-10-11的纯UI更新采用墨绿博物馆背景、米白设备/状态卡片和青铜播放图标，不改bit；当前版本沿用该风格，新增第2/10节的配置、联动及状态查询，不改变MBP1协议。

操作仍是：连接 USB-UART → 选择 AnlogicHDMI 扩展屏 → 选择本地视频 → 播放。未授权保持副板本地内容；暂停保留视频画面，停止等待副板撤销授权后回本地。电脑需使用原说明规定的 720p、音频格式及 Windows 媒体组件，UI 更新不增加编解码支持。

在工程根目录执行 `& .\tools\PCVideoPlayer\build.ps1`，使用 Windows 自带 .NET Framework 编译器，嵌入背景和图标，运行 `--self-test` 并更新 EXE 校验文件，无新增 UI 框架。复核命令：

```powershell
Start-Process .\tools\PCVideoPlayer\MuseumPCVideoPlayer.exe -ArgumentList '--self-test' -Wait -PassThru
Start-Process .\tools\PCVideoPlayer\MuseumPCVideoPlayer.exe -ArgumentList '--ui-test',"$PWD\_build_player_preview.png" -Wait -PassThru
# 仅本机解码测试，不发送串口命令；视频应含音轨、短于10秒。
Start-Process .\tools\PCVideoPlayer\MuseumPCVideoPlayer.exe -ArgumentList '--media-test','C:\路径\短视频.mp4' -Wait -PassThru
```

退出码 0 为通过。`--self-test`还检查配置XML保存/恢复、坏格式拒绝、未配置视频不反复重试、文物互不阻塞、应急再确认和过期状态处理；不连接真实串口。界面截图与解码测试不代替实板USB/HDMI验收。单纯UI更新曾不需要烧录；本轮自动联动必须使用新候选副板bit，主板和TF素材不换。

## 10. 当前联动候选的资源与上板检查

本轮提速版已完成原种子7的综合、布局布线、hold修复、STA/DRC与bitgen。LUT 11377/19600（58.05%）、FF 7295/19600（37.22%）、Slice 6430/9800（65.61%）；BRAM9K 21/64、BRAM32K 13/16、DSP 5/29、PLL 4/4、GCLK 10/16。相对此前联动候选，LUT +53、FF +5、Slice +40，BRAM/DSP/PLL不增加。setup +0.105ns、hold +0.021ns，TNS均0；未新增时序例外，原PHY7002/PHY5079提示仍披露。

`seed/linked_video_fast_switch`保留当前成功布线种子、最终报告、bitgen和回归日志；`seed/linked_video`、`seed/uart_video`原证据全部保留。当前代码重建产出提速联动版，不等同于旧已验收bit。`release/manifest_secondary_linked_video.json`的board_pass为false，等待用户验证，不把编译成功当成上板通过。

本轮UART新/旧参数分别通过10/8条PASS；集成HDMI10条、切源6条、按键/状态适配/MBP1会话/编码各1条、本地缓存策略1条，共39条PASS。本地缓存策略使用实际轮播控制器验证：首个讲解心跳不进入简介、视频覆盖期间不切轮播页、返回后继续轮播。集成仿真保留原四路共同延迟和数据岛样式，并检查应急抢占、解除不旧复和主板状态失联回退；媒体/网络仍用既有独立测试与集成stub，不宣称全系统电气或真实LPCM/BCH证明。

上板依次检查：

1. 关闭旧播放器，烧新候选副板bit；A无源时确认原轮播、说明SW4、四键/SW3及双板重连功能。
2. 先不勾联动，确认原手动播放、暂停、停止、有声视频和拔HDMI回退。
3. 配置五个任意位置的MP4，退出再开软件确认路径和串口选择恢复；启动不自播，勾联动后总览/预载也不自播。
4. 五件文物分别等待播放器“首帧已准备”，KEY2进入后直接切到对应静音视频，不等待主屏入场结束，不先显示本地简介；KEY2暂停/继续随主板，讲解中预载其他文物不跳片。退出后从保留轮播页继续，不重新读简介/轮播图片。
5. 主板退出及KEY4恢复回本地；SW4应急在视频中仍抢占。解除后旧片不恢复，下一次从总览进入或显式重新开启联动才播放。
6. 分别拔串口、HDMI、双板网线验证回退，重连再确认；应急时拔网线保持已知应急，不把普通失联当火警。
7. 软件停止后移动/删除一个映射视频，再进入该文物看到缺失提示、本地仍正常；其他文物仍可播放，重新配置后该文物恢复。实测切换/恢复延迟，不承诺零黑屏。

`theme` 是必要重建素材，运行不依赖外部图片。内置 imagegen 与主板软件统一设计：暗墨绿博物馆、右侧青铜暖光、无文字背景；透明外缘、墨绿圆角底、象牙白门廊与青铜播放三角图标。ICO 含 16～256 像素尺寸，不使用字体图标或额外依赖。

### 窗口适配与联动提速边界

控制窗口及视频配置窗口使用WPF原生Viewbox按可用宽高等比例缩放，文字、图标、按钮、输入框随窗口一起变化。已渲染检查860×610、940×750、1880×1500布局；不改变真正送往AnlogicHDMI的全屏视频尺寸。实机跨屏DPI切换仍需用户确认。

新版播放器SHA256：`CA62E70372F9D0961DE09491B3C400AA27F31AB5DF684ECE47FF32DD30A8C825`。程序先准备当前高亮文物，再发首帧提示，不提前输出电脑桌面；五个文件无须同时解码。已取消等主屏转场结束的等待，并缩短轮询及授权确认后的软件等待。副板在有首帧提示的讲解期间不读简介、保留原轮播页，消除这条TF重读造成的延迟。

未改时钟切换器的安全静音或PLL频率。PC与本地的像素时钟不同，显示器切源仍可能重新锁定并短黑；本轮不把它谎称为已消除，也不把所有延迟归因于解码/传输。首帧未准备好时仍显示原本地内容，不抢先授权黑帧。验收时请分别观察“首帧已准备→KEY2→视频”及“退出→轮播”，若剩余黑屏来自显示器锁定，需要独立同频输出方案，不能通过继续减小安全等待解决。

构建数据库、仿真缓存及旧候选bit已移入`rubbish/双板界面与联动提速_20261011`，必要软件、重建源码、最新候选bit、已验收回退bit和所有成功种子保留。不改主板RTL、TF素材、两板控制分配或音画字幕时间轴。
