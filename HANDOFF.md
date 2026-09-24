# HX4S20 多媒体工程交接

更新时间：2026-09-23
适用目录：`D:\VSCode\CodeFiles\Git_TD\Anlogic`
当前分支：`Yan_Chen_Double`，跟踪 `origin/Yan_Chen_Double`。
主板 MAIN-2 板测基线提交：`ad81b59`；MAIN-3 在其上增量开发，以 `git status --short --branch` 为准。

## 1. 当前任务与最终目标

MAIN-0、MAIN-1、MAIN-2 均已由用户确认板测通过。当前实施 MAIN-3 交互、故障恢复与顶部状态面板；MAIN-3 的 RTL/仿真/P&R/bitgen 不等于板测通过，须等用户明确回复 `MAIN-3 BOARD PASS`。

本工程的稳定目标是 HX4S20 (`EG4S20BG256`) 上的 1280×720 HDMI 多媒体图片播放器：TF 卡读取 BMP，五图缓存和快速切换，转场、亮度/对比度、顶部 OSD、UART 中文字幕，以及 v73 候选中的 WAV 音频和音频波形可视化。

完成某个版本的交付必须同时具备：RTL/仿真证据、完整综合/P&R/STA/DRC 闭合、可追溯 bit 和用户板测。综合或 bitgen 成功不等于板级通过。

## 2. 当前工作进度

### 已确认

- 主板 RTL 基线提交 `cfd5b70` 为 `fix: make product show FSM authoritative so KEY2 only pauses`；其后的 MAIN-0 审计、清理和板测记录提交不改变该 RTL 基线。
- 历史 v72 图片链和 v73 音频候选源均在当前 checkout 中；`src/memory/sdram_bmp_row_top_v66.v` 是共同的媒体核心。
- 当前唯一 TD 工程为 `hx4s20_800x600_multimedia.al`。活动顶层为 `top_1280x720_main3_interaction`；MAIN-2/MAIN-1/v72 顶层和已板测 bit 均保留作为回退。
- 工程目标器件为 `EG4S20BG256`；输入时钟为 50 MHz。
- 活动 ADC 为 `constraints/top_1280x720_v73_audio_visualizer.adc`，活动 SDC 为 `constraints/top_1280x720_main3_interaction.sdc`；ADC 中的 HDMI1、DDC、TF/SPI、按键、拨码、LED、数码管和 VGA 管脚与板卡资料一致。
- 当前工程包装顶层启用 1280×720、960×540 源帧、五图缓存、TF/SPI、SDRAM、OSD、UART 字幕、转场和音频参数接口；v72 包装未启用 v73 音频可视化。
- v73 独立包装顶层 `src/memory/top_1280x720_feature_v73_audio_visualizer.v`、ADC/SDC 及完整 P&R 脚本存在。该包装以 `top_v66` 启用五图、1280×720、UART 字幕和音频可视化。
- 用户确认主板 HDMI、TF、SDRAM、按键、SW4、音频硬件和烧录/板测条件均可用；五件文物的全貌图和每件三张细节图已准备并转换到 TF 卡。
- 本轮之前创建的商品展示顶层、原生四线 SD 状态机及相关实验仍不属于当前主线；除非用户再次明确提出，不要恢复或继续该实验。

### 未完成 / 当前卡点

- 2026-09-19 已按用户要求删除历史 `_build_v73_*`、`work_*`、旧 TD 运行目录/日志、根目录报告、备份 patch、minidump 和 `.bid` 生成物；源码、仿真入口、现行脚本、发布 bit 和设计文档保留。
- v73 的 `build_v73_audio_visualizer_bitgen.tcl` 与两个多音频 bitgen 脚本都依赖缺失的 `_build_v73_audio_visualizer/v73_audio_visualizer_pr.db`；不能直接运行它们生成可信 bit。
- 当前 `release/` 中保留历史 v70/v71/v72/v73 bit；`release/hx4s20_1280x720_v72_subtitle_continuous_scroll_v2.bit` 已完成 MAIN-0 板测，`release/hx4s20_main1_overview.bit` 已完成 MAIN-1 板测。
- ModelSim 安装在 `D:\Modelsim`，Tang Dynasty 安装在 `D:\TD_6.2.1`；后续仿真和 P&R 使用这两个明确路径，不依赖 PATH。
- 本轮 v72 连续字幕包装已完成综合、布局布线、最终 STA、DRC 和 bitgen；未跟踪构建目录与报告按用户要求保留，不提交。

### MAIN-1 总览选择（2026-09-19，板测通过）

- **行为实现：完成。** `SW1:SW2=00` 显示五件文物横向五栏总览；每栏源区域为 `192x540`，经既有 960x540→1280x720 缩放后占 `256x720`，五栏从左到右相邻铺满画面且不裁纵向。2026-09-19 首次板测确认画面内容正确，随后按照片反馈把左右双画边框改为全局单条 1 像素接缝，并让竖线覆盖顶部 OSD 区，消除顶部断线和相邻栏灰黄双线耦合。选中框为 2 像素：1 像素直接替换公共灰线，另 1 像素只向选中图片内部扩展。默认高亮 0，KEY3 下一件、KEY4 上一件，KEY2 仅在五张图均有效后确认；选择索引在视频帧边界发布，确认后边框由黄色短暂变为绿色。
- **合成策略：完成。** 加载五张完整 960x540 RGB565 帧时，行写入器同步截取各图可配置的 192 像素宽 ROI，写入第六个 960x540 SDRAM 合成帧。当前五个裁剪起点暂为居中 `x=384`；最终文物素材到位后只需调整 `top_1280x720_main1_overview.v` 中五个 `OVERVIEW_CROP_X0_*` 参数。
- **容量/带宽：通过预算。** 六帧共 `6,220,800` bytes，占 8 MiB SDRAM 的 `74.16%`；总览显示仍只读取一路 960x540 帧，不增加显示侧持续 SDRAM 吞吐。旧 `64x48` 缩略图 BRAM 已移除，MAIN-2 讲解流程未提前实现。
- **仿真：通过。** `sim/run_museum_overview_main1.do` 覆盖选择回绕、媒体就绪门控、帧边界 CDC、完整帧与横裁合成帧地址、单像素公共接缝、顶部连续性、边框、无效占位和旁路；既有 1920x1080→960x540 自适应 BMP 回归也通过。各仿真实例 ModelSim 10.6e 均为 `Errors: 0, Warnings: 0`。
- **综合/P&R/STA：通过。** `_build_main1_overview/main1_overview_pr.status` 报告最终 Setup WNS `+114 ps`、TNS `0 ps`，Hold WNS `+23 ps`、TNS `0 ps`；STA 覆盖率 `99.91%`，时序例外为空，DRC 无多驱动、异常路径或拥塞溢出。放置后资源为 LUT 13636/19600（69.57%）、寄存器 5602/19600（28.58%）、BRAM9K 22/64（34.38%）、BRAM32K 4/16（25.00%）、DSP 6/29（20.69%）；最终 7451 slices（76.03%）。
- **位流：板测通过。** `release/hx4s20_main1_overview.bit`，629648 bytes，SHA256 `034632F43E5ACF86E094D1E3D85A0A0F2E99FA4C2D592232D3D4D7FD1D0130D6`。2026-09-19 用户明确回复 `MAIN-1 BOARD PASS`；2 像素选中框、单像素普通接缝、顶部连续性和画面稳定性通过验收。工具仍报告与 MAIN-0 相同的 SDRAM 25 MHz 相移时钟本地路由警告，但最终时序和板测均已通过。
- **MAIN-2 图片素材：已写入 TF 并校验。** 文物索引 0～4 依次为越王勾践剑、四羊方尊、金缕玉衣、马踏飞燕、长信宫灯；全貌图为 `IMAGE0.BMP`～`IMAGE4.BMP`，三张细节图为 `ART0D1.BMP`～`ART4D3.BMP`。2026-09-20 已取消 PC 端强制拉伸和边缘延展，20 张源图保持宽高比、仅在超过 1920×1080 时等比缩小；当前方形素材输出为 1080×1080、24-bit、未压缩 BI_RGB，由 FPGA 自适应到 960×540 源画布并用深色博物馆背景补边。上一版已备份到 `E:\BACKUP_MAIN2_BEFORE_ADAPTIVE_20260920`，生成脚本为 `tools/prepare_museum_images.py`。

### MAIN-2 主屏讲解（2026-09-23，已上板通过）

- **拨码预载与进入门控：完成。** MAIN-2 不再用高亮变化触发预载；`SW3:SW2:SW1=000/001/010/011/100` 分别选择文物 0～4，`101`～`111` 无效，SW4 保留。总览态先缓存当前文物四张图、对应 WAV 和 TF 字幕包；五个物理图片槽中，槽 0/4 轮换保存当前与下一文物全貌，槽 1/2/3 在画面离开对应细节后复用。这样讲解期间仍可滚动预载下一件，同时当前全貌保留到返回转场完成。KEY3/KEY4 仍移动高亮；高亮与拨码选择一致、四张图和对应音频均就绪，且有效字幕包已读到首条记录时，KEY2 才进入讲解；字幕缺失或格式错误保持非阻塞。为避免同一文物第二次进入时音频先于字幕重载完成，字幕就绪使用独立门控，不再并入共享 `audio_prepared`。图片完整预载若遇到一次瞬态读错会自动从槽 0 重试一次，第二次仍失败才锁定错误，避免无限读盘。2026-09-20 已修复 WAV/字幕根目录跨簇查找；实测 E 盘五个 `SUB*.BIN` 结构有效，头部总帧数均与对应 `AUDIO*.WAV` 完全一致。
- **退出后偶发不预载/字幕不重现：已上板通过。** 2026-09-23 用户确认铜奔马、四羊方尊等文物都可能在中途退出、再次讲解后出现无字幕或切换拨码不预载，触发步骤不限于 KEY3 连按。检查发现音频或字幕读扇区中途被重启时，共享 SD 仲裁器仍可能把旧扇区数据/结束脉冲交给已开始新请求的读取器。现在仲裁器把中止的旧扇区标记为失效，等物理扇区结束后才受理新请求；字幕的跨时钟提交/确认状态也在重启时重新对齐。ModelSim 覆盖音频、字幕中止读盘，同一文物提前退出再进入、连续讲解，以及退出时下一文物图片仍在加载的情形，均通过；用户于 2026-09-23 回复 `MAIN2 PASS BOARD`。
- **无缝进入、音画同步与控制：已上板通过。** KEY2 接受后直接从总览转到已缓存全貌。WAV 以播放器实际消耗的 PCM 帧为唯一时间基准；`SUB*.BIN` v2/v3 头部提供由每件文物 `图片切换脚本.md` 换算出的四个 PCM 切换点，固定按“全貌→细节 1→细节 2→细节 3→最终全貌”播放，MD 中的图片名不改变槽位顺序。2026-09-21 板测后按用户要求把文物 0 恢复为上一版等五段画面时序，四个切点为 583488/1166976/1750464/2333952 PCM 帧；文物 1～4 的图片切点不变。最后全貌显示期间音频继续播放，最后一个 PCM 帧送出后再稳定等待 1.2 秒并收拢回概览。KEY2 暂停/继续；KEY3 立即停止音频并经全貌回概览，不等待自然结束的 1.2 秒。旧版 v1 字幕包或未启用 TF 字幕时保留原等五段回退。
- **四羊方尊音频：已修复素材根因，已上板通过。** 原 `素材\02_四羊方尊\讲解音频.wav` 和 TF `AUDIO1.WAV` 都只有约 32.24 秒，而对应 SRT 到 76.1 秒，且文件尾仍有明显非零波形，确认是源音频被截断而不是 TF 吞吐或 RTL 提前结束。已用完整讲解文稿生成并写入新的 48 kHz、PCM16、双声道 `E:\AUDIO1.WAV`，时长 74.2955 秒，SHA256 `D4F732200267A7AE4D2801CEB6928B5A23139AFA7545A682344D0770DA0A6042`；旧文件备份于 `E:\BACKUP_AUDIO_BEFORE_REPAIR_20260920\AUDIO1.WAV`。
- **TF 字幕：新版 v3，已上板通过。** `tools/generate_museum_subtitles.py` 仍从五份 `字幕.srt`、`图片切换脚本.md` 和同编号 `AUDIO*.WAV` 生成 TF 根目录 `SUB0.BIN`～`SUB4.BIN`；无需电脑实时发送，也不把文物文字固化进 FPGA。新版每条记录预渲染 800×32 白色字芯和 1 像素黑色描边两个位平面，画面背景透明，沿用 2×2 有序淡入淡出。文件头版本 3、2 bpp、6400 字节位图、每条 13 扇区；FPGA 仍兼容旧 v1/v2 包，但旧包只有白字、没有描边。E 盘五包已更新，旧包完整备份在 `E:\BACKUP_SUBTITLES_BEFORE_OUTLINE_20260923`，并逐文件 SHA256 校验；五件文物的音频总帧数、四个画面切点和全部逐句起止时间与旧包完全一致。新版包 SHA256：SUB0 `D5623130DCA199DB2281EA0EDEBCAE85FA0BA864F53C57C2CE9B7C2C89D3A1C6`、SUB1 `96F9F33A2A70C02988625AA7C80E5C884C629FF49E707DE01C98D32A70B5868A`、SUB2 `727BFF2EE26425809EBBA5506A7892F8DB38D94FEE234E31AA90A048F875992E`、SUB3 `7321BF3D9BCA6366B40CB88191B40C4BCC0C037091B7BBF34D31A3BF7B2C4775`、SUB4 `950E73D940F752C9C701E47B30E974D593BF73FA99BD7AA72C5B031107134108`。更换音频时仍要重校准 SRT/MD，不能靠全局同比缩放掩盖局部错位。
- **转场/画面参数/OSD：已上板通过。** MAIN-2 总览→全貌仍使用约 2.13 秒的“未选栏淡出、选中栏移到中央、再从裁剪区向左右恢复全貌”；返回时严格反向收拢。全貌→细节 1 保留帷幕，细节 1→2、2→3 保留淡入淡出；细节 3→最终全貌使用中心向外扩张的菱形爆发遮罩。菱形仍为原32级几何步进，改为每2个视频帧推进1步，按60 Hz约持续1.07秒，其他转场速度不变。KEY4 在讲解期间不会改变画面；KEY1 循环切换中性、提亮、高对比、偏暗柔和四组真实亮度/对比度参数。音频柱状可视化保持开启；进入概览、无音频或暂停时立即隐藏并清空旧波形，恢复播放后只显示新采样形成的完整一帧。调试 OSD 面板仍关闭。
- **仿真：通过。** `tb_museum_lecture_controller` 覆盖五阶段流程、连续讲解、提前退出、退出时后台图片读盘未结束以及随后再切换文物；`tb_museum_subtitle_overlay` 覆盖 v3 双位平面、跨簇读取、白字黑描边、透明背景、淡入淡出、提交途中退出、同一文物再次讲解；`tb_sdram_bmp_row_top_chain` 新增音频/字幕扇区中止与下一请求回归；其他既有音画、转场和自适应 BMP 回归维持。相关 ModelSim 编译无错误，三个定向测试均 PASS。
- **资源与 P&R/STA：通过。** `_build_main2_lecture_outline_fix/pr.status` 使用布局种子 76，Setup WNS `+155 ps`、TNS `0`，Hold WNS `+23 ps`、TNS `0`，0 违例。LUT 12674/19600（64.66%）、寄存器 7751/19600（39.55%）、BRAM9K 47/64（73.44%）、BRAM32K 4/16（25.00%）、DSP 7/29（24.14%）；最终 7249 slices（73.97%）。描边额外使用 2 个 BRAM32K，没有增加 BRAM9K；保留既有 SDRAM 相移时钟本地路由警告，须以板测确认。
- **已板测 bit：** `release/hx4s20_main2_lecture.bit`，629647 bytes，SHA256 `AA788DDEEC1FE2D40B57DB16E9243513A6C20B034497F9C006B70D39784F39C9`。

### MAIN-3 主屏交互与状态面板（2026-09-23，待上板）

- 在 MAIN-2 板测通过的媒体链上新增独立顶层 `top_1280x720_main3_interaction`；`ENABLE_MAIN3=0` 的旧顶层保持原行为，`release/hx4s20_main2_lecture.bit` 保留回退。
- KEY1 在标准、明亮、高对比、柔和四组亮度/对比度参数间循环；KEY2 总览确认、讲解暂停/继续；KEY3 总览按 0→4 回绕高亮，音频讲解中在 1×/2×中心裁剪缩放间循环，不再提前返回；音频结束时恢复 1× 后沿用原收拢转场；KEY4 是应用级故障恢复，不再选文物。高亮变化不发起预载，SW1～SW3 仍决定预载，且必须与高亮和有效素材匹配才能进入讲解。
- 暂停冻结图片阶段、转场、字幕淡入淡出及自然结束后的约 1.2 秒停留，音频进度停止，波形立即隐藏归零；SDRAM 扫描/刷新与后台预载不中断。KEY1 在暂停时仍能调参，KEY3 可切换缩放倍率（实际画面于继续后帧边界更新），KEY4 可恢复退出。
- KEY4 首先静音，等待已接受的 SDRAM 写突发补零收尾；随后只复位 SD 核及图片/WAV/字幕读盘客户端和仲裁状态，不复位 PLL、HDMI 或 SDRAM 控制器。完整总览缓存保留，不完整则重建；SD 卡重新初始化后依据当前有效拨码重预载。无效拨码只显示默认高亮 0，不预载；初始化超时数码管显示 `E503`，再次 KEY4 可重试。
- 顶部居中 960×56 半透明黑色 OSD 显示 TF 文物名称、实际展示阶段、画面预设、源 BMP 宽高及实际显示的 `ZOOM1x/ZOOM2x`。名称由 TF 根目录 `OSDNAME.BIN` 提供，缺失/损坏显示“文物 0～4”而不阻止讲解；更换名称不需重编 bit。名称包为 512-byte `ONAM` v1 头和五个 512-byte 位图区，总长 3072 byte；各位图 160×16、1bpp、高位先行。由 `py tools/generate_museum_osd_names.py --dest E:\OSDNAME.BIN` 生成，仅更改名称文件，不改 WAV/SUB 时间轴。
- MAIN-3 不包含以太网和应急抢占；波形的应急红色控制输入在本阶段固定关闭。主副板交互协议仍以 `docs/副屏工程启动与双板以太网接口约定_20260923.md` 为准。
- 仿真入口：`sim/run_main3_recovery.do`、`run_main3_zoom.do`、`run_museum_status_osd.do`、`run_museum_name_loader.do`、`run_museum_writer_abort.do`；MAIN-2 讲解、字幕、总览与 SD 中止读盘回归也通过。三种名称情形（有效跨簇、缺失、损坏）均 PASS，OSD 像素对齐与字形、KEY4 状态顺序、重复按键隔离及读卡初始化超时后重试、写突发补零均 PASS。2026-09-24 板测反馈连续讲解及 KEY4 后重载仍可能无字幕；已定位并修复字幕视频侧仅在取消上升沿对齐提交位的缺陷，改为整个取消期间持续对齐。新增复现测试先在旧逻辑失败，再在修复后覆盖同一文物重入、KEY4 仅复位 50 MHz 客户端、重新读包与首条字幕显示，均 PASS；用户随后上板重试两轮确认 KEY4 正常。KEY3 新缩放测试覆盖总览高亮保持、讲解中 1×/2×、帧边界显示与退出后清零，OSD 字符测试覆盖倍率显示；当前新 bit 仍待板测。
- **工具链候选，未板测。** `D:\TD_6.2.1` 最终 P&R/STA setup WNS `+135 ps`、TNS `0`，hold WNS `+23 ps`、TNS `0`，覆盖率 99.77%，时序例外为空；bitgen 完成。单独执行 `drc_check -all` 与 `report_route_status -drc`，无多驱动、无异常时序路径、路由开放网络 0；保留既有 SDRAM 25 MHz 相移时钟使用一段本地路由的工具警告，须板测确认。综合 LUT `13717/19600`（69.98%）、REG `8619/19600`、BRAM9K `48/64`、BRAM32K `5/16`、DSP `7/29`；放置后的 LUT `13955/19600`（71.20%），路由使用 `8002/9800` slices（81.65%）。相比 MAIN-2，BRAM9K +1、BRAM32K +1、DSP 不变。超过原 Slice 80% 的软目标，用户已允许资源足够时适当增加；不能以此代替上板稳定性验证。
- **待测发布文件：** `release/hx4s20_main3_interaction.bit`，630815 bytes，SHA256 `21817DA1CC02CD47210AF9F051FAEF74C95CA97B5620DE080ED6813263770B6D`。`release/media/OSDNAME.BIN` 与此前核验的 `E:\OSDNAME.BIN` 均为 3072 bytes、SHA256 `600E64D69B35F29B955D43DEA67C93F194C8A0317C6E5BD0DDC05A8F8B268029`；本轮未检测到 E 盘，未重新核验 TF 内容。MAIN-2 bit 的 SHA256 保持 `AA788DDEEC1FE2D40B57DB16E9243513A6C20B034497F9C006B70D39784F39C9`。上板步骤见 `docs/main3_board_check.md`；只有用户回复 `MAIN-3 BOARD PASS` 才标记板测通过。

### MAIN-0 审计结论（2026-09-18）

- **基线身份：通过。** 分支 `Yan_Chen_Double`，主板 RTL 基线为 `cfd5b70`；器件 `EG4S20BG256`。
- **活动工程：通过。** `hx4s20_800x600_multimedia.al` 的活动顶层为 `top_1280x720_feature_v72_resource_optimized`；v73 顶层在工程中存在但为旁路候选。
- **管脚映射：通过。** 当前 ADC 与 HX4S20C 资料中的 R7、A2/B2/B1/C1、C8/C7/C6/C5、A14/A13/B14/A12、K1/B3/E3/F5 等映射一致。
- **当前功能接入：已确认源码事实。** 五图缓存、TF/SPI、SDRAM、1280×720 HDMI、OSD、UART 字幕和转场参数在 v72 包装中接入；最终文物素材尚未接入，符合用户当前状态。
- **已有 bit：历史与本轮分列。** 历史 `release/hx4s20_1280x720_v72_resource_optimized.bit` 为 629664 bytes，SHA256 为 `3226099D43AAE624BBAAB9AEA543901316902BC85701E0FD7CBBF1192D4DAA05`。本轮 bit 为 `release/hx4s20_1280x720_v72_subtitle_continuous_scroll_v2.bit`，629664 bytes，SHA256 为 `556465BF25C952391BDA74C7A3C817B17EF443914DE6FDC26E2CFC91137CAB9C`。
- **STA/P&R 证据：本阶段门禁通过。** `_build_v72_subtitle_continuous_scroll/subtitle_continuous_scroll_pr.status` 报告最终 Setup WNS `+128 ps`、TNS `0 ps`，Hold WNS `+30 ps`、TNS `0 ps`；最终时序覆盖率 `99.89%`，慢/快角均通过，时序例外报告为空。路由 DRC 无多驱动、无异常时序路径；工具仍报告 SDRAM 25 MHz 相移时钟使用 1 段本地路由资源，该项不是时序违例，但板测时需重点观察 SDRAM/画面稳定性。
- **仿真：工具已定位，尚未重新执行。** ModelSim 安装目录和仓库 `.do`/testbench 入口已确认，后续可直接用 `D:\Modelsim\win64` 工具执行回归。

## 3. 关键上下文

### 关键文件

| 文件 | 作用 |
|---|---|
| `hx4s20_800x600_multimedia.al` | 唯一 TD 工程；当前活动顶层为 MAIN-3 `top_1280x720_main3_interaction`。 |
| `src/memory/top_1280x720_main2_lecture.v` | MAIN-2 包装顶层，启用总览、五槽讲解缓存、五路 WAV、TF 字幕和 HDMI 音频。 |
| `src/video/museum_lecture_controller.v` | MAIN-2 初始缓存、讲解中滚动预载、错误门控和四阶段音画状态机。 |
| `src/memory/top_1280x720_main1_overview.v` | MAIN-1 包装顶层，沿用 v72 约束层级并启用文物总览。 |
| `src/video/museum_overview_controller.v` | MAIN-1 按键选择、就绪门控和帧边界跨时钟域发布。 |
| `src/storage/bmp_sdram_row_writer.v` | 正常帧写入，并在 MAIN-1 中逐行横裁到第六个 SDRAM 合成帧。 |
| `src/video/museum_overview_overlay.v` | 五栏边框、未就绪占位、高亮和确认反馈；不再缓存缩略图。 |
| `src/memory/top_1280x720_feature_v72_resource_optimized.v` | MAIN-0 已板测通过的 1280×720 图片播放器回退顶层。 |
| `src/memory/top_1280x720_feature_v73_audio_visualizer.v` | v73 音频可视化候选包装顶层；不能因文件存在就假定已成为工程默认顶层。 |
| `src/memory/sdram_bmp_row_top_v66.v` | 图片缓存、SDRAM、SPI TF、按键、OSD、音频和字幕的主媒体链。 |
| `src/audio/fat32_wav_streamer.v`、`audio_pcm_player_48k.v`、`audio_goertzel8.v` | v73 WAV 读取、PCM 播放与可视化相关模块。 |
| `src/video/audio_visualizer_overlay.v` | 64 根蓝/青交替柱状音频波形可视化。 |
| `src/video/museum_subtitle_overlay.v` | MAIN-2 FAT32 字幕包读取与叠加；双缓冲当前/下一条位图，并按实际 PCM 帧切换。 |
| `tools/generate_museum_subtitles.py` | 将五件文物各自的 SRT 与同编号 WAV 绑定，生成 TF 根目录的 `SUB0.BIN`～`SUB4.BIN`。 |
| `src/video/uart_subtitle_overlay.v` | 800×32、2-bit、双缓冲、帧边界提交的中文位图字幕。 |
| `tools/play_museum_srt.py` | 按实际 WAV 时长缩放五份 SRT 并通过既有 UART 协议逐条发送。 |
| `constraints/top_1280x720_v73_audio_visualizer.{adc,sdc}` | v73 独立约束；SPI：CLK A14、MOSI A13、MISO B14、CS A12；UART：F12/D12。 |
| `scripts/build_v73_audio_visualizer_pr.tcl` | v73 全流程 P&R，固定 seed 75，输出 `_build_v73_audio_visualizer`。 |
| `scripts/build_v73_audio_visualizer_bitgen.tcl` | 只从已完成的 v73 P&R DB 生成 bit。 |
| `scripts/build_v73_multiaudio{,_controls_minimal}_bitgen.tcl` | 从同一 v73 P&R DB 输出多音频候选 bit；不会自行做 P&R。 |
| `docs/media_1280x720_v71_v72_full_features_20260902.md`、`docs/v69_subtitle_bram_aligned_20260901.md` | 历史设计和验证证据；时间与当前 checkout 不同，必须标为历史记录。 |

### 固定技术条件

- 器件：`EG4S20BG256`；输入时钟 50 MHz；1280×720 视频时钟约 75 MHz。
- TF 使用既有 SPI 驱动，而非已经撤销的原生四线 SD 实验。当前可用物理映射为 A14/A13/B14/A12。
- BMP：TF 根目录的 MAIN-1 全貌槽位为 `IMAGE0.BMP` 至 `IMAGE4.BMP`；MAIN-2 细节槽位为 `ART0D1.BMP` 至 `ART4D3.BMP`。均使用 24-bit、未压缩 BI_RGB；活动图片链支持最大 1920×1080，FPGA 按比例缩放、居中、黑边补齐。
- 字幕：MAIN-2 从 FAT32 TF 根目录读取 `SUB0.BIN` 至 `SUB4.BIN`，各包分别与同编号 WAV 的实际 PCM 帧同步；当前素材由 `py tools\generate_museum_subtitles.py --dest E:\ --audio-dir E:\ --timing-mode auto` 从五份 SRT、MD 和 WAV 生成，不需要电脑实时发送。历史 v72/v73 回退顶层仍保留 UART 位图字幕协议 `55 AA | version | mode | width=800 | height=32 | payload_length=6400 | bitmap | CRC16`。
- 音频（MAIN-2）：`AUDIO0.WAV` 至 `AUDIO4.WAV`，44-byte 标准头、PCM16、48 kHz、双声道；总览态按 SW1～SW3 预选文物并预缓冲，讲解图片阶段由实际 PCM 消耗进度驱动。

## 4. 已做出的关键决策

1. **图片稳定链与音频候选隔离。** v73 通过独立顶层和参数扩展 `top_v66`，而不是替换稳定 v72 结构；新功能必须保留回退路径。
2. **图片由 FPGA 自适应处理。** 用户明确不接受 PC 端强制统一拉伸；源 BMP 保留尺寸，由 FPGA 在加载期缩放。
3. **多图使用缓存而非切图时整图重读。** 五图预加载保证按键切换快；不要回退到读取时才加载整图。
4. **转场采用输出遮罩。** 不额外读取旧帧或增加 TF/SDRAM 带宽；OSD 保持可见。
5. **MAIN-2 中文字幕改为 TF 字幕包。** PC 端把每件文物的 SRT 按同编号 WAV 的真实 PCM 总帧数转换为 `SUB*.BIN`；FPGA 运行时仅缓存当前和下一条 800×32 双位平面字幕，避免固化特定文物文字和完整中文字库。字幕背景透明，只叠加白色字芯与黑色细描边。历史回退顶层继续保留 UART 双缓冲字幕，不影响稳定回退路径。
6. **不以约束豁免伪造时序通过。** 禁止为真实视频/SDRAM/音频路径添加 false path 或 multicycle 来掩盖违例。
7. **商品展示/原生四线 SD 已撤销。** 该方向曾板测出现 `1001`、`D1D1`、`D1D2`、`60B6`，用户决定停止试错并要求回退；没有新的用户授权不要恢复。
8. **MAIN-2 使用拨码预载。** SW1～SW3 负责选择后台预载文物，高亮只负责交互选择；两者匹配且图片/音频均就绪后才接受 KEY2，SW4 保留给后续应急模式。

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
- 用户最新要求：后续每轮完成后自动 commit，但不 push；烧录、删除或批量清理仍需明确授权。

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
- 按用户最新要求每轮完成后自动提交但不 push；不要把用户已有的无关脏工作区修改误纳入提交。
- 不要删除源级 testbench、当前脚本、回退产物或验证文档，除非用户明确要求；删除后必须说明范围和可恢复性。

## 9. 隐含约束

- 默认保持 1280×720、五图缓存、SDRAM 读出、顶部 OSD、亮度/对比度、既有按键和 UART 字幕行为。
- 新功能不得未经预算地增加 TF/SDRAM 带宽、时钟域或大型缓存。
- 自适应 BMP 必须保持格式检查、顶/底向上支持、四字节行对齐，加载失败不能覆盖已经发布的画面。
- 转场参数在一次切换开始时锁存，OSD 不得被转场遮罩覆盖。
- TD 构建脚本须从仓库根目录通过 PowerShell 管道执行；`td_commands_prompt.exe -tcl <script>` 不是本工程验证过的调用方式。

## 10. 已确认事实与推测

### 已确认

- `Yan_Chen_Double` 以 `cfd5b70` 为主板 RTL 基线；审计和清理提交只更新文档、工程元数据并删除历史残留，不修改 RTL。
- `.al` 文件活动模块为 MAIN-1 `top_1280x720_main1_overview`；v72 和 v73 包装源文件仍保留，其中 v73 的 P&R 脚本可显式指定 v73 顶层独立运行。
- 当前 `release/` 顶层中的历史 v70/v71/v72/v73 bit 均可读取；它们不是本轮 MAIN-0 生成物。
- `release/_timing_failed/hx4s20_sdram_native_singleword_diag.bit` 也存在，但目录名已表明它不是发布候选。
- 2026-09-19 清理后已从干净目录生成 MAIN-0/MAIN-1 新证据；当前 `_build_v72_subtitle_continuous_scroll`、`_build_main1_overview`、根目录报告和 `.bid` 均按用户要求保留为未跟踪构建产物，不提交。

### 推测 / 暂定

- 当前 `release` bit 的历史生成来源与本轮 `Yan_Chen_Double` 基线之间没有一一对应的本轮 STA/DRC/板测闭环；不能视为本计划任何阶段已通过。
- 如果再次需要商品展示，既有原生 SD 路线并不具备可复用的板级成功证据，应从新的需求和独立验证计划开始。

## 11. 当前项目状态快照

```text
分支：Yan_Chen_Double（跟踪 origin/Yan_Chen_Double）
MAIN-2 板测基线提交：ad81b59
工程：hx4s20_800x600_multimedia.al
工程默认顶层：top_1280x720_main3_interaction
MAIN-0 回退顶层：top_1280x720_feature_v72_resource_optimized
v73 候选顶层：top_1280x720_feature_v73_audio_visualizer
活动 ADC：constraints/top_1280x720_v73_audio_visualizer.adc
活动 SDC：constraints/top_1280x720_main3_interaction.sdc
保留最新候选 SDC：constraints/top_1280x720_v73_audio_visualizer.sdc
当前 P&R 目录：`_build_main3_interaction`（MAIN-3 工具链证据，未跟踪）
当前待板测 bit：`release/hx4s20_main3_interaction.bit`（MAIN-3，尚未板测）
MAIN-2 回退 bit：`release/hx4s20_main2_lecture.bit`（已板测通过）
MAIN-1 回退 bit：`release/hx4s20_main1_overview.bit`（已板测通过）
MAIN-0 回退 bit：`release/hx4s20_1280x720_v72_subtitle_continuous_scroll_v2.bit`（已板测通过）
当前商品展示文件：无（已回退）
当前阶段状态：MAIN-2 已板测通过；MAIN-3 按用户确认计划实施，等待最终工具链及上板验证
```

## 12. 下一步行动

1. `MAIN-0` 审计、v72 综合/P&R/STA/DRC、bitgen 和板测已完成；用户已确认 `MAIN-0 BOARD PASS`。
2. MAIN-0 板测基于 `release/hx4s20_1280x720_v72_subtitle_continuous_scroll_v2.bit`；用户确认当前基线的 HDMI、TF、SDRAM、按键、SW4 和画面稳定性满足验收要求。
3. MAIN-1 RTL、仿真、P&R、STA/DRC、bitgen 和板测已完成；用户已明确回复 `MAIN-1 BOARD PASS`。
4. 保留 MAIN-2 已板测 bit，MAIN-3 新 bit 只作为待测版本。TF 根目录需有现行 BMP/WAV/SUB 文件及可选 `OSDNAME.BIN`；名称文件缺失应显示“文物 0～4”，不阻塞讲解。
5. 按 `docs/main3_board_check.md` 逐件验证按键、暂停、恢复、无效拨码、名称和无复位重入。自然结束仍是最后全貌伴随音频末帧，再等待约 1.2 秒收拢。尤其确认 KEY4 不产生残留 SDRAM 写事务，图片/字幕/音频可重新加载。
6. 仅在用户明确回复 `MAIN-3 BOARD PASS` 后标记本阶段板测通过。提交只纳入相关源码、测试、文档、媒体包和发布 bit，不纳入 `_build_*`、根目录报告或 `.bid`，不自动 push。

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
