# 源尺寸存储与行命中译码资源优化（2026-10-03）

**后续实板未通过：** 用户反馈烧入Flash后概率出现黑屏、8008、名称缺失，KEY4不能恢复。该候选已撤回生产RTL，禁止把下面的资源/仿真/STA结果当作上板通过；仅保留bit和报告作为回归诊断记录。专用脚本/测试可由Git提交 `c955aa6` 找回。后续修复另存 `dual_fpga_museum_terminal_main_board_flash_startup_repair.bit`，不覆盖已验收版。

## 结论与边界

本轮已生成独立候选 bit，最终 setup/hold 均无违例。相对已验收纵坐标候选减少 165 Slice、390 LUT、325 FF，不增加 BRAM、DSP、PLL。该候选尚待实板验收，**不覆盖已验收 bit**。没有改副板、TF 素材、音画字幕时间轴、图片顺序、转场、按键分配、通信格式或时钟约束。

对应《2026 FPGA赛道选题指南—安路科技》物理第5页基本要求②稳定性/鲁棒性、④工程质量，以及《赛题解析一》第21页的逻辑优化方向：以真实物理资源和时序、功能回归为证据，不以占用更多资源作为得分依据；本轮没有功耗测量，不声称功耗或比赛分数提升。项目方向依据 `资料/双FPGA博物馆终端_后续推进与优化计划_20261001.md`。

## 两处必要改动

1. `museum_media_core.v` 的讲解/总览源 BMP 尺寸表各含5个32位数据，原来共320个可复位 FF。采用原厂 `EG_LOGIC_DRAM` 异步读分布式 RAM，保持原读延迟；每表只复位5个有效位，复位后不会显示旧 RAM 内容。只在原图片读取和 SDRAM 写入均成功完成时写表，失败或恢复不写入。讲解表和总览表仍独立，后台预载不能污染总览尺寸。
2. `linebuf_scaler_960x540_to_1280x720.v` 三槽行命中判定复用相同比较条件；“是否命中”用并行 OR，“选择哪槽”仍按0→1→2优先。没有新增像素流水级或改变帧/行数据请求时序。

先只改尺寸表的完整物理试验：Slice9433、LUT16765、FF11133，但最终 setup -0.464ns（1个失败端点）、hold +0.024ns，因此未生成 bit。原始失败路径由 video_y_reg[1] 经纵坐标映射、槽标签比较、串行优先命中链到 source_row_hit_d；第二处改动基于这条实际失败路径，不依据实例名猜测原因。最终候选仍使用同一 seed 1，未搜索种子或放宽约束。

## 最终物理结果

| 指标 | 已验收纵坐标版 | 本轮候选 | 差异 |
|---|---:|---:|---:|
| 综合 LUT | 16801 | 16512 | -289 |
| 综合 FF | 11381 | 11071 | -310 |
| 最终 LUT | 17081（87.15%） | 16691（85.16%） | -390 |
| 最终 FF | 11445（58.39%） | 11120（56.73%） | -325 |
| Slice / 9800 | 9486（96.80%） | 9321（95.11%） | -165 |
| BRAM9K / 64 | 43（67.19%） | 43（67.19%） | 0 |
| BRAM32K / 16 | 10（62.50%） | 10（62.50%） | 0 |
| DSP / 29 | 13（44.83%） | 13（44.83%） | 0 |
| PLL / 4 | 4（100%） | 4（100%） | 0 |
| setup WNS | +0.187ns | +0.016ns | -0.171ns |
| hold WNS | +0.023ns | +0.024ns | +0.001ns |
| setup/hold TNS | 0 / 0 | 0 / 0 | 无违例 |
| STA覆盖率 | 99.66% | 99.80% | +0.14个百分点 |

最终视频像素域 setup +0.207ns，375.094MHz HDMI串行域 +0.016ns 是全局最小值。资源有实测收益，但整体 setup 余量低于基线，不能宣称稳定性已通过板测。Slice仍偏高，不据此承诺新增功能容量。

工具为 TD6.2.168116 / EG4S20BG256；原产品入口、管脚和时序约束不变。全 DRC 和布线检查无报错，保留既有 SDRAM 相移时钟单负载使用本地布线资源警告；官方分布式 RAM 模型有两条 INIT_FILE 范围警告，不包装成“零警告”。证据文件均为本轮生成：

- `source_dimensions_candidate_20261003_gate_area.rpt`：综合网表资源。
- `source_dimensions_candidate_20261003_area.rpt` / `qor.rpt`：最终资源及违例端点数。
- `source_dimensions_candidate_20261003_timing.rpt`：完整布线后双角 STA。
- `source_dimensions_candidate_20261003_drc_bitgen.rpt`：DRC、布线检查及成功 bitgen。

## 功能检查

新增可运行检查，不仅检查仿真进程退出码，还检查 test_pass：

- `run_source_dimensions.do`：SIM RAM与原厂真实分布式 RAM 模型各60419次对照，共120838次；覆盖五槽、所有地址、异步读/复位、同地址写读、越界写。
- `run_source_row_hit_equivalence.do`：与固定基线 ffc0f06 实际译码逐值对照2162688次，覆盖所有1024行、三槽同时命中、有效位/epoch及X/Z控制。原槽优先级一致。
- `run_source_dimensions_integration.do`：实际媒体核心五槽尺寸、OSD锁存、后台讲解预载、失败/恢复与复位检查通过。

两处 RTL 改动后的最终回归9入口、19项 PASS、0失败：远程控制3、应用恢复1、应急恢复1、SD读取中断1、本地手动4、视频时序2、视口平移流4、现有转场2、尺寸集成1。此前尺寸表单独改动后的17入口25项也通过，涵盖音频、字幕、OSD、WAV读取、讲解、手动与画面参数；这些重复执行次数不算新增功能。副板实际端点重连、同boot会话/拨码一致性/超时回归通过，副板源码及 bit 未修改。

测试证据：`source_dimensions_candidate_20261003_dimensions_test.rpt`、`row_hit_test.rpt`、`integration_test.rpt`、`reconnect_test.rpt`；其余本地日志位于忽略目录 `_build_source_dimensions/final_run_*.log`。

## 复现与上板

在主板工程根目录执行：

```powershell
& D:\TD_6.2.1\bin\td_commands_prompt.exe scripts/build_source_dimensions_candidate.tcl
& D:\TD_6.2.1\bin\td_commands_prompt.exe scripts/bitgen_source_dimensions_candidate.tcl
Get-FileHash release/dual_fpga_museum_terminal_main_board_dimensions_candidate.bit -Algorithm SHA256
```

ModelSim从 `sim` 目录执行；对应 `run_remote_controls.do` 等现有回归入口同样可执行：

```powershell
& D:\Modelsim\win64\vsim.exe -c -do run_source_dimensions.do
& D:\Modelsim\win64\vsim.exe -c -do run_source_row_hit_equivalence.do
& D:\Modelsim\win64\vsim.exe -c -do run_source_dimensions_integration.do
```

输出：`release/dual_fpga_museum_terminal_main_board_dimensions_candidate.bit`，634313字节；SHA256：

```text
01C1721A28CC876D5F2221D126E2A848567A84D83FCFB0129177BFF5E5392FDA
```

只更换主板 bit，副板和两张卡不变。预期画面/控制与已验收版相同，不增加界面元素，也不承诺缩短预载时间。短流程检查：

1. 冷启动五栏完整、五件名称正常；高亮切换尺寸正确，讲解中预载下一件不污染当前 OSD。
2. 自动讲解1×/2×、暂停和平移；暂停2×后 KEY4 应恢复到1×居中总览，再加载可讲解。
3. 同件连续两次字幕；副板手动切图、手动→自动后连续两次讲解字幕。
4. 主板 SW4 应急及退出、双板网线重连后副板 SW3 自动/手动同步。

任何黑屏、五栏错位、名称/尺寸异常、字幕重入丢失、拨码卡死或通信模式不同步都判为未通过，回烧已验收 `dual_fpga_museum_terminal_main_board_y_origin_candidate.bit`（SHA开头7EE6C57A），不通过复位掩盖问题。旧正式 bit 36D9BB7C也保留。本轮未 push；已有未提交文件 `tb_fat32_bmp_adaptive_loader.v`、`bmp_sdram_row_writer.v` 保持原哈希，不纳入本轮提交。
