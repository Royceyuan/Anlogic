# 主板构建与媒体脚本

构建脚本须从工程根目录运行（见HANDOFF命令）。使用相对文件参数，避免TD命令行对嵌套Tcl路径表达式解析为空；bitgen仍先检查setup/hold报告，不允许违例时生成发布bit。

- `build_museum_main_board.tcl`：完整综合、布局布线、STA、DRC 和数据库导出。
- `build_museum_main_board_bitgen.tcl`：复查 DRC/时序后生成最终产品 bit。
- `make_bmp_adaptive.ps1`：生成主板可读取的自适应 BMP 素材。
- 其余 `make_*` 脚本：生成当前媒体或视频测试素材，名称直接描述输出用途。

历史阶段构建脚本已移至仓库外 `rubbish`，不再作为当前工程入口。
