# 双 FPGA 博物馆双屏展陈终端——主板工程交接

## 当前基线

- 唯一 TD 工程：`dual_fpga_museum_terminal_main_board.al`
- 顶层模块：`dual_fpga_museum_terminal_main_board`
- 器件：安路 `EG4S20BG256`
- 当前 bit：`release/dual_fpga_museum_terminal_main_board.bit`
- SHA-256：`4C695F6CE48BD9826AD18A7A1A8E21EE4324630A89A2F4C05FFE7687F5B9DBF4`
- 当前恢复基线：`a0a6832`，用户于2026-10-01重新上板确认图片及名称正常；发布bit为该提交原始二进制，不是重新布线生成的近似版本。
- 已验收回退 bit：`release/dual_fpga_museum_terminal_main_board_last_verified.bit`

当前产品入口集成 TF 图片/音频/字幕、总览与讲解流程、转场、自适应显示、OSD、画面参数、应急模式、应用恢复，以及主副板 UDP/MBP1 通信。旧阶段入口、诊断工程和历史报告已移入 `D:\VSCode\CodeFiles\Git_TD\rubbish`，不参与当前构建。

## 构建入口

```powershell
Get-Content scripts/build_museum_main_board.tcl | & D:\TD_6.2.1\bin\td_commands_prompt.exe
Get-Content scripts/build_museum_main_board_bitgen.tcl | & D:\TD_6.2.1\bin\td_commands_prompt.exe
```

- 管脚约束：`constraints/museum_main_board_pins.adc`
- 时序约束：`constraints/museum_main_board_timing.sdc`
- 产品入口验证：`docs/主板最终产品工程验证_20260928.md`（当时版本）
- BMP优化失败及撤回记录：`docs/reports/resource_optimization_20261001.md`
- 细节图2→3转场说明：`docs/reports/detail_light_band_transition_20260930.md`
- 资源/时序/DRC：`docs/reports/museum_main_board_*.rpt`

当前发布恢复 `a0a6832` 的配套面积、STA和DRC/bitgen报告：setup `+0.147 ns`、hold `+0.021 ns`，TNS均为0。本轮没有重新综合或布局布线；原始bit的SHA-256已与用户刚验证的文件核对一致。SDRAM相移时钟单负载使用本地时钟资源等原工具警告仍保留。

`925b855`的BMP头校验资源优化已撤回：其bit在实际TF卡上出现8008、图像黑屏、名称退回“文物0”，KEY4无效；此前模块仿真和STA通过不能代替板测。现有源码、约束、构建脚本及产品入口与 `a0a6832` 内容一致。失败的布局数据库及最终时序状态已移至忽略目录，不允许旧数据库再次生成发布bit；下一次改RTL必须从完整构建入口重新构建。

## 主副板联调

- 通信协议与副板实现要求：`docs/副板实施与双板通信协议.md`
- 双板控制分配与联调步骤：`docs/双板控制分配与以太网联调计划.md`
- PC 模拟副板操作：`docs/主板以太网控制与验收说明.md`

主板地址为 `192.168.10.1:5000`，电脑/副板对端使用 `192.168.10.2:5000`。协议为固定地址 UDP 上承载 MBP1；副板必须按协议序号、CRC、ACK 和主板状态字段实现，不能根据按键次数猜测主板状态。

## 本地交互与恢复

- KEY1：讲解画面 1×/2× 缩放；暂停期间同样可用。
- KEY2：确认进入讲解；讲解中暂停/继续。
- KEY3：总览循环高亮；讲解状态控制音频可视化显示。
- KEY4：应用级恢复，清理讲解、字幕、转场和视口状态并回到有效总览。
- SW1～SW3：选择预载文物；讲解期间允许后台预载。
- SW4：应急模式。

KEY4 已修复 2× 讲解恢复时倍率与视口残留：恢复发布时会在帧边界同步归零显示端倍率、水平和垂直偏移。

## 媒体与验证边界

- TF 素材格式、音画字幕时间轴和图片顺序未因本轮工程整理而改变。
- `release/media/OSDNAME.BIN` 为可替换的 OSD 名称媒体。
- 当前最新 bit 新增细节图2→3的64帧上下收拢/展开，边缘为纯黑，不叠加光带或亮线；中点如需等待读图就绪，图像区域保持黑底。其余图片顺序、转场、音画字幕时间轴和协议不变。
- 保留原有应急颜色、菱形遮罩、波形及行缓冲优化；BMP固定格式字段恢复原有完整值存储和校验。当前LUT 16737/19600（85.39%）、Slice 9437/9800（96.30%）、寄存器11371/19600，BRAM9K 43/64、BRAM32K 10/16、DSP 13/29；不保留导致板测回退的45 LUT节省。
- 发布bit与用户刚确认正常的 `a0a6832` bit完全一致，TF媒体及副板协议不变；源码回归结果及验证边界见撤回记录。独立旧验收回退bit保持不变。
