# 双板回溯与波形单热点资源优化

日期：2026-10-02。范围仅为主板 `audio_visualizer_overlay.v`；副板 RTL、通信协议、按键、音画字幕时间轴和 TF 素材不变。八小时长测不是本轮通过门槛。

## 已验收回溯点

| 工程 | 分支/提交 | 已验收 bit SHA256 |
|---|---|---|
| Anlogic 主板 | Yan_Chen_Double / eb9c1aa5adfe821ffdce8b16069f52e17d501804 | 36D9BB7C74E23C047BEC15A5E128A8540852B8C4B7ECD11F504E25CDB107A6EC |
| Anlogic2 副板 | secondary-main5e / 8919e868726af8433d7906c3bfa833edec42809d | 41B81E033E6F282AAC9E572D982BF8E145504FA38111CDC5F22F86021956CA58 |

离线备份位于 `D:\VSCode\CodeFiles\Git_TD\工程回溯\双板已验收_20261001_eb9c1aa_8919e86`。两板全部 351/137 个已跟踪文件均保存为实文件并逐项核对 SHA256，含 LFS 素材和 bit；两个 `git bundle --all` 均通过 verify。主板 90 个工程引用文件存在，副板 manifest 的 70 个输入哈希一致。备份不放入 rubbish，也不随本轮提交上传。

主板原有 `sim/tb_fat32_bmp_adaptive_loader.v` 修改和 `src/storage/bmp_sdram_row_writer.v` 换行差异已单独保存；本轮不改动、不提交这两项。副板保持原提交和干净工作区。

## 单热点与筛选原则

最后一次对照只改柱体纵向命中判定：在原有 y=550～650 区间内，距中心 y=600 的偏移必处于 -50～50；七位模减法给出准确有符号偏移，其绝对值与柱高比较，等效替代原上下边界的两次比较。RAM 宽度、双缓冲、PCM 计算、采样分组、颜色及两级像素延迟保持原样。该候选最终未合入，生产 RTL 已恢复。

本轮未采用的尝试：

- 强制 RAM 宽度/保留属性没有节省资源，部分配置反而增加一个 BRAM9K；已撤回。门级导出表明其层级面积混入了跨层时钟关联逻辑，不能把该数字当作 RAM 转换开销。
- 仅横向解码版本释放 84 Slice，但 setup=-0.182 ns；未生成 bit。
- 横向解码加共享限幅版本释放 48 LUT、30 Slice，但 setup=-0.070 ns；未生成 bit。
- 独立阈值限幅版本布局占 9608 Slice，高于基线 9545，未采用。
- 合并纵向距离的版本虽减少 62 LUT，但 Slice 未下降且 setup=-0.492 ns、STNS=-0.497 ns；未生成 bit。
- TD 的 post-route phys_opt 两次触发工具崩溃，未导出可用结果，没有用于发布。

所有尝试均使用原管脚/时序约束和固定 seed1；没有搜索种子、降低时钟、添加 false path 或改变 PLL。是否合入以最终布局资源及 setup/hold 为准，不用综合阶段的下降代替交付结果。

## 验证

ModelSim 10.6e：`D:\Modelsim\win64\vsim.exe`。运行方式见 `sim/README.md`。

- `run_audio_visualizer_overlay.do`：完整 16 位有符号 PCM 域 × 三种双声道组合，共 196608 组，含 -32768、低位进位、限幅、暂停清零及应急红色。
- `run_audio_visualizer_equivalence.do`：Git eb9c1aa 已验收模块作参考；行为 RAM 和 TD 官方物理 RAM 各跑一遍。每遍覆盖 262144 种纵坐标/柱高组合、99996 个逐周期像素/同步比较、72457 次 RAM 对照、845 次显示有效的帧触发；覆盖 512 地址、独立读写时钟、相邻不同柱高、复位、PCM 空档及暂停。
- 负向验证：将候选 `bar_read_index` 强制为 0，测试在像素周期 2212 捕获 mismatch；该故意注错的 Fatal 不属于正常回归失败。
- 主板其余回归：remote_controls、application_recovery、emergency_recovery、sd_read_abort、museum_subtitle_overlay、museum_manual、museum_lecture、emergency_mode、museum_status_osd、fat32_wav_streamer。
- 副板：真实配对协议端点的网线重连/SW3 模式同步回归。副板生产代码未修改。

共 13 组正常入口、16 项 PASS。含 stub 的控制仿真及厂商模型均不等同真实 TF/PHY/HDMI 板测；不存在把新候选记为 BOARD PASS 的结论。

## 最终结果

最后一次对照完成综合、固定 seed1 布局布线、最终 STA 和 DRC。其输入 `audio_visualizer_overlay.v` 的 SHA256 为 `A509F5B1C0FBA7987D823A14B6F54E0F534AE0E49FF958D725A525B4F51F2605`；仅将原 `bar_hit` 的两个边界比较替换为：

```verilog
wire [6:0] y_offset = y_s2[6:0] - CENTER_Y[6:0];
wire [6:0] y_distance = y_offset[6] ? -y_offset : y_offset;
wire bar_hit = !pause && display_valid && in_bar &&
               y_distance <= bar_height_s2;
```

| 指标 | 已验收基线 | 最小候选 | 差异 |
|---|---:|---:|---:|
| 综合 gate LUT | 16811 | 16798 | -13 |
| 最终布局 LUT | 17111 / 87.30% | 17082 / 87.15% | -29 |
| 最终寄存器 | 11435 | 11436 | +1 |
| 最终 Slice | 9545 / 97.40% | 9566 / 97.61% | +21 |
| BRAM9K | 43 / 64 | 43 / 64 | 0 |
| BRAM32K | 10 / 16 | 10 / 16 | 0 |
| DSP | 13 / 29 | 13 / 29 | 0 |
| PLL | 4 / 4 | 4 / 4 | 0 |
| setup WNS | +0.075 ns | +0.257 ns | +0.182 ns |
| hold WNS | +0.024 ns | +0.022 ns | -0.002 ns |
| setup/hold TNS | 0 / 0 | 0 / 0 | 无违例 |
| STA 覆盖 | 99.66% | 99.66% | 0 |

候选虽等效且时序闭合，但只节省 29 LUT，反而增加 21 Slice；未达到释放物理布局资源的目标，因此撤回，不生成或替换正式 bit。TD 原有 SDRAM 单负载本地时钟、derive_pll_clocks 弃用等警告仍存在，不能将 DRC 完成表述为工具零警告。

本轮落地内容为新增等效回归及本报告，不含生产 RTL 优化；当前实际资源仍为基线数值。两板正式 bit 均保持已验收哈希。临时对照产物单独归入 `rubbish/waveform_single_hotspot_20261002`，不参加正式构建、不提交。

## 操作与预期现象

不需要重新烧录，也不需要更改 TF 卡或副板。当前双板现象与已经验收的版本相同。本轮没有新优化 bit、没有新 BOARD PASS，也没有资源下降已合入的结论。

需要回退时直接烧录离线快照内两板对应 bit，恢复说明见回溯目录 README；不要覆盖工作区原有修改。后续优化应继续逐热点筛选，并对综合面积、最终 LUT/Slice、时序和板测分开记账；本次不进一步改动其它热点或搜索种子。
