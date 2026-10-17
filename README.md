# 双 FPGA 博物馆双屏展陈终端：主板最终工程介绍

本目录 `Anlogic` 是主板工程，`../Anlogic2` 是副板工程。目标器件为安路HX4S20板载 `EG4S20BG256`，使用TD 6.2.1。本文件是主板唯一工程说明；历史阶段文档、交接、试验报告和中间产物已移入工程外rubbish。

## 工程入口与当前位流

### 回退记录（2026-10-17）

按用户要求，撤回后续`preload_switch_fix`候选，恢复此前确认通过的倍速bit（SHA-256 `CB1A72BBA4A9B8FBCE50BC492B30A8E8DEB84F139347C84C1A5DC1327E2C3C48`）及对应RTL。撤销音频读者的空闲换轨重启修改，并撤下相关候选构建脚本及专项测试改动；副板与播放器保持此前已验收倍速版。

实板反馈：手动模式返回五栏总览后拨码仍可能无法预载，改自动也不能恢复，需KEY4；随后用户报告CONFIG重配置后自动讲解无音频和字幕。前次单模块满FIFO仿真通过不足以证明已定位实板根因，现撤回该修复结论。回退本身不是这些问题已解决的证明；本轮不继续修复或生成新bit。

撤回的bit（SHA-256开头`48A91691`）、脚本及诊断草稿可从工程外`rubbish/withdrawn_preload_switch_fix_20261017`恢复；原始时序/仿真证据继续保留在`seed/preload_switch_fix`，状态为已撤回，不是当前发布依据。请将下方倍速bit重新烧入Flash并断电重启；仅按CONFIG仍会重新加载板上Flash原有内容，不会读取电脑上回退的文件。

### 当前发布：FPGA内1×/2×/3×同步倍速（2026-10-17 上板通过）

当前源码将自动讲解中的KEY3改为1×→2×→3×→1×，暂停期间也可切速；总览KEY3仍控制OSD，手动KEY3仍切图。左上角`SPD1x/2x/3x`表示播放速度，`ZOOM1x/2x`仍表示图像缩放。自动讲解波形保持显示，暂停时隐藏归零。每次退出、恢复、应急或进入手动后回到1×。

HDMI仍输出48kHz；每个输出周期按倍速消费1/2/3个源PCM帧，音高相应升高。切速不重读WAV、不清FIFO、不从头播放。字幕和图片切点继续使用实际消费的源帧位置，字幕渐变与转场同步加快并保持暂停冻结，结束后的约1.2秒停留保留。轮播时长配置方式为：素材软件设置四个切图句形成源时间轴；运行时KEY3选择其1倍、1/2或1/3墙钟时长。暂停时间不计入推进时间；不是给每张图片另设独立秒数。

本轮先约分PCM/应急采样相位并收窄已知计数范围，再接入倍速；颜色偏移提前合并到既有流水级，视口读区与行匹配作等价简化。仿真覆盖原48k逐拍对照、3×源帧计数和50MHz跨时钟、暂停切速、字幕淡变、全部转场边界、颜色逐拍输出、完整视口流和既有恢复流程。

当前bit：`release/dual_fpga_museum_terminal_main_board_playback_speed.bit`，SHA-256 `CB1A72BBA4A9B8FBCE50BC492B30A8E8DEB84F139347C84C1A5DC1327E2C3C48`。seed=4，setup +0.095ns、hold +0.024ns、TNS均0，DRC和bitgen通过；LUT16970、FF11440、Slice9533/9800、BRAM9K43、BRAM32K10、DSP13、PLL4。相较已验收基线，新增倍速后的Slice少59，LUT多68，FF多5，BRAM/DSP/PLL不变；不将其描述为所有资源均减少或已获得大量布局余量。报告、源码校验清单和回归结果保留在`seed/playback_speed`，构建脚本为`scripts/build_playback_speed.tcl`和`scripts/bitgen_playback_speed.tcl`。用户确认“通过，整理，commit并push”，本轮记录为**上板通过**；不据此声称未经执行的长期或穷举硬件测试通过。旧`startup_read_fix`位流及清单移入工程外`rubbish/playback_speed_board_pass_20261017/main`，成功种子仍保留。

后续回归操作：配套烧录两板`playback_speed`发布版；第一件自动讲解中按KEY3切1×/2×/3×，确认声音、字幕和切图共同加快，暂停切速/缩放/平移后继续；KEY4恢复应为1×播放速度、1×缩放和居中总览；第五件手动KEY3循环四张640×480图，再切回自动连续讲解两次确认字幕；最后检查SW4应急与退出、重连后的SW3同步。启用新播放器联动时，PC状态与视频应跟随倍速和暂停。真实听感、3×读卡余量、实屏转场和联动延迟仍以上板结果为准。

TF专项演示：第五件`IMAGE4.BMP`、`ART4D1.BMP`～`ART4D3.BMP`已换为640×480、24-bit、BI_RGB图片，无内嵌黑边；第一件多分辨率素材保持原状。原图、生成提示和校验记录在工程外`../记录文档/长信宫灯640x480_20261017`。素材替换无需重烧bit。

### 历史基线：读突发收尾修复（2026-10-17 上板通过，位流已归档）

- 当时发布 bit：`dual_fpga_museum_terminal_main_board_startup_read_fix.bit`，SHA256 `BE70117B90A6E707EABD6A53FAB6D9CEE6E056460CB6ECC1F6D5149AE10530E2`。仍从 HDMIB 输出。用户于2026-10-17确认“ok没问题”；现已移入工程外 rubbish，历史成功种子与报告保留。
- 用户反馈：偶发冷启动 `60b6`，有 HDMI 信号且 OSD 可见，最近暂未再次复现，KEY4 是否能恢复未知。代码中该读数表示加载状态 6、行号低四位 B、帧尚未完成，并不是独立故障编号；不能仅凭它断言 TF 卡、PLL 或 HDMI 损坏。
- 已复现缺陷：`vendor/anlogic_lab6/frame_fifo_read.v` 只按“已收到长度减一”判断突发结束，最后一个数据延迟时会提前撤销读占用。现在增加最终返回有效条件，完整收齐后才释放仲裁。不改图片加载状态机、SD 时钟、音画时间轴、缓存布局或 KEY4 流程。
- `sim/run_frame_fifo_read_completion.do` 对旧条件复现失败，修复后完整/尾部短突发、最后返回延迟和正常连续返回均通过；原 PLL 启动、SD 退出隔离、1920×1080/1672×941/640×480 自适应读取测试通过。新 bit 已获用户上板认可，但不将此等同于证明 `60b6` 的唯一根因或长期零故障。
- seed=4；setup +0.254ns、hold +0.022ns、TNS 均为 0。LUT 16902、FF 11435、Slice 9592、BRAM9K 43、BRAM32K 10、DSP 13、PLL 4。构建/DRC/bitgen/测试证据保留在 `seed/startup_read_fix`；原 `seed/hdmi_b` 不变。既有时钟/硬核位置警告保留，无新增时序豁免。
- 验收：先烧录主板新 bit，断电重启数次，确认五栏、名称和预载正常；再验证自动讲解及字幕、暂停缩放/平移、KEY4、手动→自动和应急。若再次停住，记录数码管是否一直不变、OSD 是否有具体名称，以及 KEY4 能否恢复。副板启动 SW3 自动同步需配合副板 `startup_sync` 新 bit；无需改 TF 素材或播放器。

release 只保留当前回退到的已验收倍速bit、校验/清单及必要媒体。工程入口、源码/IP、约束、构建脚本、回归源码、成功种子、完整素材打包软件及必要媒体均保留。旧位流、构建数据库、ModelSim 工作库和重复日志移入工程外 rubbish，重编时自动生成构建产物。

| 项目 | 路径 |
|---|---|
| 唯一TD入口 | `dual_fpga_museum_terminal_main_board.al` |
| 顶层模块 | `dual_fpga_museum_terminal_main_board`，定义于 `src/top/museum_main_board_top.v` |
| 系统集成 | `src/top/museum_main_board_top.v` |
| 管脚约束 | `constraints/museum_main_board_pins.adc` |
| 时序约束 | `constraints/museum_main_board_timing.sdc` |
| 唯一当前已验收bit | `release/dual_fpga_museum_terminal_main_board_playback_speed.bit` |
| bit校验值与清单 | `release/dual_fpga_museum_terminal_main_board_playback_speed.bit.sha256`、`release/manifest_playback_speed.json` |
| 必要素材制作软件 | `tools/MuseumTFPackager/MuseumTFPackager.exe`，须保留整个同级运行目录 |
| 成功种子及最终报告 | 当前：`seed/playback_speed/`，种子4；历史：`seed/startup_read_fix/`、`seed/hdmi_b/`；旧A口：`seed/` |

此前HDMIB基线 SHA-256 为 `29351E9BCBB3420392381AF14B8D0ECF3EF3EFD50C3BE0EB6EB95EF2B342AACF`，已归档，不再作为当前下载入口。此次整理不改变新 bit 字节或TF卡。此前极低概率80C6仍是待观察项；用户原有未提交的自适应测试修改和行写入文件工作区状态完整保留，不夹带提交。

### 历史基线：HDMIB输出迁移（以下资源与哈希不是当前发布值）

2026-10-10按用户要求，将主板输出从HDMIA迁移至HDMIB。仅修改ADC中的六个物理管脚，顶层及媒体RTL不变：CLK=C3、D2=E1、D1=F1、D0=G5、DDC SCL=P2、SDA=R2。内部`hdmi1_*`仍是同一组逻辑信号名，不表示当前物理A口。

当前主屏HDMI线连接主板HDMIB；原HDMIA不再提供博物馆输出。TF卡、以太网接线和副板bit不变；所有按键、拨码、图片顺序、转场及音画字幕时间轴保持原逻辑。旧A口bit及校验值移入工程外rubbish，可从归档或Git历史回溯，不再混在当前release中。

B口bit SHA-256：`29351E9BCBB3420392381AF14B8D0ECF3EF3EFD50C3BE0EB6EB95EF2B342AACF`。以已提交基线`9a3e939`的独立源码副本构建，91个源码/IP文件与基线一致，未夹带工作区原有改动。完整综合、布局布线、DRC及bitgen完成；setup +0.146ns、hold +0.024ns，TNS均为0。6组功能回归合计13条PASS。B口的成功种子4与原始报告保存在`seed/hdmi_b`；构建先导出并重开gate检查点，再按种子4布局，与本次闭合流程一致，不依赖工程外缓存。

B口最终资源：LUT16969/19600、FF11448/19600、Slice9605/9800（98.01%）、BRAM9K43/64、BRAM32K10/16、DSP13/29、PLL4/4。原有SDRAM位置提示及一个SDRAM时钟局部布线提示仍保留，DRC无多驱动或异常时序路径。未改变SDC、时钟频率或PLL相位。仅迁移输出，不为原A口增加HDMI输入功能。

## 已实现功能

主屏HDMI展示五栏文物总览，按拨码预载图片、音频、字幕与名称；讲解中可以后台准备下一件素材。图片按照全貌、细节1、细节2、细节3、最终全貌展示，采用既定平滑转场，音频与TF字幕按时间轴推进。支持按比例自适应、1×/2×、暂停、视口平移、四档预设及亮度/对比度/饱和度/色温调节。

左上角OSD显示实际文物、图像阶段、源分辨率、自动/手动、倍率和实际画面参数；名称来自TF卡。字幕带描边，音频波形随PCM变化，总览及暂停不保留静止波形。静音手动浏览保留图片缓存；切回自动只恢复音频/字幕会话。KEY4提供应用级恢复，SW4控制应急抢占及退出。

主板通过以太网向副板上报实际状态，接收远程画面控制；副板展示本地文物信息、应急路线和操作说明。以太网不传图片、音频或字幕文件。

## 按键与拨码

下表对应当前已验收的倍速发布版。

| 主板按键 | 总览 | 自动讲解 | 静音手动看图 |
|---|---|---|---|
| KEY1 | 循环高亮文物0～4 | 循环1×/2× | 循环1×/2× |
| KEY2 | 确认进入当前模式 | 暂停/继续 | 退出总览，不重载图片 |
| KEY3 | 显示/隐藏OSD | 循环1×/2×/3×播放速度 | 循环全貌、细节1～3 |
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

打包软件是完整产品交付的必要配套工具，保留并随仓库提供于`tools/MuseumTFPackager`；虽不参与FPGA综合，也不能当作残留移走。双击其中的 `MuseumTFPackager.exe`，无需安装Python、不弹终端。选择五个文物文件夹的根目录，每件放全貌、细节1～3、WAV和SRT；必要时勾选本地字幕校准，在“设置切图句”指定四个阶段开始的字幕句，再生成素材包。试听后将输出 `TF_CARD` 内31文件写卡；名称位图自动生成。软件内置“使用说明”。

完整运行目录中的 `AlignmentWorker`、`models`、`ffmpeg`、DLL与许可证不可拆散，不能只留EXE。校准本机运行、保留原字幕文字，不保证每句绝对准确；检查输出提示并试听。软件源码、开发环境和重复ZIP已归档，修改软件时按清单恢复原路径。

从远程复现需要Git LFS，不能只下载缺少LFS对象的源码ZIP：安装Git及Git LFS，检出`Yan_Chen_Double`后在仓库执行`git lfs install`、`git lfs pull`。模型`models/small.pt`和EXE/DLL等必须是实际文件，不能是以`version https://git-lfs.github.com/spec/v1`开头的指针。软件完整性清单为`offline_bundle_manifest.json`，主程序SHA-256见`MuseumTFPackager.exe.sha256`。软件使用目标Windows电脑的微软雅黑，不分发Windows字体。

完整复现顺序：准备五组原始图片/WAV/SRT和名称 → 软件界面生成并检查TF素材 → 写入FAT32 TF卡 → 打开本目录唯一`.al`审核代码并按下节脚本完整编译 → 烧录主板bit → HDMIB接主屏、网线接已验证副板 → 检查五栏/名称、音画字幕、自动/手动、缩放暂停平移、应急及重连。软件程序、语音模型和DLL不要写入TF卡；现成bit可以直接验收，也保留完整FPGA源码用于重新生成。此交付包含软件可运行包，不把归档的打包软件开发环境宣称为本目录内可直接重编EXE的源码工程。

当前五件新女声源素材在 `../素材`，已用实际软件校准并写卡回读。图片顺序不变；第5、9、13、17句分别作为细节1～3及最终全貌切点。软件检查不替代真实音画/字幕上板验收。

## 双板网络接口

直连千兆以太网，固定IPv4/24、UDP/ARP；主板 `192.168.10.1:5000`、MAC `02:48:58:34:20:01`，副板 `192.168.10.2:5000`、MAC `02:48:58:34:20:02`。不支持IP分片、options或网络传媒体。固定UDP及MBP1位于 `src/ethernet`，TEMAC/RGMII/FIFO来自官方示例；不要删跨时钟FIFO或更改IP配置文件旁的综合网表。

MBP1版本1，20字节头、业务payload及2字节CRC，总长 `22+N`，多字节整数大端。魔数 `4D42`；CRC-16/CCITT-FALSE，poly=0x1021、init=0xFFFF、xorout=0、不反射，覆盖头与业务数据。消息包括HELLO(01)、心跳(02)、状态查询(03)、ACK(04)、播放状态(12)、预设(13)、四参数(14)、视口(15)、实际画面状态(16)、浏览模式(17)、浏览图片(18)、诊断(31)，十六进制编号。

副板主动握手、每500ms心跳；控制按实际状态发送绝对值，并等待匹配ACK及实际状态。忙/无效请求结束本次事务，不盲目重放旧增量。重连后重新取得新状态并同步SW3；同boot_id断线不能永久丢失已知能力。应急断线保持逃生图，重连新状态确认解除后恢复；当前应急页未显示失联提示，此项不是已完成的显示功能。完整字段定义以当前 `mbp1_codec.v`、两板endpoint和keys源码为准，历史详细协议已归档。

倍速扩展复用保留位，不改变MBP1版本、消息号或长度。主板HEARTBEAT的业务载荷整体位`[18:17]`、DISPLAY_STATUS整体位`[44:43]`均为速度索引：0=1×、1=2×、2=3×，3保留。其余字段位置不动，手动标志仍为DISPLAY_STATUS bit42。副板将速度带入PC串口快照的PHASE `[4:3]`，图片槽在`[2:0]`，总览仍为FF；配套播放器随该值设置视频速度。旧主板保留位为0，配新副板/软件仍按1×运行。要让新主板倍速同步到联动视频，需要两板当前bit和新播放器配套。

## 构建、时序与验证

手动全流程：


1. 用 `D:\TD_6.2.1\bin` 中的TD图形界面打开根目录唯一 `.al`，确认器件为 `EG4S20BG256`、顶层为 `dual_fpga_museum_terminal_main_board`。
2. 在工程文件树审核 `src/top/museum_main_board_top.v`，沿模块实例检查 `src/memory`、`src/video`、`src/audio`、`src/ethernet` 等源码；IP及约束同样必须保留。
3. 在PowerShell中按下列顺序手动启动完整综合/布局布线，再生成bit。正式构建使用脚本中的成功种子和修hold步骤；不要以GUI默认物理设计策略代替后宣称结果等价。

```powershell
Set-Location -LiteralPath D:\VSCode\CodeFiles\Git_TD\Anlogic
& D:\TD_6.2.1\bin\td_commands_prompt.exe scripts/build_playback_speed.tcl
# 确认上一步成功，检查 _build_playback_speed_v2/museum_main_board_final.ts
# setup/hold WNS非负，TNS均为0，再执行：
& D:\TD_6.2.1\bin\td_commands_prompt.exe scripts/bitgen_playback_speed.tcl
Get-FileHash -LiteralPath ./release/dual_fpga_museum_terminal_main_board_playback_speed.bit -Algorithm SHA256
```

4. 检查TD输出无ERROR，完整构建的DRC通过，bitgen明确输出 `Generate bits file`；确认新bit的文件时间和SHA256后再烧录。只看进程退出码或目录里有旧bit不能证明生成成功。自行修改后产生的新bit不自动继承当前发布bit的上板验收。

倍速构建包装器复用 `build_museum_main_board.tcl` 及`build_museum_main_board_bitgen.tcl`，这些Tcl均须保留。下次生成bit必须先执行第一条完整构建，再执行bitgen，脚本会重新建立构建目录。当前B口使用成功种子4，参数见`seed/playback_speed/seed_config.json`；历史启动修复、B口迁移和旧A口种子与报告保留用于回溯。这里只保存原始最终报告，不是可直接bitgen的数据库。种子不保证修改后的源码仍然闭合时序。

当前bit的资源/时序见上文倍速统计及`seed/playback_speed`原始报告，setup +0.095ns、hold +0.024ns，TNS=0。根级`seed/`保留旧A口的成功证据（setup +0.107ns、hold +0.023ns），不是当前bit的报告；其中旧bit路径是历史记录，不能作为当前构建依赖。

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
| `seed` | 当前B口种子4、旧A口成功种子1及原始证据全部保留 |
| `release` | 唯一已验收bit及校验值；`media/OSDNAME.BIN`作为名称媒体模板保留 |
| 原 `assets` | 单张历史图片源图不参与构建/仿真，已归档；实际TF素材由卡或独立打包软件提供 |
| `tools` | 完整素材打包软件、模型、校准运行组件及许可证是必要交付，保留并使用Git LFS上传；运行组件内的Python文件不是历史开发脚本，不拆除 |

工程里没有要求保留任何历史build数据库；重新编译自动生成build目录。回归测试源码不是中间产物，保留便于审核后验证修改。

所有移出内容位于 `D:\VSCode\CodeFiles\Git_TD\rubbish\双板软件与旧位流整理_20261003`；软件、仿真、构建和最终文档整理分别有CSV清单，记录原/目标路径、长度和SHA256。旧文档在 `finalization/Anlogic/docs`，旧工程介绍也留有备份。需要恢复时移动回清单中的原路径，勿覆盖当前文件。归档不随普通Git拉取提供；当前工程自身具备构建所需全部硬件依赖。

此前进一步审核及独立重建证据位于`rubbish/project_audit_20261003`。本次2026-10-10整理归档为`D:\VSCode\CodeFiles\Git_TD\rubbish\主板整理_20261010_1234c41`，最终仅移出旧A口bit及校验文件。软件曾暂移后已按用户要求完整恢复原路径，归档中有恢复记录；没有删除软件。核验当前工程依赖和发布bit不变；不因纯文件整理重复修改布局。主板工作区原有未提交源码改动不在本次整理提交中。

## 素材打包软件界面与重建

双击 `tools/MuseumTFPackager/MuseumTFPackager.exe`，无终端窗口。2026-10-11 更新仅涉及桌面界面：墨绿博物馆背景、米白操作卡片、生成按钮及专用 TF 图标；素材检查、转换、名称生成、切图句、字幕校准和错误处理保持原行为，不需要更换 FPGA bit 或 TF 素材。

必须整体保留此目录的 `AlignmentWorker`、`models`、`ffmpeg`、许可证和清单。新增三个 Python 源文件是当前 EXE 的必要重建源码，不是历史脚本；`verify.py` 是临时素材回归，不写 TF 卡。原音频/字幕时间轴不因 UI 更新改变，校准仍可能有低置信度句子，需按软件说明试听。

重建 GUI（在工程根目录；模型和校准组件直接使用随附版本，不重新下载）：

```powershell
py -3 -m venv _build_tools_venv
& .\_build_tools_venv\Scripts\python.exe -m pip install Pillow==12.3.0 PyInstaller==6.22.3
& .\tools\MuseumTFPackager\build.ps1 -Python "$PWD\_build_tools_venv\Scripts\python.exe"
& .\_build_tools_venv\Scripts\python.exe .\tools\MuseumTFPackager\verify.py
```

关闭正在运行的打包器后重建。构建先生成候选 EXE，再替换当前 EXE，更新 SHA256 和离线清单；临时构建输出可移入 rubbish。回归覆盖 GUI 切图句和后台生成、只读可滚动说明页、31 文件回读、自动切点、字幕格式与多种 WAV 转换；`--baseline 旧版.exe` 可追加逐文件对比，`--preview 路径.png` 可保存实际界面。

`theme` 保留重建所需 PNG/ICO，运行时嵌入 EXE。背景和图标使用内置 imagegen 生成：背景提示为暗墨绿博物馆、青铜暖光、右侧陈列器物、左中留白、无文字；图标提示为透明外缘的墨绿圆角底、象牙白博物馆门廊、青铜 TF 卡、无文字。ICO 含 16～256 像素尺寸；Pillow 仅作尺寸与 ICO 格式转换。

本轮已核验：31 个 TF 输出与原 EXE 逐文件 SHA256 一致；独立 EXE 在无外部 Python 的临时目录可检查/生成；多宽高比与超上限图片、SRT 编码、PCM8/24、float、ADPCM、mu-law WAV 回归通过。业务函数、GUI 回调、名称/字幕编码与原 EXE 的字节码及常量一致；清单内 2576 个文件逐一回读，模型、校准工作器、FFmpeg 和许可证字节不变。未重新训练模型或改变校准算法，也不将格式回归等同于语义同步验收。两板已验收 bit 校验值保持不变。

2026-10-11窗口适配修复：窗口放大/缩小时，标题、字体、按钮、表格行高和日志同步按可用宽高比例调整，不再只拉宽输入框。980×720、1120×780、1600×1100窗口回归通过；说明页和切图句弹窗随主窗口当前比例初始化。新EXE SHA256为`09406CF97C2B791DAC5CB8F48358708BF246F1D8C8E4608D4F16A1BCEC14C9C2`。原EXE与新EXE的31个TF输出逐文件一致，完整离线依赖不变；不修改主板RTL/bit、TF卡或音画时间轴。跨屏幕实际DPI切换需在用户设备上再确认。
