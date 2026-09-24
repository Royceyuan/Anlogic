# HX4S20 图片显示工程

唯一安路 TD 工程入口：

`hx4s20_museum_terminal.al`

双击该文件即可在 Anlogic TD 中打开统一工程。当前顶层模块为
`top_1280x720_main4_emergency`，目标器件为 `EG4S20BG256`。

## 当前交付

- 下载文件：`release/hx4s20_main4_emergency.bit`
- `SW1～SW3`：选择后台预载文物；`SW4`：应急模式，高电平立即抢占
- `KEY1`：总览切换文物，讲解中切换 1×/2×；`KEY2`：确认或暂停/继续
- `KEY3`：循环切换画面参数；`KEY4`：应用级故障恢复
- 图片、WAV、字幕和 OSD 名称均由 TF 卡根目录读取；详细文件约定见 `HANDOFF.md`
- MAIN-4 已完成仿真、P&R、STA、DRC 和上板验收，当前发布位流已板测通过

## 可复现构建

在工程根目录执行：

```text
td_commands_prompt.exe scripts/run_media_1280x720_v72_resource_optimized_syn.tcl
td_commands_prompt.exe scripts/run_media_1280x720_v72_resource_optimized_pr.tcl
td_commands_prompt.exe scripts/run_media_1280x720_v72_resource_optimized_bitgen.tcl
```

当前 v72 的构建证据若需追溯，见工程外的
`D:/Anlogic_information/_hx4s20_multimedia_main_cleanup_20260904/build_dirs`；本目录不再携带 TD 生成的构建目录。硬件状态仍需以实际板测为准。

## 1280×720 独立候选 v70c

v70 的完整 1280×720 SDRAM 帧在 25 MHz SDRAM 用户时钟下需要约
27.93 Mword/s，板测出现花屏、`8008` 且 LED4 灭，证实持续读欠载。v70b 保持
官方 `31_hdmi_tx_display_B` HDMI TX 和真实 1280×720 输出，将 SDRAM 工作帧
改为 960×540，再用已验证的线缓冲放大到 1280×720，平均读需求降为约
15.71 Mword/s。v70b 板测又暴露了物理 BRAM 多一拍和 KEY2 epoch 自锁；v70c
改用硬件匹配的 NOREG 单拍路径并修复重启。统一 v69 工程不变；v70c 首轮仍关闭
OSD、字幕和转场。

构建顺序：

```text
td_commands_prompt.exe scripts/run_media_1280x720_v70c_bram_restart_fix_syn.tcl
td_commands_prompt.exe scripts/run_media_1280x720_v70c_bram_restart_fix_pr.tcl
td_commands_prompt.exe scripts/run_media_1280x720_v70c_bram_restart_fix_bitgen.tcl
```

v70c 路由后 setup WNS `+0.761 ns`、hold WNS `+0.032 ns`，TNS 均为 0；bit 为
`release/hx4s20_1280x720_v70c_bram_restart_fix.bit`。这些是实现报告，不代表硬件
已验证。当前只预加载 IMAGE0/IMAGE1 两帧，便于先验收 720P 基础链路。

## 1280×720 当前版本 v72

v72 在 v70c 链路上恢复五图缓存、快速切图、七种转场、自动轮播、亮度/对比度、
顶部 OSD、原图 DIM 和 UART 中文字幕，并将 DSP 占用保持为 5/29。当前推荐 bit：

- `hx4s20_1280x720_v72_resource_optimized.bit`

详细 SHA256、资源、时序和操作说明见
`docs/media_1280x720_v71_v72_full_features_20260902.md`。当前修正版尚未上板验证。

## 自适应 BMP

加载期间将最大 1920×1080 的源图按比例缩放并居中到 960×540 工作帧，再输出为
1280×720；空余区域使用背景色补齐，不需要提前强制拉伸。输入格式为 24 位、未压缩
Windows BMP（BI_RGB）。

工程目录只保留统一 TD 入口、活动/回退源码、约束、构建脚本、源级仿真、工具、必要测试数据、官方 vendor 源和少量发布 bit。历史构建、日志和仿真 work 目录没有丢失，而是移至工程外的
`D:/Anlogic_information/_hx4s20_multimedia_main_cleanup_20260904`，清单见其中的 `MANIFEST.csv`。当前统一工程的版本索引见 `PROJECT_INDEX.md`。
