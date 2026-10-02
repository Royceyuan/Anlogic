# 应急区域判定单热点资源评估

日期：2026-10-02。结论：候选有面积收益，但未满足完整时序门槛，已撤回，不生成新 bit。当前实际资源没有因该试验下降。

## 范围与回溯

仅试改主板 `src/video/museum_emergency_overlay.v` 的固定矩形范围判定：用一块双端口 BRAM32K 分别读取 X/Y 坐标对应范围标志，斜线运算仍用原加减法。原有一拍像素延迟、调色优先级、闪烁和告警 PCM 不变；非流水入口保持原样。没有更改 TF 读取、缓存、字幕、缩放、按键、协议或副板。

主板基线 eb9c1aa、正式 bit SHA256 为 `36D9BB7C74E23C047BEC15A5E128A8540852B8C4B7ECD11F504E25CDB107A6EC`；副板基线 8919e86、bit SHA256 为 `41B81E033E6F282AAC9E572D982BF8E145504FA38111CDC5F22F86021956CA58`。两板离线实文件快照及 Git bundle 位于 `D:\VSCode\CodeFiles\Git_TD\工程回溯\双板已验收_20261001_eb9c1aa_8919e86`，详情见同日期波形评估报告。

原有两个未提交文件 `sim/tb_fat32_bmp_adaptive_loader.v`、`src/storage/bmp_sdram_row_writer.v` 不修改、不提交。副板不修改。

## 功能验证

ModelSim 10.6e，TD 6.2.168116：

- 每个坐标在独立时钟周期输入，覆盖 2048×1024 共 2097152 个坐标，逐拍核对输出像素及 hs/vs/de/x/y。参考是原直接入口和独立旧几何公式，不是与 ROM 共用范围函数的另一张查表。
- 行为 ROM 和官方 `EG_PHY_BRAM32K` 各通过一次全域检查。官方模型同时加载 `eg_phy_glbl.v` 的 `glbl`，实际覆盖 INIT 位序、双端口地址及一拍读延迟；不是只检查 SIM 分支。
- 覆盖复位、正常 RGB 透传、有效/消隐、两种闪烁背景、告警 PCM 正负变化与退出静音。
- 导出综合门级网表，独立逐位核对 128 段 INIT、2048 地址、32768 位，全部与范围数学表达一致；初始化未被综合丢弃。
- 其余主板回归：remote_controls、application_recovery、emergency_recovery、sd_read_abort、museum_subtitle_overlay、museum_manual、museum_lecture、museum_status_osd、fat32_wav_streamer、audio_visualizer_overlay、video_timing、rgb888_picture_adjust、mbp1_main_endpoint_control、hdmi_local_reset。14 个入口、17 项 PASS，加上两种应急检查共 16 个入口、19 项 PASS。

候选输入文件 SHA256：`C69F6C37C60994D181A7C8C26F28C89AB07DE8EB5302CA5BC8198FDDC4B434CD`。候选及实验入口归档于下述 rubbish 子目录，不参与正式工程。

## 综合与最终布局

先完成综合和功能仿真，再布线；只试 seed1、seed2、seed3，不继续搜索。三次使用同一门级数据库、原管脚和时序约束、high 布局努力及 routability 布线；没有降低频率、改变 PLL 或添加 false path。

| 指标 | 已验收基线 | 候选 seed1 | 候选 seed2 | 候选 seed3 |
|---|---:|---:|---:|---:|
| 综合 LUT | 16811 | 16376 | 16376 | 16376 |
| 最终 LUT | 17111 (87.30%) | 16629 (84.84%) | 16624 (84.82%) | 16636 (84.88%) |
| 最终寄存器 | 11435 | 11428 | 11424 | 11422 |
| Slice | 9545 (97.40%) | 9432 (96.24%) | 9446 (96.39%) | 9457 (96.50%) |
| BRAM9K | 43/64 | 43/64 | 43/64 | 43/64 |
| BRAM32K | 10/16 | 11/16 | 11/16 | 11/16 |
| DSP | 13/29 | 13/29 | 13/29 | 13/29 |
| PLL | 4/4 | 4/4 | 4/4 | 4/4 |
| setup WNS | +0.075 ns | -0.984 ns | -0.521 ns | +0.142 ns |
| setup TNS | 0 | -4.270 ns | -0.853 ns | 0 |
| hold WNS | +0.024 ns | +0.024 ns | +0.030 ns | -0.010 ns |
| hold TNS | 0 | 0 | 0 | -0.010 ns |
| STA 覆盖 | 99.66% | 99.69% | 99.69% | 99.69% |

模块综合面积由 190 LUT+174 ripple 减至 60 LUT+50 ripple；整机面积差还包含重新映射/打包的影响，不能把全部整机 LUT 差算成该模块直接删除的逻辑。

seed1/2 失败主要涉及原有纵坐标映射、波形及状态更新链，说明单一模块面积下降不能保证整体布局时序。seed3 剩余一条 HDMI 复位释放 removal 违例：视频复位同步输出至串行时钟复位同步器的异步复位端。额外普通 `fix_hold` 与指定该网的 `fix_hold -clock_opt` 均未解决，工具提示修复会受到 setup 约束限制，最终数值仍为 -0.010 ns；未忽略该违例、未放宽约束、未生成 bit。

TD 原有 SDRAM 本地时钟、PLL feedback 路由及 derive_pll_clocks 弃用等警告仍存在，不能称为工具零警告。STA 覆盖不是 100%，沿用既有覆盖边界，不把未分析路径宣称为全部已验证。

## 落地与预期现象

- 生产应急 RTL 已恢复至基线，正式 bit、原资源/时序报告及副板版本保留。
- 加强现有应急测试：全域逐拍采样，变化同步信号，检查复位、消隐及正常 RGB 透传。入口为 `sim/run_emergency_mode.do`。
- 实验数据库、候选 RTL 和官方模型入口归入 `D:\VSCode\CodeFiles\Git_TD\rubbish\emergency_region_single_hotspot_20261002`，不参加正式构建、不提交。
- 本机重跑候选物理 ROM 检查可从主板 `sim` 目录执行 `D:\Modelsim\win64\vsim.exe -c -do ../../rubbish/emergency_region_single_hotspot_20261002/run_emergency_region_physical.do`；入口直接编译归档候选，不覆盖生产源码。仅归档存在的本机可用，不属于仓库必需入口。
- 不需要重新烧录或更改 TF 卡，画面、音频、字幕、按键和双板联调预期均与已验收版本相同。本轮没有新 BOARD PASS，也没有“资源下降已合入”的结论。

下一热点应优先针对实际 STA 中的像素纵坐标映射关键链评估，而不是继续刷种子或只按综合 LUT 判断收益；须另做独立等效检查，不能叠加本次未通过候选。
