# 双板手动浏览、原画面控制与轻量恢复发布检查

日期：2026-10-01。主板 `Anlogic`，副板 `Anlogic2`。本轮使用同一对正式入口；不修改 TF 图片、音频、字幕、名称、音画时间轴、图片顺序及转场类型。原已通过的 bit 独立保留。

## 1. 配对发布

- 主板：`release/dual_fpga_museum_terminal_main_board.bit`，634313字节，SHA-256 `36D9BB7C74E23C047BEC15A5E128A8540852B8C4B7ECD11F504E25CDB107A6EC`；同目录 `.bit.sha256` 同步更新。
- 副板：`Anlogic2/release/hx4s20_secondary_main5e_manual_browse.bit`，629641 字节，SHA-256 `FD19782EA3AC24D1F59918F6F08C054E20832B40DDD4ED9C44FF088FE1BF151A`。
- 副板 `release/manifest_manual_browse.json` 记录配对主板校验值以及副板源码、报告和仿真日志校验值。不能只根据 capability bit9 判断是否已经烧录本次修改版。
- 主板上一版 `14D50353...` 保存在 `_build_museum_main_board/museum_manual_pre_osd_14d50353.bit`。副板旧 v06 位流及原 `manifest.json` 未覆盖。

## 2. 实际行为与修复依据

副板 SW3=1 静音手动，SW3=0 自动讲解。四键在两种模式保持 SW2:SW1 原分组：00 四预设，01 亮度/对比度，10 饱和度/色温，11 四方向平移。主板 KEY3 手动循环全貌、细节1、细节2、细节3、全貌；物理副板四键不调用兼容保留的 0x18 选图接口。

主板手动 KEY2 走现有回全貌、收拢到总览流程，不进行 KEY4 完整恢复、不清除手动模式。同文物缓存仍在时可再次确认；拨码改为别的文物仍需要正常读取新图。

手动切回自动后先回有效总览，等待已经接受的 SD 扇区完整结束，只重新准备 WAV 与字幕会话，保留图片、总览、名称、SD 初始化与有效 FAT32 几何参数。主板恢复心跳阻止普通控制；副板仅保留此次预期恢复中的模式关闭事务，等待实际自动、总览且恢复标志清零后解锁。KEY4 仍执行原完整恢复。

WAV 原重启路径会重新读 MBR/VBR，过程中改写字幕共享的文件系统参数。新增默认关闭的 REUSE_GEOMETRY，仅本产品入口使用已校验几何参数从根目录重开 WAV；KEY4 清零几何参数后仍重新校验 MBR/VBR。会话启动条件寄存一拍，禁止在旧扇区作废、PCM FIFO 复位或会话 restart 时启动新会话，保留原扇区仲裁取消/收尾机制。音频、字幕仍从卡读取，轻量恢复不是零 TF 读取承诺。

OSD 在 ZOOM 上方显示实际“自动/手动”；状态经同步和帧边界锁存，不直接显示未确认的副板拨码意图。

## 3. 时序处理与验证边界

复用现有应急像素一级流水，将几何判定与颜色输出分开；线性转场比较移入现有第二级；行缓冲横向起点先合并再映射像素。总像素流水延迟不变。HDMI 四路原有两级串行复位使用 TD preserve 保持独立，防止综合合并为 375 MHz 长复位网。没有修改 PLL、管脚、时序约束、扫描帧率或像素数据格式。

正式构建使用 TD 6.2.168116、EG4S20BG256、主板 place seed1/high effort、route routability，布线后 fix_hold，再执行 final STA、DRC 和 bitgen。本轮完整综合后复用同一 gate DB 在 seed1 重新布局并闭合；规范构建脚本仍使用 seed1。主板最终资源与时序以本目录 `museum_main_board_area.rpt`、`museum_main_board_timing.rpt` 为准；bitgen 脚本拒绝 setup/hold 未闭合的结果。

主板 setup +0.075ns、hold +0.024ns，TNS及违例端点均为0，STA覆盖99.66%。相比上一发布版，布局后 LUT 16829→17111（+282）、寄存器11380→11435（+55）、Slice9522→9545（+23），DSP和BRAM不变；包含物理优化/缓冲，不应把布局数字全归为新增RTL。当前 Slice 97.40%，余量仍小，本轮目的为功能修复及位流交付，不宣称已完成资源优化。

| 主板资源 | 本轮最终占用 | 比例 |
|---|---:|---:|
| LUT | 17111/19600 | 87.30% |
| 寄存器 | 11435/19600 | 58.34% |
| Slice | 9545/9800 | 97.40% |
| BRAM9K | 43/64 | 67.19% |
| BRAM32K | 10/16 | 62.50% |
| DSP | 13/29 | 44.83% |
| PLL | 4/4 | 100% |
| GCLK | 3/16 | 18.75% |

主板仍有工程已有的 IPC 元数据加载提示、SDRAM 宏自动放置/本地时钟和旧 derive_pll_clocks 命令告警；已核验工程引用文件存在及实际综合/布线结果，不隐瞒这些告警，不因此放宽时序约束。

副板最终布局：LUT 10726/19600、寄存器6714/19600、BRAM9K 32/64、BRAM32K 0/16、DSP9/29、PLL4/4。setup +0.213ns、hold +0.021ns，TNS0，STA覆盖99.76%。原 SDRAM 宏自动放置、单负载本地 SDRAM 时钟等告警仍存在，不能表述为零告警。

## 4. 可重复离线检查

在各工程 `sim` 目录调用 `D:\Modelsim\win64\vsim.exe -c -do <脚本>`；日志为 `registered_*.log`，本轮不提交临时日志和仿真工作库。

| 主板检查入口 | 覆盖内容 |
|---|---|
| run_remote_controls.do | 正式 KEY3 选图、手动 KEY2 缓存退出、轻量恢复等待、注册启动隔离、预设/参数/视口与 BUSY 后恢复 |
| run_local_manual_test.do | 旧单板诊断控制、拨码消抖、恢复等待和重入；诊断拨码并非正式双板分配 |
| run_local_controls.do | 原总览 OSD/自动波形按键行为 |
| run_application_recovery.do / run_emergency_recovery.do | KEY4 收尾/复位/重试，SW4 抢占及帧边界解除 |
| run_sd_read_abort.do | 旧音频/字幕响应隔离，新扇区仍可仲裁 |
| run_museum_manual.do / run_museum_lecture.do | 静音四图、KEY2 退出重入及原自动时间轴 |
| run_museum_subtitle_overlay.do / run_fat32_wav_streamer.do | 字幕重复与 restart，WAV 几何复用及文件错误处理 |
| run_video_timing.do / run_light_band.do / run_emergency_mode.do | 行缓冲、OSD 像素等效，线性/菱形/上下收拢转场，应急流水 RGB 与同步对齐 |
| run_museum_status_osd.do / run_mbp1_main_endpoint_control.do | 模式字形及原 MBP1 控制端点 |
| run_hdmi_local_reset.do | 100 次异步复位、两级释放和 HDMI 串行码流等效 |

副板九组回归的源码与日志哈希已与发布 manifest 核验一致，共15项汇总 PASS。两板工程引用路径完整；Python loopback 检查不依赖故障有线网卡。

仿真包含存储 stub，不能替代真实 TF、HDMI 或双板板测。当前 E: 未挂载，没有真实卡重放，也未写入任何 TF 媒体。保留主板原有两处未提交修改，未夹带无关清理。

## 5. 烧录后验收

1. 同时烧录本报告配对的两板 bit，保留原各自 TF 卡，直连网线。副板 SW3=0 验证原自动讲解及四组控制。
2. SW3=1，主板 KEY2 进入后应静音、无字幕/波形，不自动切图；KEY3 循环四图，KEY1 缩放；副板四组预设、参数、平移持续有效。
3. 主板 KEY2 返回总览，SW3 仍为1；同文物再确认可重入，不重新读取同一文物整套图片。KEY4 仍为完整应用恢复。
4. 手动展示中 SW3=0，应先回全貌、收拢总览；WAV 和首条字幕重新就绪后确认进入自动讲解，字幕应正常出现。重复至少三轮；原图缓存保留，但音频和字幕需要有限读盘等待。
5. 分别测试所有文物、后台切换预载目标、转场中快速按键、暂停/缩放/平移、KEY4、应急开关、断线和双方独立复位。正在恢复/转场时拒绝新控制，恢复后必须重新可用，不能回放旧按键。

本轮构建交付不代表已实板通过；请回报双板实测结果后再标记验收。
