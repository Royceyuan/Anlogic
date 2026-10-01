# 双 FPGA 博物馆双屏展陈终端——主板工程交接

## 当前基线

- 唯一 TD 工程：`dual_fpga_museum_terminal_main_board.al`
- 顶层模块：`dual_fpga_museum_terminal_main_board`
- 器件：安路 `EG4S20BG256`
- 当前 bit：`release/dual_fpga_museum_terminal_main_board.bit`
- SHA-256：`14D503535CA033A01CE2F5AC5805E97FD7E3A994D0A3E8866D67419D75076A14`
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
- 当前版本验证：`docs/reports/manual_browse_main_board_20261001.md`（新手动模式待副板适配后板测）
- 资源/时序/DRC：`docs/reports/museum_main_board_*.rpt`

最终时序为 setup `+0.008 ns`、hold `+0.021 ns`，TNS均为0，STA覆盖99.68%。setup余量较小，不用时序闭合替代新版本板测。SDRAM相移时钟单负载使用本地时钟资源仍保留工具警告；未更改该媒体路径或放宽约束。

## 主副板联调

- 通信协议与副板实现要求：`docs/副板实施与双板通信协议.md`
- 双板控制分配与联调步骤：`docs/双板控制分配与以太网联调计划.md`
- PC 模拟副板操作：`docs/主板以太网控制与验收说明.md`

主板地址为 `192.168.10.1:5000`，电脑/副板对端使用 `192.168.10.2:5000`。协议为固定地址 UDP 上承载 MBP1；副板必须按协议序号、CRC、ACK 和主板状态字段实现，不能根据按键次数猜测主板状态。

## 本地交互与恢复

- KEY1：总览循环高亮；讲解画面 1×/2× 缩放，暂停期间同样可用。
- KEY2：确认进入讲解；讲解中暂停/继续。
- KEY3：总览控制 OSD 显示/隐藏；讲解状态控制音频可视化显示。
- KEY4：应用级恢复，清理讲解、字幕、转场和视口状态并回到有效总览。
- SW1～SW3：选择预载文物；讲解期间允许后台预载。
- SW4：应急模式。

KEY4 已修复 2× 讲解恢复时倍率与视口残留：恢复发布时会在帧边界同步归零显示端倍率、水平和垂直偏移。

## 媒体与验证边界

2026-10-01新增主板静音手动浏览：副板后续SW3通过MBP1 `0x17`控制正常/手动，`0x18`选择全貌或细节1～3，DISPLAY_STATUS字节6 bit2和播放状态5回报实际手动状态。手动时停音频、隐藏字幕及波形、保留当前四图缓存；退出回总览，再确认从头讲解。主板本地按键/拨码分配不变，副板工程本轮未改。完整接口与验收见 `docs/主板静音手动浏览与副板接口_20261001.md`。

当前电脑有线网卡故障，不以PC连接板卡作为本轮验收前提；离线仿真与loopback自检不依赖该网卡。新功能实板验收待副板适配后进行。已验证的a0a6832发布bit额外保存为 `_build_museum_main_board/museum_a0a6832_board_pass.bit`（SHA-256 `4C695F6CE48BD9826AD18A7A1A8E21EE4324630A89A2F4C05FFE7687F5B9DBF4`）。

- TF 素材格式、音画字幕时间轴和图片顺序未因本轮工程整理而改变。
- `release/media/OSDNAME.BIN` 为可替换的 OSD 名称媒体。
- 当前最新 bit 新增细节图2→3的64帧上下收拢/展开，边缘为纯黑，不叠加光带或亮线；中点如需等待读图就绪，图像区域保持黑底。其余图片顺序、转场、音画字幕时间轴和协议不变。
- 基线已等效优化应急颜色选择、菱形遮罩流水线、波形高度及行缓冲水平起点；本轮保持像素路径。新增手动控制后LUT85.86%、Slice97.16%，相对基线增加92 LUT、85 Slice；BRAM9K43、BRAM32K10、DSP13不变。布局仍拥挤，不能继续大幅扩功能而忽略时序。
- 当前最新 bit 由最终产品命名入口重新生成，离线仿真、综合、布局布线、STA、DRC 和 bitgen 均通过，待上板验收；上一版实板验收 bit 独立保留以便回退。
