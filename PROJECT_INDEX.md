# 双 FPGA 博物馆双屏展陈终端工程索引

## 主板产品入口

| 项目 | 文件或模块 |
|---|---|
| TD 工程 | `dual_fpga_museum_terminal_main_board.al` |
| 顶层模块 | `dual_fpga_museum_terminal_main_board` |
| 系统集成 | `src/top/museum_main_board_top.v` |
| 显示与媒体子系统 | `src/memory/museum_display_subsystem.v`、`museum_media_core.v` |
| 网络端点 | `src/ethernet/museum_network_endpoint.v` |
| 管脚约束 | `constraints/museum_main_board_pins.adc` |
| 时序约束 | `constraints/museum_main_board_timing.sdc` |
| 完整构建 | `scripts/build_museum_main_board.tcl` |
| bitgen | `scripts/build_museum_main_board_bitgen.tcl` |
| 当前发布 | `release/dual_fpga_museum_terminal_main_board.bit` |
| 已验收回退 | `release/dual_fpga_museum_terminal_main_board_last_verified.bit` |
| 当前验证摘要 | `docs/reports/manual_mode_controls_rearm_20261001.md` |

独立 MAIN-5A/5B 诊断工程、旧分辨率顶层、阶段包装器和历史构建脚本均不是最终产品入口，已移至 `D:\VSCode\CodeFiles\Git_TD\rubbish\Anlogic_历史源码与阶段入口_20260928`。

## 命名原则

- 文件名表示硬件职责，不使用 MAIN 阶段号或临时修复版本号。
- 只有确实固定分辨率或变换关系的模块保留尺寸，例如 `linebuf_scaler_960x540_to_1280x720.v`。
- 官方或第三方 `vendor` 文件保持原名，避免破坏 IP 和参考工程依赖。
- 历史名称只允许出现在验证记录中，不作为当前构建入口。
