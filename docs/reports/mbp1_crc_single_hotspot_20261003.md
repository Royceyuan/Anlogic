# MBP1 CRC单热点试验：未合入

2026-10-03。按用户“若插值不能发布则自行选择下一步”的授权，在撤回水平插值生产改动后，评估收发共用CRC函数。结果：算术完全等价，局部逻辑减少，但最终Slice增加且hold失败；已撤回，不生成新bit、不push。

## 对应赛题与约束

对应指南物理第4页1.2“多板合理分工、板间通信、可靠运行”，第5页基础“显示稳定性与鲁棒性、系统工程规范性”，以及《赛题解析一》第21页“以优化逻辑实现最终设计”。这是现有链路的实现优化，不是新增扩展功能或确定加分项。

只替换 `mbp1_codec.crc_byte`，保持CRC-CCITT多项式0x1021、初值、字节顺序、包长、UDP地址、MBP1字段、ACK、重传、会话/去重和逐字节时序不变。没有增加RAM、DSP、状态或协议延迟。

候选计算：先令 `folded=prior[15:8]^value`，再 `folded^=folded>>4`，用固定拼接与异或获得16位新CRC。原逐位算法仍作为独立测试参考。

## 验证

- 穷举65536种旧CRC × 256种输入字节，共16777216组，全部完全相同。
- 原有编码/解码、标准向量、坏CRC、坏头、截断、最大256字节载荷、超长拒绝检查通过。
- 主板端点禁用/启用控制、直接TX字段、定址UDP、媒体桥五个入口通过。覆盖HELLO、ACK、状态查询、周期上报、去重和心跳。
- 未将历史端点对照算为PASS：`run_mbp1_endpoint_equivalence.do` 使用62ee8bf端点参考，在tick38失败。使用HEAD原CRC重跑也在同一tick失败，属于当前端点与历史参考不兼容；本轮只记录，不修改无关测试或协议行为。

穷举证明CRC函数对所有二值输入相同，不能据此声称新物理布局已实板通过。当前电脑网卡故障不作为测试前提，最终上板应使用真实双板。

## 整机资源及STA

水平插值生产改动已完整撤回后再综合本候选，原器件、ADC/SDC、seed1、时钟与构建参数不变。未扫描种子或添加时序豁免。

| 指标 | 已验收纵坐标版 | CRC候选 |
|---|---:|---:|
| 综合LUT | 16801 | 16814 |
| 综合寄存器 | 11381 | 11381 |
| codec层次LUT / ripple | 680 / 78 | 672 / 78 |
| 最终LUT / 19600 | 17081 (87.15%) | 17100 (87.24%) |
| 最终寄存器 | 11445 | 11441 |
| Slice / 9800 | 9486 (96.80%) | 9672 (98.69%) |
| BRAM9K / BRAM32K | 43 / 10 | 43 / 10 |
| DSP / PLL | 13 / 4 | 13 / 4 |
| setup WNS / TNS (ns) | +0.187 / 0 | +0.146 / 0 |
| hold WNS / TNS (ns) | +0.023 / 0 | -0.082 / -0.082 |
| hold失败端点 | 0 | 1 |
| STA覆盖 | 99.66% | 99.66% |

局部减少8 LUT，但整机综合增加13 LUT、最终增加19 LUT和186 Slice。不能把局部/代码行数下降当作整机资源收益。hold最紧路径位于codec内寄存器控制端；更改组合表达式会影响全局打包、复制和布线，不能用函数等价隐藏物理时序失败。

这也说明当前不适合继续用小表达式改写来释放布局空间。后续应独立评估确有大量触发器/多路选择开销的元数据存储，先测RAM化或有边界证明的位宽收益，再考虑重新集成插值；不能同时修改SD握手和像素算法来混淆问题。

## 保留、复现与当前使用

生产CRC已恢复原算法。候选保留在 `experiments/mbp1_crc/prepare.tcl`，仅生成忽略目录中的RTL；`build.tcl`只替换生成工程里的codec，不改正式入口。运行：

```powershell
Push-Location sim
& D:\Modelsim\win64\vsim.exe -c -do run_mbp1_crc_equivalence.do
Pop-Location
& D:\TD_6.2.1\bin\td_commands_prompt.exe experiments/mbp1_crc/build.tcl
```

当前候选不执行bitgen。原始报告为本目录 `mbp1_crc_trial_20261003_{gate_area,area,qor,timing}.rpt`，本地完整日志位于 `_build_mbp1_crc_candidate`。

隔离构建脚本的生成工程TD展开、原ADC/SDC加载已通过；构建只在试验目录运行，并复制原SDRAM include头文件以保持原有路径，不修改生产源码或约束。

主板继续用已验收 `release/dual_fpga_museum_terminal_main_board_y_origin_candidate.bit`（SHA256开头7EE6C57A），副板不变。无需重新烧录；五栏/名称、自动与手动、字幕、缩放/平移、应急、双板控制的预期现象与本轮之前一致。本轮没有新增资源优化合入，也没有新增BOARD PASS。

用户原有 `sim/tb_fat32_bmp_adaptive_loader.v`、`src/storage/bmp_sdram_row_writer.v` 未改、未提交；TF卡素材未写入，音画字幕时间轴和图片顺序未改。
