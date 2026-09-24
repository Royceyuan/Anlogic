# 副屏本地功能交接（2026-09-23）

## 2026-09-24 原图简介 720p 与用户逃生图（当前候选）

- 按用户最新要求，五张简介继续使用 `assets/secondary_exhibit_source/` 中的原始排版 PNG；`tools/prepare_secondary_exhibit_720p.py` 只等比缩放、补齐背景，生成 `assets/secondary_exhibit_720p_tf/IMAGE5.BMP`～`IMAGE9.BMP`，每张 1280×720、24-bit BMP，没有重写文字或重新生成版式。`IMAGE0`～`IMAGE4` 仍是 1280×720 文物大图。
- SW4 紧急页改用用户的 `C:\Users\20526\Desktop\文物图片\逃生路线图.png`；原件逐字节复制到 `assets/secondary_emergency_source/escape_route_original.png`，SHA256 `283F6D6540A67E6E21D81E4DEC2F84D5BA3ADD1DE4578A17FDAB0E403433A9E6`。上卡文件 `IMAGEA.BMP` 为保持整张海报不裁切的 960×540 转换图。原件是示意海报，场馆尚未核实位置和出口，不能用作真实疏散依据。
- 当前候选把五张轮播图存为 960×540 RGB565（槽 0～4），单张当前简介存为原生 1280×720 RGB565（槽 5），紧急海报存为 960×540 RGB565（槽 6）。布局：槽 5 基址 1,296,000 个 32-bit 字，槽 6 基址 1,756,800 个字，末地址 2,016,000 小于 8 MiB SDRAM 的 2,097,152 个字；总占用 8,064,000 bytes。大图源文件仍为 720p，但当前轮播工作帧会缩为 540p；本次清晰度提升针对简介。
- 本地操作：SW1～SW3 改变为 0～4 时自动发预缓存命令，画面继续轮播；KEY2 模拟主板确认，切到对应简介；KEY3 返回轮播；SW4 抢占显示用户逃生图。没有主板 Ethernet 接收器，以上按键和拨码仍是本地模拟。
- 定向 ModelSim：1280×720 简介 BMP 的 FAT32→行缓冲→SDRAM 写入测试 PASS；`IMAGEA.BMP` 文件名和 960×540 写入测试 PASS；540p、缩放与 720p SDRAM 行缓存读出测试 PASS；控制器和紧急画面叠加测试 PASS。上述仿真没有模型化板上 SDRAM 仲裁抖动，**hardware = NOT TESTED**。
- 当前候选位流 `release/hx4s20_secondary_local_info720_v6.bit`，629649 bytes，SHA256 `CF747D1E7985966A46414903C52CA527DEA8EA76EC2280C61215946194CE550D`。TD 6.2.168116 新鲜 P&R/STA：Setup WNS +168 ps/TNS 0，Hold WNS +24 ps/TNS 0，bitgen 成功；仅有已核对的 PHY-7002、PHY-5079 警告。完整 TF→SDRAM→HDMI 板级画质与带宽仍须实测，**hardware = NOT TESTED**。旧 `hx4s20_secondary_local_precache_v4.bit` 不具备原生 720p 简介读出能力。另存 `hx4s20_secondary_local_route_v5.bit` 为 540p 简介回退版本，Setup +203 ps/TNS 0、Hold +23 ps/TNS 0，SHA256 `4346F470C7F2480B0D39E83A51F8E7B9F79BDB606F8BA6C38A78F534C7B86F18`，它会将 720p 输入缩回 540p，不能用于验收本次清晰度要求。
- 当前未检测到 F: 卡，所以十一张新版 BMP **尚未写卡**。读卡器重新出现后使用 `tools/copy_secondary_exhibit_720p_to_sd.ps1 -DriveLetter F`，脚本要求 FAT32 并逐文件核对 SHA256；烧录新版位流前应核对卡根目录的 `IMAGE0.BMP`～`IMAGE9.BMP`、`IMAGEA.BMP`。

## 2026-09-24 预缓存命令语义更新

- `ARTIFACT_SELECT.confirmed=0` 或携带有效文物编号的 `HEARTBEAT` 使副屏在继续五图轮播时，后台将对应 `IMAGE5.BMP`～`IMAGE9.BMP` 读入第 6 个 SDRAM 槽。未确认命令不切换显示画面。
- `ARTIFACT_SELECT.confirmed=1` 才进入对应简介/路线页；若预缓存未完成，保持轮播，待加载成功后在帧边界切换。KEY1 本地模拟预选并预缓存，KEY2 模拟确认，KEY3 返回轮播，SW1～SW3 选择 0～4，SW4 仍是本地紧急开关。
- 第 6 槽一次只能保存一件文物的简介；在展示旧简介时收到新预选，须等离开旧简介后才覆写该槽。预缓存失败记录对应文物错误，切换到另一个文物后允许重新加载。
- 当前物理顶层仍没有 Ethernet PHY/UDP/MBP1 接收器，KEY1/KEY2 只是本地命令模拟。当前 SDRAM 工作帧仍为 960×540；原生 1280×720 文物图与滚动缓存是独立的待完成工作。本节描述 RTL 语义，不代表板测通过。
- 本地候选 bit：`release/hx4s20_secondary_local_precache_v4.bit`，629649 bytes，SHA256 `B49120333D9735F31D1F0FBDA4047025F7136C07D4DD3A25FB19D1844C2B5B27`。ModelSim 控制器和叠加层仿真 PASS；TD 6.2.168116 新鲜 P&R/STA：Setup WNS +337 ps/TNS 0，Hold WNS +30 ps/TNS 0，bitgen 成功。完整 TF→SDRAM 预缓存时序与硬件仍需专门验证；**hardware = NOT TESTED**。
- `tools/prepare_secondary_exhibit_720p.py` 已生成 `assets/secondary_exhibit_720p_tf/`：`IMAGE0`～`IMAGE4` 为 1280×720 BMP，`IMAGE5`～`IMAGE9` 仍为 960×540 BMP，十文件共 21,600,540 bytes。2026-09-24 已确认 F: 为 FAT32/Removable/Lenovo，原十文件与仓库旧版逐张 SHA256 相同，然后将此包写入 F: 根目录，十文件逐张 SHA256 校验通过。v4 的自适应 BMP 读取器允许这些输入尺寸，但仍将文物图缩至 960×540 工作帧；原生 720p 显示必须等待滚动缓存和更高带宽的新版 bit。此组合尚未上板验证。

## 2026-09-24 本地预览候选

- 历史 bit：`release/hx4s20_secondary_local_preview_v3.bit`，629649 bytes，SHA256 `3F241645CA150B09CCE2B2379C27D8C9A0F67BC49B7E384FBDCA3EA719A10102`。原 `hx4s20_secondary_v2_local.bit` 保留。v3 不支持预选即预缓存。
- 保持 1280×720 HDMI 与 960×540 RGB565 六槽缓存。8 MiB SDRAM 存六张原生 1280×720 帧需 11,059,200 bytes，容量不足；过去原生 1280×720 SDRAM 读出还出现欠载。因此本候选没有宣称实现原生 720p 图片质量。
- 本地预览：SW4=0 时，`SW3:SW2:SW1=000/001/010/011/100` 选文物 0～4；按 KEY2 进入对应简介/路线页，按 KEY3 返回五图轮播。KEY2/KEY3 走已解析命令接口；以太网接收器仍未接入。`101`～`111` 不接受选择。SW4=1 仍显示应急页。
- 正常轮播与简介页不再叠加底部 `MAIN LINK LOST` 状态栏；媒体等待、媒体错误和应急页继续显示诊断栏。原始简介素材是 4:3 排版，放入 16:9 画布时两侧仍有浅色延展背景；这与 HDMI 黑边不同，后续需重新排版素材才能完全消除。
- `sim/run_secondary_local.do`：控制器和叠加层仿真 PASS，Errors 0、Warnings 0。新 bit 完整综合、P&R、最终 STA：Setup WNS +548 ps/TNS 0，Hold WNS +30 ps/TNS 0；bitgen 成功。**hardware = NOT TESTED**。之前用户实测旧版偶发停在 `60B6`，本候选没有修改 TF/SDRAM 加载链，不能视为修复。

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
| 已解析命令接口 | `top_v66` 的 `secondary_cmd_*` 和 `cmd_result` | v2 bit 将输入接为常量；v3 本地预览 bit 用 KEY2/KEY3 生成命令；将来 MBP1 接收器必须先完成长度、CRC、序号、boot_id 去重及 ACK，再驱动此接口 |

本地开关为 `emergency_sw`，对应板上 SW4 的 C5 管脚；置 1 进入演示紧急页，置 0 解除本地紧急。远程紧急状态与本地开关取或；远程状态需要匹配 `emergency_id` 的 CLEAR 或匹配状态快照才能解除。紧急状态下链路超时不会自动清警。

已解析接口定义：50 MHz 单周期 `secondary_cmd_valid`，`secondary_cmd_type` 使用约定的 `HELLO=01`、`HEARTBEAT=02`、`STATUS_QUERY=03`、`ARTIFACT_SELECT=10`、`LECTURE_STATE=11`、`PLAYBACK_STATE=12`、`EMERGENCY_SET=20`、`EMERGENCY_CLEAR=21`（均十六进制）；`secondary_cmd_artifact_id`、`secondary_cmd_confirmed`、`secondary_cmd_mode`、`secondary_cmd_lecture_phase`、`secondary_cmd_lecture_reason`、`secondary_cmd_emergency_id`、`secondary_cmd_route_id`、`secondary_cmd_emergency_active` 是提取后的字段。v4 起，未确认的 `ARTIFACT_SELECT` 会预缓存对应简介但继续轮播；`ARTIFACT_SELECT.confirmed=1` 或 `HEARTBEAT.mode=2` 进入对应简介；`HEARTBEAT.mode=1` 或讲解返回恢复轮播。`secondary_cmd_result` 使用 MBP1 的 OK=0、UNSUPPORTED=3、INVALID_STATE=5。CRC、ACK 与 UDP 尚不存在，不能把该接口称为网络已通。

## 素材

- 2026-09-24 新交互素材包：`assets/secondary_exhibit_v2_tf/IMAGE0.BMP`～`IMAGE4.BMP` 是五张无字文物大图，`IMAGE5.BMP`～`IMAGE9.BMP` 是按同一文物顺序排列的简介/路线页；`tools/prepare_secondary_exhibit_v2.py` 可重建。五张大图源文件见 `assets/secondary_exhibit_hero_source/`。TF 根目录必须放全部十张，每张 960×540、24-bit BI_RGB。
- 旧版 `assets/secondary_exhibit_tf/IMAGE0.BMP`～`IMAGE4.BMP` 是五张简介页，只供旧轮播 bit 使用；不可与新版文件混放或互换。新版上卡用 `tools/copy_secondary_exhibit_v2_to_sd.ps1 -DriveLetter F`，脚本会核对 FAT32 并逐文件校验 SHA256。2026-09-24 已确认 F: 为 FAT32、Removable、USB、Healthy（卷标 Lenovo），已将十张新版 BMP 写入根目录并逐张复核 SHA256 相同；卡上媒体文件共 15,552,540 bytes。
- 2026-09-24 用户提供 `C:\Users\20526\Desktop\文物图片` 中五张已排版 PNG，原样复制到 `assets/secondary_exhibit_source/` 并用 Git LFS 保管，原文件未改动。顺序为越王勾践剑、四羊方尊、金缕玉衣、马踏飞燕、长信宫灯，原图均为 1448×1086。原图高度超过本地顶层 `ADAPTIVE_BMP_MAX_HEIGHT=1080`，不能直接改扩展名投入 TF。
- `tools/prepare_secondary_exhibit_images.py` 已保持原图比例、完整文字和统一地图，将五张图缩至 720×540 并以同图柔焦背景补足两侧，生成 `assets/secondary_exhibit_tf/IMAGE0.BMP`～`IMAGE4.BMP`；另有 `assets/secondary_exhibit_preview/IMAGE0.png`～`IMAGE4.png` 供查看。BMP 均为 960×540、24-bit、BI_RGB、1,555,254 bytes。TF 中只复制 `secondary_exhibit_tf` 的五个 BMP，不复制预览图。
- 旧版 `release/hx4s20_secondary_local.bit` SHA256 为 `8A7E1B53082C4AA9E4F6C5087902EBE58146BF1CED3DB5396D171C5098211F62`，对应旧版五张简介页轮播；新版卡应使用 `release/hx4s20_secondary_v2_local.bit`，见下表。尚未上板验证。
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

v2 bit 的物理顶层把 `secondary_cmd_valid` 接常量 0，因为 Ethernet/UDP/MBP1 接收器尚未实现。烧录 v2 bit 可以观察五张大图和转场；**不能仅靠 v2 bit 观察主板确认后切简介**。v3 本地预览 bit 使用按键注入同一命令接口，可独立查看简介页，但不等于主板网络已接通。待接收器接入后还须重新综合/生成 bit 并做双板联调。以上 bit、仿真和时序均非板级验证。

## 待用户下达上板指令后

1. 先单独烧录 SECONDARY-0 诊断 bit，确认显示器识别 1280×720、彩条与边界稳定，连续运行 30 分钟。记录显示器/LED/数码管现象。
2. TF 卡 FAT32 根目录放 `assets/secondary_exhibit_v2_tf/IMAGE0.BMP`～`IMAGE9.BMP`，再烧录新版本地功能 bit。未连接主板命令时确认五张大图依次出现、每页 5.0 秒 ±1 帧并有转场，无撕裂和旧页残留。连接 MBP1 接收器后，确认进入讲解时测试五张对应简介，退出后恢复轮播；分别移除/损坏某页素材，核对占位画面和数码管错误码。
3. 将 SW4 置 1、再置 0，观察紧急页优先显示、解除后从第 0 页恢复。真实位置和路线未替换前，不用于现场引导。
4. 只有上述板测记录齐全才分别标记对应 `SECONDARY-N BOARD PASS`。后续 Ethernet 按独立 PHY 诊断、UDP/MBP1、双板联调推进。
