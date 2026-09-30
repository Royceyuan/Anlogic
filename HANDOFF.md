# 双 FPGA 博物馆双屏展陈终端——主板工程交接

## 当前基线

- 唯一 TD 工程：`dual_fpga_museum_terminal_main_board.al`
- 顶层模块：`dual_fpga_museum_terminal_main_board`
- 器件：安路 `EG4S20BG256`
- 当前 bit：`release/dual_fpga_museum_terminal_main_board.bit`
- SHA-256：`E90E89592A7E1756238D9CC8052E3713C2E67C4A76B8FBB8CEC28A095BE5B1B3`
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
- 当前版本验证：`docs/reports/resource_optimization_20261001.md`
- 细节图2→3转场说明：`docs/reports/detail_light_band_transition_20260930.md`
- 资源/时序/DRC：`docs/reports/museum_main_board_*.rpt`

最终时序为 setup `+0.028 ns`、hold `+0.022 ns`，TNS 均为 0。setup 裕量较小，当前 bit 仍需上板回归确认；不能仅凭资源下降认定稳定性已获实板验证。SDRAM 相移时钟单负载使用本地时钟资源是当前保留的工具警告；该路径已闭合，并沿用实板验证通过的媒体链。

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
- 保留原有应急颜色、菱形遮罩、波形及行缓冲优化；本轮仅将 BMP 固定格式字段的完整数值存储改为逐字节匹配标志，完整保留宽高、偏移、文件长度及非法输入校验。当前 LUT 85.16%、Slice 96.10%，比已推送的 `a0a6832` 减少45 LUT、100个寄存器和19 Slice；BRAM/DSP 不变，布局仍较拥挤。
- 当前最新 bit 由最终产品命名入口重新生成，离线仿真、综合、布局布线、STA、DRC 和 bitgen 均通过，待上板验收；上一版实板验收 bit 独立保留以便回退。
