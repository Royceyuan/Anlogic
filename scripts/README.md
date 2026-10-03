# 主板构建与媒体脚本

构建脚本须从工程根目录运行（见HANDOFF命令）。使用相对文件参数，避免TD命令行对嵌套Tcl路径表达式解析为空；bitgen仍先检查setup/hold报告，不允许违例时生成发布bit。

- `build_museum_main_board.tcl`：完整综合、布局布线、STA、DRC 和数据库导出。
- `build_museum_main_board_bitgen.tcl`：复查 DRC/时序后生成最终产品 bit。
- `build_flash_startup_repair.tcl` / `bitgen_flash_startup_repair.tcl`：撤回未通过板测的尺寸表/行命中优化，并加入系统与视频 PLL 锁定复位保护；输出到独立 `_build_flash_startup_repair` 和 `release/dual_fpga_museum_terminal_main_board_flash_startup_repair.bit`，不覆盖原验收 bit。启动保护测试：`sim/run_pll_startup.do`。
- `build_horizontal_interpolation_candidate.tcl` / `bitgen_horizontal_interpolation_candidate.tcl`：仅生成隔离的水平插值试验；当前整机时序未通过，不是可上板发布版本，详见缩放试验报告。
- `make_bmp_adaptive.ps1`：生成主板可读取的自适应 BMP 素材。
- `extract_pdf_text.py`：提取板级资料，供工程核查使用。
- 当前五组文物媒体统一打包入口：`tools/Package_tool/museum_media_packager.py`，说明见该目录 README。

历史阶段构建、临时单板诊断及早期视频测试脚本已移至仓库外 `rubbish`，归档清单见 `docs/工程残留整理_20261001.md`。正式构建与 bitgen 仍使用原脚本及当前数据库。
