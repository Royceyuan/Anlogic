# HX4S20 多媒体图片播放器交接

更新时间：2026-09-04  
适用目录：`D:\Anlogic_information\hx4s20_multimedia_main`

## 0. 2026-09-04 最新状态（优先于下方历史段落）

- 当前活动设计是 1280×720 HDMI 的 `top_1280x720_feature_v72_resource_optimized`，统一 TD 入口为 `hx4s20_800x600_multimedia.al`；活动约束为 `constraints\top_1280x720_v72_resource_optimized.sdc`，v69 仅保留历史回退。
- 本轮已完成的源码改动：修复 1280 宽 OSD 在 x=1024 处因 7-bit 字符索引回绕而重复绘制；增加 UART 字幕清除命令（mode bit7，帧边界生效）；主机脚本/GUI 默认滚动速度由 1 调为 3，并增加“关闭字幕”按钮。当前修改涉及 `src\video\osd_status_1280_pipe.v`、`src\video\uart_subtitle_overlay.v`、`tools\send_subtitle.py`、`tools\subtitle_sender_gui.py` 及对应仿真源。
- 定向仿真已通过：`tb_osd_1280_dimensions`、`tb_uart_subtitle_overlay`（含 CRC、滚动和 clear）、旧字幕链路回归及 Python 工具语法检查。清除命令 dry-run 生成 6411 字节包。
- 本轮源码尚无新的可发布 bit。上一份 release bit `release\hx4s20_1280x720_v72_resource_optimized.bit`（SHA256 `3226099D43AAE624BBAAB9AEA543901316902BC85701E0FD7CBBF1192D4DAA05`）不包含本轮改动，只能作为旧 v72 参考，不得声称已验证本轮功能。
- 工程已按队友交接要求做过可恢复精简：TD 构建目录、日志、ModelSim work、旧脚本/文档/约束和测试资产移至 `D:\Anlogic_information\_hx4s20_multimedia_main_cleanup_20260904`，清单为 `MANIFEST.csv`；工程目录保留约 10.7 MB。不要直接删除该归档，除非用户再次明确授权。
- 对本轮源码重新 P&R 的 seed 结果：seed 74 为 setup WNS `-0.546 ns`、hold `+0.024 ns`；seed 75 为 setup `-0.013 ns`、hold `+0.030 ns`；seed 76 为 setup `-0.013 ns`、hold `+0.030 ns`，均未满足 WNS 非负/TNS=0，因此禁止 bitgen 发布。本轮硬件状态 `NOT TESTED`。

## 1. 当前任务与最终目标

当前工作是维护一个可在安路 TD 中直接打开、可复现构建的 HX4S20 多媒体图片播放器工程。当前活动链路为 1280×720、75 MHz 视频时钟、五图缓存、SDRAM 读出、自适应 BMP、转场、顶部 OSD、亮度/对比度和 UART 字幕；后续音频/以太网必须隔离设计。

最终交付必须包括源文件可解析、仿真通过、综合/P&R/STA/DRC/bitgen 完整证据，以及用户实际上板完成冷启动、复位、切图、字幕和长显测试。编译或 bitgen PASS 不等于硬件 PASS。

## 2. 当前工作进度

### 已完成并有文件或测试证据支持

- 已将工程整理为唯一 TD 入口：`hx4s20_800x600_multimedia.al`。
- 当前顶层为 `top_1280x720_feature_v72_resource_optimized`；v69 顶层仍是 800×600 历史回退。
- TF 根目录接口为 `IMAGE0.BMP` 至 `IMAGE4.BMP`；BMP 自适应读取和 FPGA 内最近邻等比缩放保留在图像加载链中，当前 v72 输出 1280×720。
- 过渡效果支持 `SW3:SW1=000..110`，`111` 安全回退到淡入淡出；转场期间 OSD 保持可见。用户已反馈当前转场视觉效果很好。
- UART 字幕支持 800×32、2-bit 双缓冲、帧边界原子提交、静态居中和完整 1280 像素轨迹滚动；本轮加入 mode bit7 清除。默认主机速度为 3，仍可用 1..7 调节。
- 字幕上位机工具已保留：`tools\send_subtitle.py`、`tools\subtitle_sender_gui.py`、`tools\字幕发送器.vbs`、`tools\字幕发送器.bat`；GUI 的无反应、Tk 参数错误和启动脚本路径问题已修正。
- `sim` 中保留源级 testbench 和运行脚本，删除了生成的 work、transcript、波形和历史输出；不是删除测试源。
- 根目录、旧构建目录和日志已按用户要求清理；当前仍有少量历史版本脚本/源码用于追溯，不等于活动构建产物。

### 当前发布产物

- v72 旧参考：`release\hx4s20_1280x720_v72_resource_optimized.bit`  
  SHA256：`3226099D43AAE624BBAAB9AEA543901316902BC85701E0FD7CBBF1192D4DAA05`（不含本轮修改）
- v69：`release\hx4s20_800x600_adaptive_v69_subtitle_bram_aligned.bit`  
  SHA256：`2AA3F085E4E60F15898C2C15AAFBED1C1C79E6C35C1E77364EA4F8681CE6B75C`
- v57 回退：`release\hx4s20_800x600_feature_v57.bit`  
  SHA256：`8356C40343F98C9461245C48586AEB944AA4A07AF3E0115384812371C07B529F`
- `release\_timing_failed\hx4s20_sdram_native_singleword_diag.bit` 是历史诊断产物，不是发布 bit，不得作为当前版本或硬件通过证据。

### 验证状态

- v69 文档记录：ModelSim BPP1/BPP2、跨字节模式、UART OK/CRC reject/滚动均通过；综合 setup WNS `+1.709 ns`、hold WNS `+0.471 ns`、TNS 均为 0；P&R setup WNS `+2.974 ns`、hold WNS `+0.023 ns`、TNS 均为 0；最终 DRC 无 error。
- v65 转场回归记录：8 种模式、五图缓存切换和 1920×1080 自适应 BMP 回归通过；v65 P&R/STA 记录 setup WNS `+0.333 ns`、hold WNS `+0.030 ns`、TNS 为 0。
- 曾有一次统一 `.al` 的后台构建证据：综合 setup `+1.709 ns`/hold `+0.471 ns`，P&R setup `+1.569 ns`/hold `+0.037 ns`，输出目录和生成 bit 已删除，不能当成当前发布 bit 的新哈希或上板证据。
- 用户曾实际上板反馈图像、转场和字幕可用，但没有形成完整的冷启动、复位、五图全序列、串口收发和长时间显示记录，因此硬件状态保持 `NOT PASSED`/未完成完整验收。

### 尚未完成与当前卡点

- 音频、以太网尚未实现；需要另行做资源、时钟、引脚和带宽预算，不能直接侵入稳定图像读出链。
- v69 没有新的硬件冷启动/长显报告；下一步应由用户按测试清单实际烧录并记录现象。
- 当前卡点是本轮 OSD/字幕源码的 75 MHz setup 时序：最新 seed 76 setup WNS `-13 ps`、TNS `-13 ps`；必须先完成时序修正或找到合法闭合布局，再综合/P&R/bitgen。不要用 false path、multicycle 或删功能掩盖该路径。

## 3. 关键上下文

### 工程结构与职责

- `src\memory\top_1280x720_feature_v72_resource_optimized.v`：当前活动包装顶层。
- `src\memory\sdram_bmp_row_top_v66.v`：五图缓存、SDRAM 读写、按键/自动轮播、图像发布和状态链。
- `src\storage\fat32_image_loader.v`、`adaptive_row_ram.v`、`bmp_sdram_block_writer.v`：FAT32 根目录 BMP 解析、逐行缩放和写入。
- `src\video\video_transition_mask.v`：输出端组合遮罩；不读第二帧，不增加 TF/SDRAM 带宽。
- `src\video\uart_subtitle_overlay.v` 及 UART/字幕子模块：115200 接收、协议/CRC、双缓冲字幕和底部合成。
- `src\video\osd_status.v`、`osd_status_rgb888.v`：顶部 IMG/MAN-AUTO/亮度/对比度/DIM OSD。
- `constraints\top_1280x720_v72_resource_optimized.sdc`：当前活动 SDC；PR 脚本仍读取历史兼容 ADC `constraints\top_800x600_adaptive_v66_uart_subtitle.adc`。
- `scripts\run_media_1280x720_v72_resource_optimized_{syn,pr,bitgen}.tcl`：当前构建入口；历史 PR build root `_media_1280x720_v72_resource_optimized_r3` 已移至工程外清理归档。
- `docs\v65_multi_transition_20260901.md`、`v66_uart_subtitle_20260901.md`、`v69_subtitle_bram_aligned_20260901.md`：对应版本设计/验证记录。

### 固定接口和参数

- 器件：`EG4S20BG256`；当前视频目标 1280×720 HDMI，视频 PLL 75 MHz；800×600/40 MHz 为早期稳定基线。
- 自适应 BMP 实际 v69 参数为最大 `1920×1080`，支持 24 位、未压缩 Windows BMP，顶向下/底向上和四字节行对齐；输出按比例缩放、居中、黑边补齐，不拉伸不裁切。计划讨论中曾说“1k 上限”，后来用户明确选择 1080p 级图片，实际活动 RTL 以 1920×1080 为准。
- `SW4=0` 手动；`SW4=1` 自动轮播；`KEY2` 切图；`KEY1` 复位；`KEY3/KEY4` 调亮度/对比度。转场拨码只在一次切图开始时锁存。
- 转场：000 淡入淡出；001 左右擦除；010 上下擦除；011 四条百叶窗；100 棋盘；101 中心向外；110 对角线；111 回退淡入淡出。011/100 已为可见性调慢，棋盘约 0.9 s，其余展开约 0.6 s，具体以活动 RTL 为准。
- USB1 板载 CH340：FPGA `uart_rxd=F12`、`uart_txd=D12`，115200 8N1。用户当前使用 `COM8`；VOFA 或其他串口助手占用 COM8 时，先关闭占用程序。
- 字幕协议当前为 v67/v69 2-bit 格式：`55 AA | version | mode | width=800 | height=32 | payload_length=6400 | bitmap | CRC16`，每行 200 字节，最高位对应最左像素；完整包 6411 字节。`mode bit7=1` 为清除字幕，提交仍在帧边界完成；旧 v66 bit 需显式使用 `--format v66`。
- v69 关键修正：Anlogic `EG_LOGIC_BRAM` 即使 `NOREG` 也表现为读时钟边沿采样；旧模型将其当异步读，造成像素索引与字节错一拍、细字体碎裂。v69 直接消费这一拍输出并保留 UART 回复修正。

## 4. 已做出的关键决策

1. **保留 800×600 作为历史稳定回退，同时当前活动链转为 1280×720。** v70/v71/v72 逐步复用官方 HDMI 时序并修正 SDRAM/BRAM 对齐；任何新改动仍必须能回退到 v69/v57。
2. **缩放放在 FPGA 加载期，主机只负责把原图保存为 BMP。** 这样保留源图尺寸信息，避免把所有图片预先拉伸成 800×600；最近邻是当前资源和时序可接受的质量基线。
3. **多图采用预加载/缓存而不是切图时临时读一整张图。** 五图缓存换取快速按键响应；不能随意改回慢速单帧加载路径。
4. **转场只做输出遮罩。** 不读取旧帧、不增加 SDRAM/TF 带宽、不改变帧边界发布；OSD 保持可见。真正的旧帧/新帧混合留作后续独立功能。
5. **中文由上位机光栅化。** FPGA 不内置完整中文字库；字幕双缓冲并在帧边界提交，避免半条消息和撕裂。2-bit 字幕优先解决 1-bit 细笔画显示质量和 BRAM 资源问题。
6. **统一 `.al` 保留 TD 的 `FileInfo` 结构和 AutoExcluded 历史源。** 曾尝试简化 XML，导致 TD `PJR-8437: File ... info lost`，因此不能改成自创简化工程格式。
7. **保留历史回退 bit，活动 v72 只有在本轮源码重新闭合后才能更新。** 旧 v72 bit 的 SHA 只代表旧源码；本轮 OSD/字幕改动不能复用旧 bit 的验证结论。

## 5. 已尝试但失败的方法

- v51～v55 的高分辨率/旧缩放和逐行写入路径：出现撕裂、重影、花屏、黑条、无信号或复位敏感；除非有新的时序/仿真证据，不应重新切回。
- v58 候选：硬件表现比前一版差，按键响应慢，最右侧虚线/黑条问题明显；未作为活动版本。
- 直接在切图时从 TF 读取整图：KEY2 响应约 1 s；后续改为多图预加载/缓存，切换明显改善。
- 旧字幕 BRAM 模型/额外字节寄存器：细字体呈碎条、静态也撕裂；根因是 `NOREG` 同步读语义理解错误，v69 已修正。只有在更换 BRAM 原语或仿真模型时才值得重新评估。
- 旧 GUI 启动方式：VBS 使用错误路径或隐藏窗口会导致“双击没反应”；Tkinter 曾有 tuple `pady` 和重复 `text` 参数错误。当前应沿用已修正的 `FileSystemObject.BuildPath`、可见窗口和现有 GUI。
- 把图片文件夹整体复制到 SD 卡根目录：会破坏根目录文件查找，用户明确要求不要这样做；必须直接复制 `IMAGE0.BMP`～`IMAGE4.BMP` 文件。
- 一次统一 TD 后台构建生成的 `Runs`/日志/bit 已删除，不能因曾经有输出就声称当前 bit 已重新验证。
- ModelSim 遗留 `vish/vsimk` 进程曾锁住 `sim\transcript`；进程已终止，生成物已清理。若仿真再次锁文件，先检查残留进程，不要盲目改 RTL。

## 6. 用户明确表达过的偏好

- 使用中文，先给结论，再给少量必要操作；重视可执行路径、命令、端口和状态，不喜欢泛泛而谈。
- 倾向直接执行，除非存在会改变方案的关键歧义；修改后说明改了什么、为什么、如何验证。
- 偏好最小、外科式修改，保持现有稳定画面、切图速度、OSD 风格和操作习惯；不希望为了“顺便优化”引入大范围重构。
- 关注实际观感：无撕裂、无虚线/黑条、字幕实心纯白、中文可读、静态居中、转场有冲击力但切图要快。
- 不希望每次通过难记的终端命令操作字幕，更喜欢双击即可打开的 GUI；串口当前是 COM8。
- 明确要求清理无用测试工程、日志和冗余 bit；同时保留真正有用的源级 testbench、当前 bit、回退 bit和文档证据。
- 未授权时不自动烧录或宣称硬件通过；希望把综合/P&R/仿真结果与实际板测分开写。

## 7. 隐性行为习惯与“肌肉记忆”

- 先核对当前实际文件和活动顶层，再动手；不要根据旧聊天中的版本名猜测目录状态。
- 已由用户确认“很好/稳定”的路径视为冻结基线；后续功能从包装层或独立模块增加，避免回改图像读出核心。
- 任何诊断、假设和用户附件中的方案都只是待验证信息；用源码、仿真、日志、时序和板测分层证明。
- 每次改动都给出明确成功标准和验证顺序；不要把“能综合”当成“上板正确”。
- 遇到多个可行方案，优先最小资源、最小带宽、可回退、可验证的方案；不要为了扩展性提前堆配置。
- 用户通常希望得到能直接照做的下一步，而不是长篇理论；但涉及风险时要明确指出限制和未验证项。

## 8. 用户纠正记录与“不要再次犯的错误”

- 不要把源图片在 PC 端统一缩放后再放卡；自适应需求是保留原始尺寸，由 FPGA 加载期缩放。
- 不要把图片文件夹塞进 SD 卡根目录；根目录直接放 `IMAGE0.BMP`～`IMAGE4.BMP`。
- 不要把 v58 的慢切图、边缘虚线/黑条或不稳定现象带回当前版本；v57/v69 的快速缓存路径优先。
- 不要把字幕层放到会遮住顶部 OSD 的位置；底部 `y=568..599`，顶部 IMG/DIM 始终可见。
- 不要把 1-bit/错误 BRAM 时序模型当成已解决方案；细字体必须按当前 v69 同步 BRAM 语义验证。
- 不要让滚动字幕和静态字幕共用未经验证的对齐逻辑；静态必须居中，滚动必须完整且不撕裂。
- 不要用隐藏窗口的 bat/VBS 代替用户可见 GUI；双击无反应时先修启动路径和窗口样式。
- 不要把 LED、数码管一次亮起或单次烧录有画面解释成完整硬件通过；必须记录冷启动、复位、切图、串口和长显。
- 不要删除当前源级 testbench、活动脚本、发布 bit、回退 bit或验证文档；删除前必须有用户明确授权。
- 不要残留已删除目录的引用；当前实际文件状态与旧文档冲突时，以文件系统为准并明确指出。

## 9. 隐含约束

- 保持 800×600、4:3、40 MHz HDMI、五图缓存、SDRAM 读出、顶部 OSD、亮度/对比度和现有按键定义。
- 新功能默认不增加 TF/SDRAM 访问，不改变图片帧边界发布，不引入未经预算的实时乘法/大缓存。
- 自适应 BMP 必须保持 24 位 BI_RGB、顶/底向上、行四字节对齐、合法尺寸检查和失败时不覆盖当前已发布画面。
- 转场模式由切图开始时锁存，切换拨码不能在转场中途变形；OSD 不被遮罩。
- UART 字幕必须帧边界原子替换，接收期间显示旧字幕；COM8 资源可能被 VOFA 独占。
- TD `.al` 的 FileInfo/路径属性结构必须保留；不要用简化 XML、不要引入 false path/multicycle 掩盖时序。
- 音频/以太网后续必须与图像链隔离设计，并先做资源、时钟、引脚和带宽预算。

## 10. 已确认事实与推测分离

### 已确认

- 当前唯一 TD 工程、活动顶层和 v72 源路径如上所列；release 中的 v72 SHA 是本轮改动前旧 bit，不能代表当前源码。
- v69 文档中的仿真、综合、P&R、STA、DRC 结果存在；`TNS=0`，记录的 WNS 为正。当前 v72 本轮源码的仿真通过，但 P&R setup 仍为负。
- 用户已反馈当前转场、五图切换和字幕观感良好；静态字幕已要求并实现居中。
- 当前项目根目录不再保留 TD 构建目录和 TD 日志；`sim` 仅保留 v72/OSD/UART/转场等必要源级测试文件和脚本；历史证据在工程外可恢复归档中。
- 用户当前串口为 COM8；板端 UART 管脚为 F12/D12。

### 推测 / 暂定

- 用户之前偶发“连续烧录前两次无现象、第三次有现象”的完整根因尚未被单一实验确认，不能归因于某一个复位或烧录时序。
- 当前 v69 上板观感良好不等于完成冷启动和长时间可靠性验收。
- 统一 `.al` 的后台构建时序差异可能来自构建环境/约束或工具状态；生成物已删除，若要发布必须重新跑完整流程并保留新证据。
- 音频和以太网的可行资源余量暂无可靠信息，必须先查器件资源和现有 P&R 报告。

## 11. 当前项目状态快照

当前根目录应为：

```text
constraints/  docs/       release/  scripts/  sim/
src/          test_media/ tools/    vendor/
FPGA_DIAGNOSTIC_BRIEF.md  HANDOFF.md  PROJECT_INDEX.md  README.md
hx4s20_800x600_multimedia.al
```

当前重要文件：

- 工程：`hx4s20_800x600_multimedia.al`
- 活动 RTL：`src\memory\top_1280x720_feature_v72_resource_optimized.v`
- 活动约束：`constraints\top_1280x720_v72_resource_optimized.sdc` 和兼容 ADC
- 活动脚本：`scripts\run_media_1280x720_v72_resource_optimized_syn.tcl`、`_pr.tcl`、`_bitgen.tcl`
- 当前 bit：release 中旧 v72 参考 bit，不包含本轮源码修改；新 bit 尚未生成
- 回退 bit：`release\hx4s20_800x600_feature_v57.bit`
- 字幕工具：`tools\subtitle_sender_gui.py`、`tools\字幕发送器.vbs`
- 诊断/索引：`FPGA_DIAGNOSTIC_BRIEF.md`、`README.md`、`PROJECT_INDEX.md`

当前未保存的重要改动：暂无可靠信息。注意，TD 重新运行后会生成 `Runs`、日志和中间文件；这些是构建输出，不应误当源码，也不要在构建未取证前删除。

## 12. 下一步行动

1. 先检查本文件所列 v72 活动顶层、源码时间戳和 seed=76 的最新报告；历史 PR root 已移至工程外归档，不要把旧 v72 release bit 当成本轮结果。
2. 保留并复跑已通过的 `tb_osd_1280_dimensions`、`tb_uart_subtitle_overlay` 和工具 `py_compile`；不要重复已排除的 v58/旧 BRAM 路径。
3. 针对当前 75 MHz 负 setup 路径先做最小 RTL 时序修正；优先检查 `video_transition_mask` → OSD `rgb_s1` 和字幕滚动 BRAM 地址路径。禁止用 false path/multicycle 掩盖真实视频数据路径。
4. 源码修正后依次运行综合 → P&R → STA/DRC；只有 setup/hold WNS 非负且 TNS=0 才运行 v72 bitgen，并重新计算 SHA256。
5. 生成新 bit 后，明确标记 `Hardware status: NOT TESTED`，交给用户在 1280×720 下检查 OSD 不重复、字幕全屏滚动、关闭字幕、五图切换和长显。
6. 若开始音频或以太网，先单独列资源/时钟/引脚/带宽预算，优先做隔离模块或候选包装顶层，不直接改动已稳定的 SDRAM/HDMI 图像读出路径。
7. TD 重新生成的构建目录和日志是证据；清理前先保留报告、状态和 hash，并确保本文档与文件系统同步。

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
> - 用户纠正记录
> - 隐含约束
> - 不要再次犯的错误
> - 已确认的关键决策
>
> 如果 HANDOFF 与当前实际文件状态冲突，以当前文件状态为准，并明确指出差异。
>
> 然后直接从“下一步行动”开始继续工作。
