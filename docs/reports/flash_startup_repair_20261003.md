# Flash冷启动黑屏修复（2026-10-03）

## 已验证事实与待验证因果

- 用户板测：资源候选c955aa6写Flash后概率出现黑屏、8008、LED3/4熄灭；OSD可见但名称缺失，KEY4不能恢复。该候选判为不通过。
- `museum_media_core.v` 的8008不是错误码：首位8来自frame_done，末位8来自图片加载器S_DONE，两个0分别是固定字段及row_index低4位。因此不能据此直接认定“读取未完成”，也不能认定五张图片、名称和SDRAM内容已校验正确。LED输出随不同状态/板级极性解释，不单凭亮灭定位故障。
- 原系统PLL与视频PLL的extlock未接入媒体复位；write/mem复位只靠两个时钟周期后释放。这允许PLL尚未锁定时启动SD、SDRAM/FIFO控制。针对真实RTL的延迟锁定模型在90ns触发 `media released before system PLL lock`；这是可复现的启动缺陷，不是凭现象推测。
- **尚未知：** 该缺陷是否是此次概率故障的全部原因。仿真不能模拟真实卡、电源、PLL启动及板级信号完整性；最终判断须依靠修复bit的Flash冷启动复测。未伪称已复现整板黑屏/名称丢失，也未修改素材来掩盖故障。

## 最小修复

1. 撤回未通过实板的尺寸表分布式RAM与行缓存OR命中优化，恢复已验收数据通路和原复位型尺寸表。保留旧候选bit/报告作诊断；失效专用脚本/测试从当前工程移除，在Git c955aa6仍完整可回溯。
2. 两个原PLL封装只新增locked输出，接原厂extlock；PLL分频、相位及数量不变。
3. mem/write复位等待系统PLL锁定；1280视频复位等待视频PLL锁定和SDRAM初始化。仍使用原两级reset_sync，异步拉住、按各域时钟同步释放，没有额外固定等待计时器。
4. 其他历史视频模式不新增PLL接口，保留其原复位关系；正式产品是1280路径。

不新增重试状态机，不修改KEY4流程、吞吐、缓存策略、协议、图片/音频/字幕顺序、TF内容或副板。原两个用户未提交文件保持原哈希，不纳入本轮提交。

## 验证

`sim/run_pll_startup.do` 复用实际媒体核心集成fixture，只给两个PLL独立的可控锁定信号。覆盖4轮独立延迟/重新锁定、失锁时清空缓存、视频晚锁定到总览素材已完成后仍能启动，以及实际像素通路有非黑像素；不以OSD白字代替图片非黑检查。修复前失败、修复后PASS；模型警告保留并明确记录，不声称零警告。

正常回归17入口共27项PASS、0失败：remote_controls(3)、application_recovery(1)、emergency_recovery(1)、sd_read_abort(1)、local_manual_test(4)、video_timing(2)、viewport_pan_stream(4)、light_band(2)、museum_subtitle_overlay(1)、museum_lecture(1)、museum_manual(1)、museum_status_osd(1)、fat32_wav_streamer(1)、audio_visualizer_overlay(1)、rgb888_picture_adjust(1)、mbp1_main_endpoint_control(1)、hdmi_local_reset(1)。对应入口为 `sim/run_<名称>.do`，日志位于 `_build_flash_startup_repair/fixed_run_*.log`。新增PLL测试另算1入口、4轮场景，PASS。首次批量检查因匹配 `PASS ` 而漏掉已有测试输出的 `PASS:`，并非测试失败；已改为单词边界匹配并完整重跑。

修复前/后启动检查原始记录：`flash_startup_repair_20261003_pll_before.rpt` / `pll_after.rpt`。前者是有意保留的失败复现，不能纳入修复后“0失败”计数。常规fixture有12条已有端口/模型警告，未隐藏。

## 完整构建结果

TD6.2.168116 / EG4S20BG256，沿用原ADC/SDC和固定seed1；没有种子搜索、降低时钟、放宽约束或忽略违例。综合、布局布线、双角STA、全DRC、布线状态检查及bitgen均完成。只撤回优化而未加保护的对照重构得到原已验收setup +0.187ns / hold +0.023ns；最终发布修复候选是加入锁定保护之后的独立重新构建，不能混用两次报告。

| 指标 | 已验收纵坐标版 | 启动修复候选 |
|---|---:|---:|
| 综合LUT / FF | 16801 / 11381 | 16688 / 11381 |
| 最终LUT / FF | 17081 / 11445 | 16960（86.53%）/ 11427（58.30%） |
| Slice / 9800 | 9486（96.80%） | 9540（97.35%） |
| BRAM9K / BRAM32K | 43/64、10/16 | 43/64、10/16 |
| DSP / PLL | 13/29、4/4 | 13/29、4/4 |
| setup / hold WNS | +0.187 / +0.023ns | +0.107 / +0.023ns |
| setup / hold TNS | 0 / 0 | 0 / 0 |
| 违例端点 | 0 | 0 |
| STA覆盖率 | 99.66% | 99.60% |

资源与时序余量仍紧张。本轮目标是修复稳定性，不宣称资源改善；与上一未通过候选相比Slice增加219，与已验收版相比增加54。DRC/布线无错误，保留原derive_pll_clocks过时及SDRAM相移时钟本地布线等工具警告。

最终工具证据为 `flash_startup_repair_20261003_gate_area.rpt`、`area.rpt`、`qor.rpt`、`timing.rpt`、`drc_bitgen.rpt`（均带前述完整前缀）。新bit为634313字节，SHA256：

```text
4409952619964B9FB2D138E2D3FB9006DB005E53278404412D8A7F92AB876BE5
```

两份旧bit7EE6C57A / 36D9BB7C及副板源码/bit保持不变。用户原有 `sim/tb_fat32_bmp_adaptive_loader.v` / `src/storage/bmp_sdram_row_writer.v` SHA256仍为9E91CC46… / F3955F05…，未纳入提交。完成后自动commit、不push。

复现（主板根目录）：

```powershell
& D:\TD_6.2.1\bin\td_commands_prompt.exe scripts/build_flash_startup_repair.tcl
& D:\TD_6.2.1\bin\td_commands_prompt.exe scripts/bitgen_flash_startup_repair.tcl
```

启动仿真（sim目录）：

```powershell
& D:\Modelsim\win64\vsim.exe -c -do run_pll_startup.do
```

## 上板验收

只更换主板，新文件为 `release/dual_fpga_museum_terminal_main_board_flash_startup_repair.bit`；副板及两张卡不改。必须烧到Flash后断电再上电，不能只验证JTAG下载。预期：启动完成后五栏图片、具体文物名称完整；能进入讲解；KEY4恢复、字幕重入、自动/手动、应急及重连等功能保持原样。8008仍可能是正常完成显示，不要求换成别的数码管值。

针对概率故障，进行10次短冷启动：每次断电待电源灯熄灭、间隔至少5秒，再上电；至少覆盖上电前网线插入/未插入以及两个不同有效文物拨码。记录每次五栏/名称是否完整、是否能讲解；失败不要用KEY4后的正常结果抵消。如果仍失败，记录OSD名称/尺寸、数码管、是否可以进入讲解，并用未覆盖的已验收7EE6C57A bit在同一张卡、相同电源和拨码下作A/B，继续排查，不认定通过。
