# 纵坐标单热点优化：待上板候选

## 结论与边界

2026-10-02，固定种子 1 的综合、布局布线、setup/hold、DRC 检查及 bitgen 已完成。候选减少 30 LUT、59 Slice，setup 余量改善；收益较小，不代表全工程已达到最低资源。15 个回归入口共 21 项 PASS，仍需真实双板验收，不能用仿真代替板测。

正式已验收 bit 未覆盖：`release/dual_fpga_museum_terminal_main_board.bit`，SHA256 为 `36D9BB7C74E23C047BEC15A5E128A8540852B8C4B7ECD11F504E25CDB107A6EC`。副板源码、提交及 bit 不变。仓库外双板回溯点仍保留在 `D:\VSCode\CodeFiles\Git_TD\工程回溯\双板已验收_20261001_eb9c1aa_8919e86`。

## 唯一生产改动

`src/video/linebuf_scaler_960x540_to_1280x720.v` 复用横坐标已有做法：在 `source_start` 锁存 1×/2× 选定的纵向起点，逐像素只进行缩放值选择与一次起点加法。替换原纵向平移寄存器，不新增流水级，不改变 BRAM、FIFO、槽位、epoch、读帧握手及行释放逻辑。

原 16 位符号扩展加法最终截取 11 位，候选保留相同的 11 位回绕行为。穷举全部 1024 种编码起点、1024 种光栅 Y、两种倍率；包含负平移、越界、消隐，以及启动后拨动原始控制输入，不能用“合法视口范围”假设删除保护。源图高度边界与负坐标裁剪原样保留。

未修改音画字幕时间轴、素材、按键、MBP1 格式、以太网、时钟频率、约束或 PLL。没有引入此前撤回的波形/应急区域候选。

## 同配置资源与时序对照

工具 TD 6.2.168116，器件 EG4S20BG256。固定种子 1、high 布局/门级打包、routability 布线、一次 `fix_hold`，与原构建脚本一致；没有扫描种子。

| 指标 | 已验收基线 | 本候选 | 差异 |
|---|---:|---:|---:|
| 综合 LUT | 16811 | 16801 | -10 |
| 综合寄存器 | 11379 | 11381 | +2 |
| 最终 LUT | 17111 / 19600，87.30% | 17081 / 19600，87.15% | -30 |
| 最终寄存器 | 11435 | 11445 | +10 |
| 最终 Slice | 9545 / 9800，97.40% | 9486 / 9800，96.80% | -59 |
| BRAM9K | 43 / 64 | 43 / 64 | 0 |
| BRAM32K | 10 / 16 | 10 / 16 | 0 |
| DSP | 13 / 29 | 13 / 29 | 0 |
| PLL | 4 / 4 | 4 / 4 | 0 |
| Setup WNS | +0.075 ns | +0.187 ns | +0.112 ns |
| Hold WNS | +0.024 ns | +0.023 ns | -0.001 ns |
| Setup / Hold TNS | 0 / 0 | 0 / 0 | 无违例 |
| STA 覆盖 | 99.66% | 99.66% | 0 |

全设计综合 LUT 的差异不等同于行缓冲模块本身的收益：该层次普通 LUT+ripple 从 296+104 变为 303+101，寄存器从 143 变为 145。采用依据是最终实际 Slice 收益与同时闭合的 setup/hold，而不是声称这一表达式必然节省某个固定数量的逻辑单元。

原最紧路径为光栅 Y→行缓存命中。候选全局最紧路径移为转场进度→显示 X，仍只有 0.187 ns 余量；Slice 仍高，不能把此结果表述为资源富裕。DRC 无多驱动或异常时序路径，保留基线同类 SDRAM 单负载本地时钟、PLL 反馈和旧时钟派生命令警告，没有放宽约束或隐藏警告。

原正式资源报告保持不变。本候选的原始报告为同目录 `y_origin_candidate_20261002_gate_area.rpt`、`_area.rpt`、`_qor.rpt`、`_timing.rpt`、`_drc_bitgen.rpt`。

## 回归与复现

从工程 `sim` 目录使用 `D:\Modelsim\win64\vsim.exe -c -do <入口>`：

- `run_video_timing.do`：2097152 种 Y 映射、全部合法 X 平移/光栅列、4096 种回中几何；30 个完整 OSD 面板及 100000 随机周期。
- `run_viewport_pan_stream.do`：同一连续帧测试分别跑行为 RAM 和 TD 官方非 SIM BRAM 模型，各检查无行缓存下溢及 1×/2×、20/40 步长、正负方向和边界像素。官方保护模型有两项参数切片警告，像素检查 PASS，没有屏蔽。
- `run_remote_controls.do`：手动模式与静音状态、暂停 2× 平移后的 KEY4 回到 1× 居中总览、预设/参数/视口/优先级。
- `run_application_recovery.do`、`run_emergency_recovery.do`、`run_sd_read_abort.do`：恢复、SW4 抢占、迟到读盘响应隔离。
- `run_museum_subtitle_overlay.do`、`run_museum_manual.do`、`run_museum_lecture.do`、`run_museum_status_osd.do`、`run_fat32_wav_streamer.do`、`run_audio_visualizer_overlay.do`、`run_rgb888_picture_adjust.do`、`run_mbp1_main_endpoint_control.do`、`run_hdmi_local_reset.do`：其余媒体、控制、协议与局部复位回归。

从主板工程根目录复现候选构建，复用原脚本，仅重定向产物，避免覆盖已验收 bit：

```powershell
(Get-Content .\scripts\build_museum_main_board.tcl -Raw).Replace('./_build_museum_main_board','./_build_y_origin_candidate') | & D:\TD_6.2.1\bin\td_commands_prompt.exe
(Get-Content .\scripts\build_museum_main_board_bitgen.tcl -Raw).Replace('./_build_museum_main_board','./_build_y_origin_candidate').Replace('./release/dual_fpga_museum_terminal_main_board.bit','./release/dual_fpga_museum_terminal_main_board_y_origin_candidate.bit') | & D:\TD_6.2.1\bin\td_commands_prompt.exe
```

## 烧录与验收

只更新主板；副板继续使用已验收 `8919e86` 的 bit。候选：

- `release/dual_fpga_museum_terminal_main_board_y_origin_candidate.bit`，634313 字节。
- SHA256：`7EE6C57AE2DD2231AB5B76E7F7AC73C9032CADF72063F07378003877646005C9`。
- 预期现象：与已验收双板版本完全相同，不应出现新增界面、素材顺序或等待流程变化。

短流程重点检查：启动五栏/名称；自动讲解的 1×/2×、暂停和平移；暂停 2× 后 KEY4 恢复到 1× 居中总览；副板手动模式切图、手动→自动后连续两次讲解字幕；SW4 应急及退出；网线重连后 SW3 模式切换。不要为这次单热点变更安排长时间耐久测试。若有图像错位、黑屏、行重复、字幕缺失或控制差异，改烧保留的正式 bit 并反馈具体步骤。

本轮提交不包含用户原有 `sim/tb_fat32_bmp_adaptive_loader.v` 与 `src/storage/bmp_sdram_row_writer.v` 修改，未推送。
