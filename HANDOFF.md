# HX4S20 多媒体工程交接

更新时间：2026-09-09
适用目录：`D:\VSCode\CodeFiles\Git_TD\Anlogic`
当前分支/提交：`Yan_Chen0907` / `a8b9495264fe654d4ef83bfe631bac3941fdff19`
远端：`origin/Yan_Chen0907`，当前 `HEAD` 与远端同提交。

## 1. 当前任务与最终目标

当前没有正在实施的新功能；刚按用户要求从已撤销的“商品展示/原生四线 SD”实验完整回退到 GitHub `Yan_Chen0907`。

本工程的稳定目标是 HX4S20 (`EG4S20BG256`) 上的 1280×720 HDMI 多媒体图片播放器：TF 卡读取 BMP，五图缓存和快速切换，转场、亮度/对比度、顶部 OSD、UART 中文字幕，以及 v73 候选中的 WAV 音频和音频波形可视化。

完成某个版本的交付必须同时具备：RTL/仿真证据、完整综合/P&R/STA/DRC 闭合、可追溯 bit 和用户板测。综合或 bitgen 成功不等于板级通过。

## 2. 当前工作进度

### 已确认

- 当前分支最新提交 `a8b9495` 为 `fix: slim audio control display logic`。它移除了 OSD 中自动轮播速度和暂停文字的显示逻辑，保留音轨号显示，并新增 `release/hx4s20_1280x720_v73_multiaudio_controls_minimal.bit` 的 LFS 记录及 bitgen 脚本。
- 历史 v72 图片链和 v73 音频候选源均在当前 checkout 中；`src/memory/sdram_bmp_row_top_v66.v` 是共同的媒体核心。
- 当前唯一 TD 工程为 `hx4s20_800x600_multimedia.al`。其工程配置的活动顶层仍是 `top_1280x720_feature_v72_resource_optimized`，并非 v73；这是当前文件的事实。
- v73 独立包装顶层 `src/memory/top_1280x720_feature_v73_audio_visualizer.v`、ADC/SDC 及完整 P&R 脚本存在。该包装以 `top_v66` 启用五图、1280×720、UART 字幕和音频可视化。
- 本轮之前创建的商品展示顶层、原生四线 SD 状态机、诊断 bit、P&R 目录、ModelSim work、相关测试和脚本均已被用户明确要求回退并清除；当前仓库中不存在这些文件。除非用户再次明确提出，不要恢复或继续该实验。

### 未完成 / 当前卡点

- 当前 checkout 没有 `_build_v73_audio_visualizer` 或 v72 的完整构建目录和当前轮报告。不能声称 `a8b9495` 已重新 P&R 或已板测。
- v73 的 `build_v73_audio_visualizer_bitgen.tcl` 与两个多音频 bitgen 脚本都依赖缺失的 `_build_v73_audio_visualizer/v73_audio_visualizer_pr.db`；不能直接运行它们生成可信 bit。
- 当前工作区有 10 个 Git LFS 跟踪的历史 release bit 缺失，`git status` 显示为删除；详见“项目状态快照”。不要在未说明目的的情况下清除该状态、提交删除或自动下载/恢复 LFS 对象。
- 当前用户没有要求继续 v72/v73 或恢复缺失 release；下一步应等待明确任务。若用户要求继续，先确认目标是稳定 v72 还是 v73 音频候选。

## 3. 关键上下文

### 关键文件

| 文件 | 作用 |
|---|---|
| `hx4s20_800x600_multimedia.al` | 唯一 TD 工程；当前工程标签/模块配置仍为 v72。 |
| `src/memory/top_1280x720_feature_v72_resource_optimized.v` | 工程当前配置使用的 1280×720 图片播放器包装顶层。 |
| `src/memory/top_1280x720_feature_v73_audio_visualizer.v` | v73 音频可视化候选包装顶层；不能因文件存在就假定已成为工程默认顶层。 |
| `src/memory/sdram_bmp_row_top_v66.v` | 图片缓存、SDRAM、SPI TF、按键、OSD、音频和字幕的主媒体链。 |
| `src/audio/fat32_wav_streamer.v`、`audio_pcm_player_48k.v`、`audio_goertzel8.v` | v73 WAV 读取、PCM 播放与可视化相关模块。 |
| `src/video/audio_visualizer_overlay.v` | 64 根蓝/青交替柱状音频波形可视化。 |
| `src/video/uart_subtitle_overlay.v` | 800×32、2-bit、双缓冲、帧边界提交的中文位图字幕。 |
| `constraints/top_1280x720_v73_audio_visualizer.{adc,sdc}` | v73 独立约束；SPI：CLK A14、MOSI A13、MISO B14、CS A12；UART：F12/D12。 |
| `scripts/build_v73_audio_visualizer_pr.tcl` | v73 全流程 P&R，固定 seed 75，输出 `_build_v73_audio_visualizer`。 |
| `scripts/build_v73_audio_visualizer_bitgen.tcl` | 只从已完成的 v73 P&R DB 生成 bit。 |
| `scripts/build_v73_multiaudio{,_controls_minimal}_bitgen.tcl` | 从同一 v73 P&R DB 输出多音频候选 bit；不会自行做 P&R。 |
| `docs/media_1280x720_v71_v72_full_features_20260902.md`、`docs/v69_subtitle_bram_aligned_20260901.md` | 历史设计和验证证据；时间与当前 checkout 不同，必须标为历史记录。 |

### 固定技术条件

- 器件：`EG4S20BG256`；输入时钟 50 MHz；1280×720 视频时钟约 75 MHz。
- TF 使用既有 SPI 驱动，而非已经撤销的原生四线 SD 实验。当前可用物理映射为 A14/A13/B14/A12。
- BMP：TF 根目录直接放 `IMAGE0.BMP` 至 `IMAGE4.BMP`；24-bit、未压缩 BI_RGB，活动图片链支持最大 1920×1080，FPGA 按比例缩放、居中、黑边补齐。
- 字幕：主机端光栅化；包格式为 `55 AA | version | mode | width=800 | height=32 | payload_length=6400 | bitmap | CRC16`，完整 6411 字节。`mode bit7=1` 用于清除，帧边界生效。
- 音频（v73 候选）：`AUDIO0.WAV` 至 `AUDIO3.WAV`，标准 PCM WAV；`SW3=1` 时 KEY2 上一曲、KEY3 下一曲、KEY4 暂停/继续。非音频模式时 KEY2 切图/调自动速度、KEY3/KEY4 调亮度/对比度。

## 4. 已做出的关键决策

1. **图片稳定链与音频候选隔离。** v73 通过独立顶层和参数扩展 `top_v66`，而不是替换稳定 v72 结构；新功能必须保留回退路径。
2. **图片由 FPGA 自适应处理。** 用户明确不接受 PC 端强制统一拉伸；源 BMP 保留尺寸，由 FPGA 在加载期缩放。
3. **多图使用缓存而非切图时整图重读。** 五图预加载保证按键切换快；不要回退到读取时才加载整图。
4. **转场采用输出遮罩。** 不额外读取旧帧或增加 TF/SDRAM 带宽；OSD 保持可见。
5. **中文字幕由主机转位图、FPGA 双缓冲提交。** 不在 FPGA 中加入中文字库，避免半包和撕裂。
6. **不以约束豁免伪造时序通过。** 禁止为真实视频/SDRAM/音频路径添加 false path 或 multicycle 来掩盖违例。
7. **商品展示/原生四线 SD 已撤销。** 该方向曾板测出现 `1001`、`D1D1`、`D1D2`、`60B6`，用户决定停止试错并要求回退；没有新的用户授权不要恢复。

## 5. 已尝试但失败的方法

- **商品展示原生四线 SD。** 仿真曾覆盖 CMD8 有/无响应，但板上先后停在 `1001`、`D1D1`、`D1D2`；切回既有 SPI 后又出现 `60B6`。这没有得到可交付板级结果，用户已要求回退。只有重新获得明确需求、可观察的板级协议证据和独立测试计划时才重启。
- **未闭合时序就生成 bit。** 历史上多次 P&R 出现负 WNS；规则是 Setup/Hold WNS 必须非负、TNS 为 0 后才允许 bitgen。
- **简化 TD `.al` XML。** 曾导致 `PJR-8437: File ... info lost`；保留原有 FileInfo/AutoExcluded 结构，不能自创简化工程格式。
- **旧字幕 BRAM 读时序模型。** 把 Anlogic `NOREG` 当异步读会造成细字体错位/碎裂；v69 路径按实际单拍同步读语义处理，不能随意恢复旧逻辑。
- **切图临时从 TF 整图读取。** 用户体验约 1 秒延迟；保留多图缓存。
- **把图片所在文件夹整体复制到 TF 根目录。** 会破坏根目录短文件名匹配；只能直接放指定 BMP 文件。

## 6. 用户明确偏好

- 默认中文、结论优先、给出可执行的文件/命令/验证步骤；避免泛泛理论。
- 用户希望优先直接执行，只有会改变方案的关键歧义才提问。
- 偏好外科式最小修改；不要顺手重构稳定图片、字幕、OSD、转场或 bit。
- 必须区分源码检查、仿真、P&R、bit 和板测；不能把某一级的成功说成已上板成功。
- 用户明确认为近期 TF 问题应优先从软件排查；但所有解释、假设和附件中的结论仍需用代码、日志或测试验证。
- 未明确授权时不要 commit、push、烧录、删除或批量清理。最近一次完整回退/清理是用户明确授权的例外。

## 7. 隐性行为习惯与协作规则

- 先读 HANDOFF、检查当前 `git status`、活动顶层和约束，再判断工作状态；旧文档与当前文件冲突时以当前文件为准并指出差异。
- 已被用户确认稳定的路径视为冻结基线，新实验优先放在独立顶层/模块中。
- 每次非平凡修复先写清成功标准，随后运行最小有效测试；完成后说明改动、证据与用户如何验证。
- 可复现证据优先于直觉：源码、仿真输出、TD 日志、最终 timing report、hash、上板现象必须分层记录。
- 多个方案中优先选择资源/带宽最少、可回退且可验证的方案；不要因“未来扩展”添加抽象或依赖。

## 8. 用户纠正记录：不要再次犯的错误

- 不要把硬件现象归咎于等待时间、操作失误或未验证硬件；应先审查软件和实际证据。
- 不要把仿真模型通过说成板级协议已通过；原生 SD 实验已证明两者不同。
- 不要在未闭合 Setup/Hold 的设计上生成待烧录 bit。
- 不要把 v72 工程配置、v73 源文件、历史 release bit 和当前 P&R 结果混成同一个“当前版本”。
- 不要在未获授权时重启已撤销的商品展示/原生 SD 工作，或恢复其源码/bit。
- 不要自动提交、push，或把用户已有的脏工作区修改误纳入提交。
- 不要删除源级 testbench、当前脚本、回退产物或验证文档，除非用户明确要求；删除后必须说明范围和可恢复性。

## 9. 隐含约束

- 默认保持 1280×720、五图缓存、SDRAM 读出、顶部 OSD、亮度/对比度、既有按键和 UART 字幕行为。
- 新功能不得未经预算地增加 TF/SDRAM 带宽、时钟域或大型缓存。
- 自适应 BMP 必须保持格式检查、顶/底向上支持、四字节行对齐，加载失败不能覆盖已经发布的画面。
- 转场参数在一次切换开始时锁存，OSD 不得被转场遮罩覆盖。
- TD 构建脚本须从仓库根目录通过 PowerShell 管道执行；`td_commands_prompt.exe -tcl <script>` 不是本工程验证过的调用方式。

## 10. 已确认事实与推测

### 已确认

- `HEAD`、`origin/Yan_Chen0907` 和本地 `Yan_Chen0908` 当前都指向 `a8b9495`。
- `.al` 文件活动模块为 v72；v73 的 P&R 脚本显式指定 v73 顶层，故可独立运行但不会因打开工程自动成为顶层。
- 当前 `release/` 顶层中实际存在且 LFS 状态为本地可用的候选发布文件只有：
  - `hx4s20_1280x720_v73_multiaudio.bit`，629,662 bytes，LFS OID 前缀 `eb6a0f0850`；
  - `hx4s20_1280x720_v73_multiaudio_controls_minimal.bit`，629,662 bytes，LFS OID 前缀 `7b8dfbb898`。
- `release/_timing_failed/hx4s20_sdram_native_singleword_diag.bit` 也存在，但目录名已表明它不是发布候选。
- 10 个历史 release bit 在 Git LFS 中有记录但在工作树缺失，`git status` 将它们显示为删除；当前原因未经独立验证。
- 当前没有未跟踪的商品展示文件或 TD P&R 构建目录。

### 推测 / 暂定

- `a8b9495` 的 v73 多音频 bit 是否已在用户板上按当前提交验证，暂无当前轮可核验 P&R/板测报告；不能视为已验收。
- 缺失 LFS bit 是此前清理、LFS checkout 策略还是其他本地状态造成，暂无可靠根因；如需恢复应先保留现状并由用户决定是否运行 LFS 恢复。
- 如果再次需要商品展示，既有原生 SD 路线并不具备可复用的板级成功证据，应从新的需求和独立验证计划开始。

## 11. 当前项目状态快照

```text
分支：Yan_Chen0907（跟踪 origin/Yan_Chen0907）
提交：a8b9495
工程：hx4s20_800x600_multimedia.al
工程默认顶层：top_1280x720_feature_v72_resource_optimized
v73 候选顶层：top_1280x720_feature_v73_audio_visualizer
当前 P&R 目录：无
当前商品展示文件：无（已回退）
当前未提交改动：HANDOFF.md（本次生成）+ 10 个缺失 LFS release bit
```

缺失的 LFS release 文件：

```text
release/hx4s20_1280x720_v70_official_hdmi_clean.bit
release/hx4s20_1280x720_v70b_bandwidth_fix.bit
release/hx4s20_1280x720_v70c_bram_restart_fix.bit
release/hx4s20_1280x720_v71_full_features.bit
release/hx4s20_1280x720_v72_resource_optimized.bit
release/hx4s20_1280x720_v72_subtitle_continuous_scroll_v2.bit
release/hx4s20_1280x720_v73_audio_visualizer_no_center_line.bit
release/hx4s20_1280x720_v73_audio_visualizer_stable.bit
release/hx4s20_800x600_adaptive_v69_subtitle_bram_aligned.bit
release/hx4s20_800x600_feature_v57.bit
```

## 12. 下一步行动

1. 先读取本文件，运行 `git status --short --branch`，确认用户希望继续 v72、v73 还是另起新功能；不要默认恢复商品展示。
2. 若用户要使用/恢复历史 bit，先向用户说明上述 10 个 LFS 文件缺失；在用户同意后再通过 Git LFS 恢复，并核验文件大小与 SHA256。不要提交这些删除状态。
3. 若用户选择 v73，先阅读 `top_1280x720_feature_v73_audio_visualizer.v`、`sdram_bmp_row_top_v66.v`、v73 ADC/SDC、P&R 脚本和历史文档；再跑 RTL/仿真与完整 P&R。不要使用缺失的旧 DB 直接 bitgen。
4. 若用户选择 v72，先核实 `.al` 的活动顶层和 v72 约束/脚本，再针对目标问题作最小修改；保持 v73 候选隔离。
5. 所有需要发布的 bit 都必须从本轮闭合 P&R DB 生成，并交付最终 STA、文件大小、SHA256 和“硬件是否已测试”的明确状态。

## 13. 新 Agent 启动指令

> 你正在接手一个已有工作线程。
>
> 请先完整阅读本 HANDOFF，再开始工作。
>
> 默认信任其中标记为“已确认”的状态。
>
> 不要重复已经完成的工作、已经失败的实验或已经解决的问题，除非出现新的证据。
>
> 优先延续已有决策、用户偏好、工作方式和隐含规则。
>
> 在做重大修改前，检查是否违反：
>
> - 用户纠正记录；
> - 隐含约束；
> - 不要再次犯的错误；
> - 已确认的关键决策。
>
> 如果 HANDOFF 与当前实际文件状态冲突，以当前文件状态为准，并明确指出差异。
>
> 然后直接从“下一步行动”开始继续工作。
