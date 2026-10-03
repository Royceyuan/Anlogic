# 双 FPGA 博物馆双屏展陈终端——主板工程交接

## Flash启动修复（2026-10-03，待上板）

用户反馈尺寸表资源候选写入Flash后概率黑屏/8008、名称缺失，KEY4不恢复，因此该候选不通过。已撤回尺寸表分布式RAM和行命中OR优化，恢复已验收数据通路；另修复可复现的启动隐患：系统PLL与1280视频PLL导出extlock，内存/读取控制复位等待系统锁定，视频/FIFO复位等待视频锁定及SDRAM初始化，仍由原reset_sync同步释放。新增 `sim/run_pll_startup.do` 在修复前复现90ns提前释放，修复后延迟/重新锁定及晚锁定场景通过。该隐患与本次真实板故障的因果关系仍需Flash冷启动验收，不能用模型宣称概率故障彻底消除。

新构建/bit路径为 `_build_flash_startup_repair` / `release/dual_fpga_museum_terminal_main_board_flash_startup_repair.bit`，SHA256 `4409952619964B9FB2D138E2D3FB9006DB005E53278404412D8A7F92AB876BE5`；复用原产品约束和固定seed1，完成STA/DRC/bitgen：setup +0.107ns、hold +0.023ns，TNS=0，LUT16960、FF11427、Slice9540（97.35%），BRAM/DSP/PLL不增。17正常回归入口27项PASS，另有PLL启动4轮场景通过。完整结果/Flash冷启动验收见 `docs/reports/flash_startup_repair_20261003.md`。旧已验收主板7EE6C57A和副板B36B3D6E不覆盖，副板及TF无需修改；该修复候选仍待实板确认。

## 已撤回资源候选（2026-10-03，实板未通过）

源图片尺寸表改用异步读分布式 RAM，行缓存命中存在性改为并行译码，保留原槽位优先级；不调整控制、协议、素材和音画时间轴。固定 seed 1、原时钟及约束完成整机综合、布线、STA/DRC 和 bitgen：LUT 16691、FF 11120、Slice 9321（95.11%），相对已验收纵坐标版减少 390 LUT / 325 FF / 165 Slice，BRAM/DSP/PLL 不增。setup +0.016 ns / hold +0.024 ns，TNS=0，覆盖率99.80%；setup余量薄，不能代替实板验收。

该候选 `release/dual_fpga_museum_terminal_main_board_dimensions_candidate.bit`（SHA256 `01C1721A28CC876D5F2221D126E2A848567A84D83FCFB0129177BFF5E5392FDA`）仅保留作诊断，不能再作为发布版烧录。已验收主板 `7EE6C57A...` 和副板 `B36B3D6E...` 未覆盖；当前生产源码为上述启动修复，不再是尺寸表资源候选。历史回归和资源见 `docs/reports/source_dimensions_single_hotspot_20261003.md`；已删除失效的候选专用测试/构建入口，仍可由提交c955aa6恢复。

## 当前双板上板验收记录（2026-10-02）

后续视口请求合并试验也未合入：19个正常入口26项检查PASS，但固定seed1最终Slice9655（+169），setup -1.540ns。主板生产文件已逐字节恢复，副板未改、无新bit；当前资源仍为已验收的9486 Slice。对照测试、撤回与原始数据见 `docs/reports/viewport_request_single_hotspot_20261002.md`。上一流水线时序起点的综合网表网络实际是transition_mode[2]，不能根据实例名直接归因为Y坐标计算。

本日画面参数流水线试验最终减少14个Slice（9486→9472），但setup WNS -0.325ns、3个失败端点，已完整撤回生产RTL，不生成bit。原已验收bit与用户两处已有修改均保持不变。新增逐周期对照及常规回归通过；数据和失败路径见 `docs/reports/picture_pipeline_single_hotspot_20261002.md`。当前资源仍按9486 Slice计，后续优先考察平移/转场共享控制链。

用户后续确认网线重连后的SW3问题已解决，并确认副板双栏说明页正常。主板此前纵坐标候选的其余短流程均已通过；当前已验收组合为主板纵坐标候选 `7EE6C57A...` 与副板双栏说明页 `B36B3D6E...`。下方首轮SW3故障反馈作为历史记录保留，不再表示当前待修问题。正式主板bit `36D9BB7C...` 仍保留，不自动覆盖或混淆两份报告。

两板当前363/173个已跟踪实文件（含主板两处已有未提交修改）及完整Git bundle已复制到仓库外 `D:\VSCode\CodeFiles\Git_TD\工程回溯\双板已验收_20261002_aa6292d_7efd48c`，逐文件SHA256及bundle verify均通过。新资源试验只能另存候选，不覆盖该回溯点。

本日OSD名称地址单热点的两种写法均通过四组行为/官方BRAM等价检查及常规回归，但固定seed1最终Slice分别9558、9550，高于9486基线。两种候选均撤回，生产RTL及现有bit不变，未生成新bit。详细数据、撤回原因及复现见 `docs/reports/osd_name_address_single_hotspot_20261002.md`；不以综合LUT下降冒充可交付优化。

## 纵坐标候选首轮记录（2026-10-02）

源码增加纵坐标单热点优化，仅在现有读帧启动边界锁存倍率选定的纵向起点；无新增像素延迟，控制、协议及素材不变。固定种子 1 最终 LUT 17081、Slice 9486（96.80%），setup +0.187 ns / hold +0.023 ns，TNS 为 0；15 个回归入口共 21 项 PASS，实板通过范围与待查问题见下段。独立候选 `release/dual_fpga_museum_terminal_main_board_y_origin_candidate.bit`，SHA256 开头 `7EE6C57A`。正式已验收 bit 与副板仍保留不变；资源明细、复现和短流程验收见 `docs/reports/y_origin_single_hotspot_20261002.md`。候选资源报告单独命名，不覆盖下面正式基线报告。

本日用户板测：启动五栏/名称、自动讲解倍率/暂停/平移、暂停2×后的KEY4居中恢复、手动切图及切回自动后连续两次字幕、SW4应急及退出均通过；网线重连后状态及普通四键正常，只有副板SW3未同步。尚不记整体验收通过。本地副板文件仍为SHA256 `41B81E03`；用户使用“仅Flash”烧录，待确认双板冷启动后的运行配置与重连结果。现有实际双端点拔插回归通过，额外同boot_id副板重启试验不等于本次拔插场景，握手试验已撤回，没有放宽去重或更换bit。

## 当前基线

2026-10-01正式产品已接入双板静音手动浏览：副板SW3选择自动/手动，四键在两种模式均保留原画面控制。主板手动KEY3循环四图、KEY2退出保留图片缓存；手动→自动只重启音频/字幕会话。双板操作见`docs/主板静音手动浏览与副板接口_20261001.md`。独立单板诊断入口的101/110拨码仅用于旧诊断bit，不是正式产品控制；本轮没有修改TF媒体。

- 唯一 TD 工程：`dual_fpga_museum_terminal_main_board.al`
- 顶层模块：`dual_fpga_museum_terminal_main_board`
- 器件：安路 `EG4S20BG256`
- 当前 bit：`release/dual_fpga_museum_terminal_main_board.bit`
- SHA-256：`36D9BB7C74E23C047BEC15A5E128A8540852B8C4B7ECD11F504E25CDB107A6EC`
- 已验收回退 bit：`release/dual_fpga_museum_terminal_main_board_last_verified.bit`

当前产品入口集成 TF 图片/音频/字幕、总览与讲解流程、转场、自适应显示、OSD、画面参数、应急模式、应用恢复，以及主副板 UDP/MBP1 通信。旧阶段入口、诊断工程和历史报告已移入 `D:\VSCode\CodeFiles\Git_TD\rubbish`，不参与当前构建。

## 构建入口

2026-10-02：双板已建立仓库外离线回溯点（实文件快照及已校验 Git bundle）。波形单热点候选完成等效检查及布局对照，但未获得 Slice 收益，已撤回生产 RTL；正式 bit 不变。新增验证与具体结果见 `docs/reports/waveform_single_hotspot_20261002.md`，不把未合入候选作为当前资源数字。

继续对照的应急区域 ROM 候选有 LUT/Slice 收益，但三个布局对照均未同时闭合 setup/hold；已撤回生产 RTL，未生成新 bit。结果见 `docs/reports/emergency_region_single_hotspot_20261002.md`。本轮提交仅含回溯说明、评估记录和更严格的回归检查，现有正式资源报告及双板 bit 仍为已验收基线。

```powershell
Get-Content scripts/build_museum_main_board.tcl | & D:\TD_6.2.1\bin\td_commands_prompt.exe
Get-Content scripts/build_museum_main_board_bitgen.tcl | & D:\TD_6.2.1\bin\td_commands_prompt.exe
```

- 管脚约束：`constraints/museum_main_board_pins.adc`
- 时序约束：`constraints/museum_main_board_timing.sdc`
- 当前版本验证：`docs/reports/manual_mode_controls_rearm_20261001.md`（双板手动控制及轻量恢复，用户已反馈可用）
- 工程整理记录：`docs/工程残留整理_20261001.md`
- 资源/时序/DRC：`docs/reports/museum_main_board_*.rpt`

最终时序为 setup `+0.075 ns`、hold `+0.024 ns`，TNS均为0，STA覆盖99.66%。setup余量及Slice余量仍较小，不用时序闭合替代新版本板测。SDRAM相移时钟单负载使用本地时钟资源仍保留工具警告；未更改该媒体路径或放宽约束。

## 主副板联调

2026-10-01：用户已确认双板手动展示及副板网线重连修复正常，并已要求推送对应分支。重连修复仅修改副板能力缓存失效策略，主板源码/bit不变；副板bit的SHA256开头为41B81E03，步骤见 `Anlogic2/docs/网线重连模式恢复_20261001.md`。应急期间副屏保持逃生图但没有失联提示，用户要求暂缓该提示，未记为通过。

- 通信协议与副板实现要求：`docs/副板实施与双板通信协议.md`
- 双板控制分配与联调步骤：`docs/双板控制分配与以太网联调计划.md`
- PC 模拟副板操作：`docs/主板以太网控制与验收说明.md`

主板地址为 `192.168.10.1:5000`，电脑/副板对端使用 `192.168.10.2:5000`。协议为固定地址 UDP 上承载 MBP1；副板必须按协议序号、CRC、ACK 和主板状态字段实现，不能根据按键次数猜测主板状态。

## 本地交互与恢复

- KEY1：总览循环高亮；讲解画面 1×/2× 缩放，暂停期间同样可用。
- KEY2：总览确认进入；自动讲解中暂停/继续；手动展示中退出回总览，不触发完整复位。
- KEY3：总览控制 OSD 显示/隐藏；自动讲解控制音频可视化显示；手动展示循环全貌→细节1→细节2→细节3→全貌。
- KEY4：应用级恢复，清理讲解、字幕、转场和视口状态并回到有效总览。
- SW1～SW3：选择预载文物；讲解期间允许后台预载。
- SW4：应急模式。

KEY4 已修复 2× 讲解恢复时倍率与视口残留：恢复发布时会在帧边界同步归零显示端倍率、水平和垂直偏移。

## 媒体与验证边界

副板SW3通过MBP1 `0x17`控制正常/手动，DISPLAY_STATUS字节6 bit2和播放状态5回报实际手动状态。OSD在ZOOM上方显示实际“自动/手动”。手动时停音频、隐藏字幕及波形、保留当前四图缓存；主板KEY2退出仍保持手动模式，可再次确认进入。SW3切回自动时先回全貌、收拢总览，等待旧SD扇区完成后只重启音频和字幕；保留图片、名称、SD初始化和有效FAT32几何参数。副板四键在两种模式均为原预设/参数/平移分组，不调用兼容保留的`0x18`选图接口。完整接口与验收见 `docs/主板静音手动浏览与副板接口_20261001.md`。

当前电脑有线网卡故障，不以PC连接板卡作为验收前提；离线仿真与loopback自检不依赖该网卡。用户已反馈本次双板版本可用。a0a6832额外备份及旧单板诊断版已移入仓库外 rubbish，本地恢复位置见工程整理记录；`release` 内保留当前正式 bit 和一份已验收回退 bit。

- TF 素材格式、音画字幕时间轴和图片顺序未因本轮工程整理而改变。
- `release/media/OSDNAME.BIN` 为可替换的 OSD 名称媒体。
- 当前最新 bit 新增细节图2→3的64帧上下收拢/展开，边缘为纯黑，不叠加光带或亮线；中点如需等待读图就绪，图像区域保持黑底。其余图片顺序、转场、音画字幕时间轴和协议不变。
- 为闭合时序，将现有应急像素流水边界移至几何判定之后、调色之前，线性转场比较移至已有第二级；合并行缓冲横向起点，避免每像素串联两次起点加法。总像素延迟不变，像素/同步等效仿真通过。HDMI四路原有两级局部复位使用TD preserve保留，避免跨通道合并造成375MHz长复位网；复位释放及串行码流等效检查通过。资源与时序以本轮报告为准，不能用历史数字代替当前构建。
- 当前最新 bit 由最终产品命名入口重新生成，离线仿真、综合、布局布线、STA、DRC 和 bitgen 均通过，用户已反馈双板可用；上一版实板验收 bit 独立保留以便回退。此次归档未修改位流、RTL或约束。
