# 副屏本地功能交接（2026-09-23）

## 基线与范围

- 工作树：`D:\Anlogic_information\hx4s20_secondary`；分支：`secondary-screen`；起点：`a158ae3225617b539e3dde5727f12e8d13a48008`（`origin/Yan_Chen_Double`）。主板原工作树不在此目录。
- 目标器件 `EG4S20BG256`，TD 实测版本 `6.2.168116`，本机 ModelSim 实测版本 `10.4`。文档提到的 ModelSim `10.6e` 尚未在本机验证。
- 用户要求先完成副屏本地功能和待接命令接口，暂不上板。当前没有 PHY、RGMII、UDP 或 MBP1 字节流接收器，主板也没有向副板发送真实命令。
- 本分支包含两个可独立构建顶层：`top_1280x720_secondary`（SECONDARY-0 彩条诊断）和 `top_1280x720_secondary_local`（SECONDARY-1/2/3 本地功能）。两者均**未上板**，不得标记 `BOARD PASS`。

## 已实现

| 功能 | 实现位置 | 边界 |
|---|---|---|
| 720p 彩条、时序、LED、数码管 | `src/secondary/top_1280x720_secondary.v` | 仅诊断顶层，无媒体链 |
| TF 根目录 `IMAGE0.BMP`～`IMAGE9.BMP`、五张大图预载、简介页按需加载到第 6 个画面槽 | `src/secondary/top_1280x720_secondary_local.v` 复用 `top_v66` | 五张大图就绪后显示；一个简介页与五张大图共占 6,220,800 bytes SDRAM |
| 无讲解时 50 MHz 独立 5 秒轮播，0→1→2→3→4→0；确认讲解后显示对应简介 | `src/secondary/secondary_carousel_controller.v` | 未确认的拨码预选不打断轮播或当前讲解；画面切换在帧边界提交，启用原有淡入、擦除、幕布、缩放转场 |
| 五张生成的大图和五张用户提供的简介/路线图 | `assets/secondary_exhibit_v2_tf/IMAGE*.BMP` | 大图是 AI 根据用户素材生成的展示图，不是馆藏实拍；路线图尚未经场馆核定 |
| 本地紧急开关及独立警示画面 | 控制器、`src/secondary/secondary_page_overlay.v` | 画面不依赖 TF 或网络；解除后从第 0 页重新计时 |
| 媒体等待/错误页、LINK WAIT/OK/LOST 状态 | `secondary_page_overlay.v` | LINK 状态现在没有物理网络输入，约 2 秒后正常显示 LOST |
| 已解析命令接口 | `top_v66` 的 `secondary_cmd_*` 和 `cmd_result` | 本地顶层当前将输入接为常量；将来 MBP1 接收器必须先完成长度、CRC、序号、boot_id 去重及 ACK，再驱动此接口 |

本地开关为 `emergency_sw`，对应板上 SW4 的 C5 管脚；置 1 进入演示紧急页，置 0 解除本地紧急。远程紧急状态与本地开关取或；远程状态需要匹配 `emergency_id` 的 CLEAR 或匹配状态快照才能解除。紧急状态下链路超时不会自动清警。

已解析接口定义：50 MHz 单周期 `secondary_cmd_valid`，`secondary_cmd_type` 使用约定的 `HELLO=01`、`HEARTBEAT=02`、`STATUS_QUERY=03`、`ARTIFACT_SELECT=10`、`LECTURE_STATE=11`、`PLAYBACK_STATE=12`、`EMERGENCY_SET=20`、`EMERGENCY_CLEAR=21`（均十六进制）；`secondary_cmd_artifact_id`、`secondary_cmd_confirmed`、`secondary_cmd_mode`、`secondary_cmd_lecture_phase`、`secondary_cmd_lecture_reason`、`secondary_cmd_emergency_id`、`secondary_cmd_route_id`、`secondary_cmd_emergency_active` 是提取后的字段。`ARTIFACT_SELECT.confirmed=1` 或 `HEARTBEAT.mode=2` 进入对应简介；`HEARTBEAT.mode=1` 或讲解返回恢复轮播；未确认的预选仅更新主板状态。`secondary_cmd_result` 使用 MBP1 的 OK=0、UNSUPPORTED=3、INVALID_STATE=5。CRC、ACK 与 UDP 尚不存在，不能把该接口称为网络已通。

## 素材

- 2026-09-24 新交互素材包：`assets/secondary_exhibit_v2_tf/IMAGE0.BMP`～`IMAGE4.BMP` 是五张无字文物大图，`IMAGE5.BMP`～`IMAGE9.BMP` 是按同一文物顺序排列的简介/路线页；`tools/prepare_secondary_exhibit_v2.py` 可重建。五张大图源文件见 `assets/secondary_exhibit_hero_source/`。TF 根目录必须放全部十张，每张 960×540、24-bit BI_RGB。
- 旧版 `assets/secondary_exhibit_tf/IMAGE0.BMP`～`IMAGE4.BMP` 是五张简介页，只供旧轮播 bit 使用；不可与新版文件混放或互换。新版上卡用 `tools/copy_secondary_exhibit_v2_to_sd.ps1 -DriveLetter F`，脚本会核对 FAT32 并逐文件校验 SHA256。SD 卡尚未插入，未执行复制。
- 2026-09-24 用户提供 `C:\Users\20526\Desktop\文物图片` 中五张已排版 PNG，原样复制到 `assets/secondary_exhibit_source/` 并用 Git LFS 保管，原文件未改动。顺序为越王勾践剑、四羊方尊、金缕玉衣、马踏飞燕、长信宫灯，原图均为 1448×1086。原图高度超过本地顶层 `ADAPTIVE_BMP_MAX_HEIGHT=1080`，不能直接改扩展名投入 TF。
- `tools/prepare_secondary_exhibit_images.py` 已保持原图比例、完整文字和统一地图，将五张图缩至 720×540 并以同图柔焦背景补足两侧，生成 `assets/secondary_exhibit_tf/IMAGE0.BMP`～`IMAGE4.BMP`；另有 `assets/secondary_exhibit_preview/IMAGE0.png`～`IMAGE4.png` 供查看。BMP 均为 960×540、24-bit、BI_RGB、1,555,254 bytes。TF 中只复制 `secondary_exhibit_tf` 的五个 BMP，不复制预览图。
- 已验证 `release/hx4s20_secondary_local.bit` SHA256 仍为 `8A7E1B53082C4AA9E4F6C5087902EBE58146BF1CED3DB5396D171C5098211F62`；本轮仅换 TF 素材，bit 不需重编。2026-09-24 检查时未检测到 SD 卡盘符，尚未复制到卡，也尚未板测。插卡后确认 FAT32，用 `tools/copy_secondary_exhibit_to_sd.ps1 -DriveLetter <盘符>` 复制并逐文件校验 SHA256。
- 用户提供的路线图是方案素材，展馆平面和当前位置尚未由场馆核定；不得用于真实导航或疏散。
- 单张 AI 生成的虚构地图：`assets/secondary_demo/fictional_museum_map.png`，SHA256 `39493C46B8D83C79BC14DAEE5DC2513C6C0C141CCB4A6051E1C12D699E454EB9`。
- `tools/make_secondary_demo_pages.py` 把同一演示地图嵌入五张不同标题的 960×540、24-bit BMP。现有五张文件各 `1,555,254` bytes，采用 Git LFS 跟踪。重新生成需要 Python、Pillow 和 Windows `C:/Windows/Fonts/simhei.ttf`。
- 后续换真实资料时只替换五张同名 BMP。必须先由场馆确认平面图、当前位置、出口和路线；此演示图**不能当实际疏散指引**。

## 仿真、实现和 bit

在 `sim` 目录运行 `& 'E:\Modelsim\win64\vsim.exe' -c -do run_secondary_0.do`、`... -do run_secondary_local.do`、`... -do run_secondary_transition.do`。2026-09-24 三组均 PASS：SECONDARY-0 时序仿真覆盖两完整帧；本地控制器覆盖五张大图轮播、未确认预选不打断、确认后保持简介页、返回恢复轮播、无效确认拒绝、紧急抢占及链路超时；转场映射和遮罩仿真 PASS。完整 TF→SDRAM→HDMI 链仍未上板验证。

在仓库根目录执行：

```powershell
Get-Content -Raw scripts/build_secondary_pr.tcl | & 'D:\Anlogic\TD5.6.2\bin\td_commands_prompt.exe'
Get-Content -Raw scripts/build_secondary_bitgen.tcl | & 'D:\Anlogic\TD5.6.2\bin\td_commands_prompt.exe'
Get-Content -Raw scripts/build_secondary_local_pr.tcl | & 'D:\Anlogic\TD5.6.2\bin\td_commands_prompt.exe'
Get-Content -Raw scripts/build_secondary_local_bitgen.tcl | & 'D:\Anlogic\TD5.6.2\bin\td_commands_prompt.exe'
```

| 顶层 | Setup WNS/TNS | Hold WNS/TNS | 资源（place） | bit |
|---|---|---|---|---|
| SECONDARY-0 | +715 ps / 0 | +67 ps / 0 | LUT 180、REG 173 | `release/hx4s20_secondary_0.bit`，629643 bytes，SHA256 `84C081D6F1DB2F53EECE2231313A5C2B472CE3383D17520D3A487ABEE68ACA3D` |
| 本地功能 | +762 ps / 0 | +23 ps / 0 | LUT 10306、REG 4405、BRAM9K 22、DSP 3；路由后 slices 66.50% | `release/hx4s20_secondary_local.bit`，629649 bytes，SHA256 `8A7E1B53082C4AA9E4F6C5087902EBE58146BF1CED3DB5396D171C5098211F62` |
| 新版大图轮播 bit | +646 ps / 0 | +24 ps / 0 | LUT 11950、REG 4418、BRAM9K 22、DSP 5 | `release/hx4s20_secondary_v2_local.bit`，629649 bytes，SHA256 `7859997F0E1CEC2BBB7309BD77B2B869B5D02A5333247DD9C3A608629899E780` |

本地 P&R DRC 报告无多驱动、无异常时序路径。日志有 `PHY-7002`（SDRAM 自动布局位置调整）及 `PHY-5079`（SDRAM 时钟一条本地布线）工具警告，bitgen 门禁仅允许这两个已核对代码，其他 critical warning 或时序失败会拒绝生成。主板 `top_1280x720_main2_lecture` 在本分支可由 TD 成功 elaborate；原有 `run_v26_subtitle_output_route.do` 在本机 ModelSim 10.4 遇到内部错误，优化运行又因旧 testbench stub 与核心参数/端口不匹配而失败，不能把该主板仿真算作 PASS。副屏完整 TF→SDRAM→HDMI 板级链仍须按用户后续指令验证。

新版 bit 的物理顶层仍把 `secondary_cmd_valid` 接常量 0，因为 Ethernet/UDP/MBP1 接收器尚未实现。烧录新版 bit 可以观察五张大图和转场；**不能仅靠烧录观察主板确认后切简介**。该路径已在 `top_v66` 的已解析命令接口及控制器中实现，并通过控制器仿真；待接收器接入后还须重新综合/生成 bit 并做双板联调。以上 bit、仿真和时序均非板级验证。

## 待用户下达上板指令后

1. 先单独烧录 SECONDARY-0 诊断 bit，确认显示器识别 1280×720、彩条与边界稳定，连续运行 30 分钟。记录显示器/LED/数码管现象。
2. TF 卡 FAT32 根目录放 `assets/secondary_exhibit_v2_tf/IMAGE0.BMP`～`IMAGE9.BMP`，再烧录新版本地功能 bit。未连接主板命令时确认五张大图依次出现、每页 5.0 秒 ±1 帧并有转场，无撕裂和旧页残留。连接 MBP1 接收器后，确认进入讲解时测试五张对应简介，退出后恢复轮播；分别移除/损坏某页素材，核对占位画面和数码管错误码。
3. 将 SW4 置 1、再置 0，观察紧急页优先显示、解除后从第 0 页恢复。真实位置和路线未替换前，不用于现场引导。
4. 只有上述板测记录齐全才分别标记对应 `SECONDARY-N BOARD PASS`。后续 Ethernet 按独立 PHY 诊断、UDP/MBP1、双板联调推进。
