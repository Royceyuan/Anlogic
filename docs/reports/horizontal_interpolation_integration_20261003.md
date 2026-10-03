# 水平插值集成试验：未发布

2026-10-03 归档；两次候选的实际综合、布局和 STA 完成于 2026-10-02。结论：功能仿真通过，整机 setup 未闭合，不生成候选 bit，不替换已验收版本。

## 范围与赛题对应

对应选题指南物理第5页扩展③“图片缩放适配，鼓励优化缩放质量”。课件第19页提供双线性实现示例；第21页推荐优化逻辑而非增加资源占用。本轮仅试加载端水平插值，不将其称为完整双线性，也不宣称确定加分。

数据路径为源 BMP → RGB565 → 水平邻居插值 → 960×540 缓存 → 原有 1280×720 最近邻显示。纵向采样、第二级显示采样、图片顺序、自适应几何、转场、音频和字幕时间轴不变。插值不会恢复源图本来没有的细节。

## 实现与功能验证

复用源行 RAM 的单读口：先锁存左像素，再读钳位后的右邻居。复用原有恢复除法器，在8步内生成 `floor(256*水平余数/适配宽度)`；一个 DSP 分时计算 RGB 三通道，最后四舍五入。第二版由加载器保持输入稳定，去掉算术核重复锁存的输入。

- 算术核141099项检查通过，覆盖水平/双线性、边界、忙时请求、复位和输出保持。
- 实际 FAT32/SD/行 RAM/SDRAM 模型48组检查：插值开/关、9K/32K RAM、6种源尺寸、正/负 BMP 高度；逐像素核对数据、地址和打包。
- 4组新增阶段中断/重新加载：分数计算、请求、等待和写出阶段。
- 1919×1080 底向上 BMP 到960×540完整路径，逐像素和 SDRAM 字验证。
- 加载器工作期间的左右输入和分数稳定性断言通过。
- 17个既有回归入口共24项 PASS，覆盖恢复、应急、字幕、自动/手动、按键/远程、音频、OSD、视口和转场；副板重连模型另有1项 PASS。

仿真不等于新版本上板通过。本轮未写 TF 卡、未修改副板、未改媒体包。

## 完整资源和时序

同一器件、原ADC/SDC、固定 seed1；未降低时钟、未添加 false path、未扫描种子。

| 指标 | 已验收纵坐标版 | 首次集成 | 稳定输入优化后 |
|---|---:|---:|---:|
| 综合 LUT | 16801 | 16927 | 16871 |
| 综合寄存器 | 11381 | 11495 | 11439 |
| 最终 LUT / 19600 | 17081 | 17213 | 17134 |
| 最终寄存器 | 11445 | 11550 | 11506 |
| Slice / 9800 | 9486 (96.80%) | 9738 (99.37%) | 9705 (99.03%) |
| BRAM9K / 64 | 43 | 43 | 43 |
| BRAM32K / 16 | 10 | 10 | 10 |
| DSP / 29 | 13 | 14 | 14 |
| PLL / 4 | 4 | 4 | 4 |
| Setup WNS / TNS (ns) | +0.187 / 0 | -2.143 / -13.383 | -1.210 / -3.013 |
| 失败 setup 端点 | 0 | 27 | 5 |
| Hold WNS / TNS (ns) | +0.023 / 0 | +0.022 / 0 | +0.022 / 0 |

第二版少56个综合LUT、56个寄存器，仍不能交付。新增DSP虽有物理余量，整机布局已近满；单独小核的时序闭合不能代替整机闭合。

另外试验了“候选逻辑保留、开关置0”：setup +0.048ns、hold +0.022ns，但Slice为9559，仍高于已验收9486。该配置也撤回，不能将其综合LUT16627宣称为合入的优化收益。

## 保留与复现

正式生产入口、加载器、媒体核心和调用恢复原逻辑。候选以 `experiments/scale_quality/horizontal_integration.patch` 保留；`prepare_horizontal.tcl` 只向忽略的构建目录生成候选RTL。试验核仍位于 `experiments/scale_quality/rgb565_interpolate.v`，不加入正式工程入口。

隔离构建脚本已核验生成工程的TD展开及原ADC/SDC加载；为满足原SDRAM源码的根目录include，只复制一份原有 `global_def.v` 到试验目录，不修改vendor源码。正式入口TD展开也通过。此检查不等于重新布局布线或时序转正。

在工程根目录运行：

```powershell
& D:\Modelsim\win64\vsim.exe -c -do experiments/scale_quality/run.do
Push-Location sim
& D:\Modelsim\win64\vsim.exe -c -do run_horizontal_interpolation.do
Pop-Location
& D:\TD_6.2.1\bin\td_commands_prompt.exe scripts/build_horizontal_interpolation_candidate.tcl
& D:\TD_6.2.1\bin\td_commands_prompt.exe scripts/bitgen_horizontal_interpolation_candidate.tcl
```

最后一步必须检查 setup/hold，当前失败数据库会拒绝 bitgen。以后代码或布局结果变化时必须重新检查，不使用本轮报告冒充新的时序结果。

已验收主板 bit 保留为 `release/dual_fpga_museum_terminal_main_board_y_origin_candidate.bit`，SHA256：`7EE6C57AE2DD2231AB5B76E7F7AC73C9032CADF72063F07378003877646005C9`。预期仍为原有五栏、名称、讲解/手动、字幕、缩放/平移、双板控制和应急，不会出现新增插值效果。

原始证据：本目录 `horizontal_integration_20261003_*` 报告；完整模型日志在本地 `_build_horizontal_interpolation`，可按上述命令重新生成。本轮不提交用户原有两处修改，不push。

## 后续方向

按用户授权，接着评估 MBP1 收发共用CRC逻辑的等价表达式，保持数据格式和逐字节时序不变。它对应指南1.2板间通信、基础“系统工程规范性”及课件第21页逻辑优化；最终仍以整机Slice、setup/hold及真实双板验收为门槛，不承诺综合表达式更短就一定省硬件。

该方向已执行：CRC全部16777216组输入等价，但最终Slice增加、hold未闭合，亦撤回。详见 [CRC单热点试验](mbp1_crc_single_hotspot_20261003.md)。
