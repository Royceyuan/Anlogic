# 双 FPGA 博物馆双屏展陈终端——主板工程

本目录是“**双 FPGA 博物馆双屏展陈终端**”的主板 FPGA 工程。

## 唯一工程入口

- TD 工程：`dual_fpga_museum_terminal_main_board.al`
- 顶层模块：`dual_fpga_museum_terminal_main_board`
- 管脚约束：`constraints/museum_main_board_pins.adc`
- 时序约束：`constraints/museum_main_board_timing.sdc`
- 目标器件：安路 `EG4S20BG256`

该入口集成博物馆图片展示、TF 媒体预载、音频与字幕、OSD、画面参数、应急模式以及主副板 UDP/MBP1 通信。历史阶段工程和分辨率试验入口不属于当前产品工程，已移至仓库外的 `rubbish` 目录。

## 构建

在工程根目录执行：

```powershell
Get-Content scripts/build_museum_main_board.tcl | & D:\TD_6.2.1\bin\td_commands_prompt.exe
Get-Content scripts/build_museum_main_board_bitgen.tcl | & D:\TD_6.2.1\bin\td_commands_prompt.exe
```

发布文件：

- `release/dual_fpga_museum_terminal_main_board.bit`：当前最新主板 bit。
- `release/dual_fpga_museum_terminal_main_board.bit.sha256`：当前 bit 校验值。
- `release/dual_fpga_museum_terminal_main_board_last_verified.bit`：上一版实板验收回退 bit。
- `release/media/OSDNAME.BIN`：TF 卡 OSD 名称媒体。

最终资源、时序和 DRC 报告位于 `docs/reports/museum_main_board_*.rpt`，验证摘要见 `docs/主板最终产品工程验证_20260928.md`。

操作、协议和板测记录以 `HANDOFF.md` 及 `docs/副板实施与双板通信协议.md` 为准。
