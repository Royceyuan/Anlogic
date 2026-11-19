# 双FPGA博物馆双屏展陈与应急信息终端

基于安路HX4S20C（EG4S20BG256）开发板的全离线双板系统。主板负责文物图片浏览、语音讲解与字幕显示，副板负责本地视频、导览音频和应急疏散画面。两板通过以太网交换操作指令、运行状态和讲解进度，双屏均输出1280×720画面。

## 目录与工程入口

```text
工程根目录/
├─ Museum_Main/
│  ├─ museum_main_final.al        主板工程入口
│  ├─ src/                        RTL源码
│  ├─ constraints/                引脚与时序约束
│  ├─ vendor/                     官方IP和参考模块
│  ├─ scripts/ sim/ seed/         构建、仿真和布局种子配置
│  └─ release/                    主板最终位流及时序报告
├─ Museum_Secondary/
│  ├─ museum_secondary_final.al   副板工程入口
│  ├─ src/ constraints/ vendor/   RTL、约束和IP依赖
│  ├─ scripts/ sim/ seed/         构建、仿真和布局种子配置
│  └─ release/                    副板最终位流及时序报告
└─ LICENSE
```

两板工程保持同级目录。工程包包含源码、配置、IP、最终位流及时序报告。两板的配套素材和媒体制作工具通过下方网盘链接获取。

## 配套素材与工具下载

- 下载链接：[配套素材与媒体制作工具（百度网盘）](https://pan.baidu.com/s/1G7DOR03A89nFKIcVfsEv2w?pwd=1zm8)
- 提取码：`1zm8`

配套资源包括主板图片、讲解音频、字幕及TF卡文件，副板视频、音频和字幕，以及两板对应的媒体制作工具。现成TF卡文件用于板端播放，媒体制作工具用于素材转换与展陈内容更新。

两板素材分别对应 `Museum_Main/assets/`、`Museum_Secondary/assets/`，文件结构与下文的TF卡部署说明一致。媒体工具独立运行，按对应素材和输出目录生成板端文件。图形界面综合、布局布线及bit生成由TD读取工程内的源码、配置、约束和IP完成，配套媒体用于上板运行与功能展示。

## 软件复建

使用 **Anlogic TD 6.2.1（6.2.168116）**。图形界面复建所需的综合、布局和布线参数已保存到两个工程入口。

1. 打开 `Museum_Main/museum_main_final.al` 或 `Museum_Secondary/museum_secondary_final.al`。
2. 若出现“private parameters are not default”提示，选择 **Cancel**，保留工程中的种子和逻辑优化参数。**Revert**会将这些参数恢复默认值。
3. 重新打开已构建的工程时，若出现 **Flow Step Recovery** 提示，选择 **OK** 恢复已有运行结果。
4. 点击顶部绿色 **Run** 箭头，执行综合、布局、布线及bit生成。软件弹出任务数量或重置运行数据提示时，确认后继续。
5. 完成后查看 **Multi-Seed Result** 中的最终时序和bit。Setup、Hold的最差裕量均应不小于0，总负裕量应为0。

需要从源码重新运行全部步骤时，在 **Flow Runs** 中右键 `syn_1`，选择 **Reset Runs**，连同关联的 `phy_1` 一并重置，再点击Run。无需在Tcl Console中输入构建命令。

工程采用固定单种子模式，每块板只运行一个种子：

| 参数 | 主板 | 副板 |
|---|---|---|
| 综合 `pack_effort` | high | medium |
| 布局种子 | 20 | 17 |
| 布局 `effort` | high | high |
| 布局 `hfn_opt_effort` | low | medium |
| 布局 `opt_timing` | high | high |
| 布局 `logic_level_opt` | on | on |
| 布线 `effort` | routability | routability |
| 布线 `hold_fix_iteration` | 12 | TD 默认值 |

物理实现按照“布局 → 布线 → 独立hold修复 → 最终时序分析 → bit生成”的顺序执行。

两块板的位流与对应时序报告均保存在各自的 `release/` 目录。

两块板均已从各自的 `.al` 入口通过绿色 **Run** 完整复建。复建位流与 `release/panel_switches_20261114/` 中的上板确认位流逐字节比对，差异仅为 TD 写入的 `# Date:` 生成时间行。

| 工程 | Setup WNS | Setup TNS | Hold WNS | Hold TNS |
|---|---:|---:|---:|---:|
| 主板拨码版 | +0.059 ns | 0.000 ns | +0.027 ns | 0.000 ns |
| 副板拨码版 | +0.105 ns | 0.000 ns | +0.022 ns | 0.000 ns |

在图形界面重新构建后，TD 将运行结果写入以下目录。

```text
Museum_Main/museum_main_final_Runs/phy_1/seed_20/
  museum_main_final.bit
  museum_main_final_phy.ts
  museum_main_final_pr.timing

Museum_Secondary/museum_secondary_final_Runs/phy_1/seed_17/
  museum_secondary_final.bit
  museum_secondary_final_phy.ts
  museum_secondary_final_pr.timing
```

TD 在运行目录的 `best_result/` 中保存筛选出的实现结果。`release/` 保留发布用位流和最终布线时序报告，供上板和结果核对。

## 上板与配套素材

- 主板 [拨码版 bit](Museum_Main/release/panel_switches_20261114/museum_main_final.bit) · [时序汇总](Museum_Main/release/panel_switches_20261114/museum_main_final_phy.ts) · [详细时序报告](Museum_Main/release/panel_switches_20261114/museum_main_final_pr.timing)
- 副板 [拨码版 bit](Museum_Secondary/release/panel_switches_20261114/museum_secondary_final.bit) · [时序汇总](Museum_Secondary/release/panel_switches_20261114/museum_secondary_final_phy.ts) · [详细时序报告](Museum_Secondary/release/panel_switches_20261114/museum_secondary_final_pr.timing)
- 副板 [倍速与 OSD v02 bit](Museum_Secondary/release/speed_osd_v02/museum_secondary_offline_speed_osd_v02.bit) · [构建与验证记录](Museum_Secondary/release/speed_osd_v02/README.md)

主板支持24位BMP读取、多尺寸图片适配、0.5×／1×／2×缩放、1×／2×／3×讲解、字幕、波形和转场。讲解中按 KEY4，画面收拢并平移回到总览，系统随后重新准备讲解音频和字幕。副板以640×480、30fps播放本地RGB565视频，放大输出至720p；倍速与 OSD v02 的文物视频和讲解字幕均跟随主板倍速，字幕仍以主板讲解进度为准。总览和手动浏览时播放宣传片，进入讲解后副板静音，应急状态下优先显示疏散指引。

手动浏览时，在总览按 KEY2 显示所选文物的全貌，按 KEY3 依次查看三张细节。下一张细节加载完毕后即可切换。最后一次按 KEY3 复用开场全貌帧槽，随后自动回到总览。

### 拨码开关

| 位置 | 开关 | `0` | `1` |
|---|---|---|---|
| 主板 | SW1 | 正常展陈 | 双板应急 |
| 主板 | SW2 | 自动讲解 | 手动切图 |
| 主板 | SW3 | 讲解声音开启 | 主板讲解静音 |
| 主板 | SW4 | 显示叠加层 | 隐藏 OSD、字幕和音频波形 |
| 副板 | SW3 | 导览旁白开启 | 副板导览静音 |
| 副板 | SW4 | 显示叠加层 | 隐藏 OSD、字幕和音频波形 |

主板 SW2 在总览生效，文物页内拨动时在返回总览后应用。SW3 静音期间，画面和字幕按当前进度推进。两板 SW4 的叠加层显隐在帧边界生效，声音继续播放。主板切回显示后沿用 KEY3 设置的总览 OSD 状态。双板应急画面和主板提示音优先。

### 主板TF卡

从网盘获取主板素材后，将 `Museum_Main/assets/TF_CARD/` 内全部31个文件复制到FAT32主板TF卡根目录：

| 文件 | 数量 | 用途 |
|---|---:|---|
| `IMAGE0.BMP`～`IMAGE4.BMP` | 5 | 文物全貌图 |
| `ART0D1.BMP`～`ART4D3.BMP` | 15 | 每件文物三张细节图 |
| `AUDIO0.WAV`～`AUDIO4.WAV` | 5 | PCM16、48kHz、双声道讲解音频 |
| `SUB0.BIN`～`SUB4.BIN` | 5 | 字幕位图、时间轴与切图时刻 |
| `OSDNAME.BIN` | 1 | 文物名称数据 |

编号0～4依次对应越王勾践剑、四羊方尊、金缕玉衣、马踏飞燕（铜奔马）、长信宫灯。

`Museum_Main/assets/字幕/`中的5份SRT采用与现用字幕BIN一致的文字和时间轴；回编后与原BIN逐字节一致。这些SRT供素材编辑使用，主板运行时读取BIN。复制到TF卡的是上述31个文件，不包含外层文件夹和SRT。

### 副板TF卡

副板使用 `ART0.BIN`～`ART4.BIN`、`GUIDE.BIN`、`EVAC.BIN` 和 `SUB0.BIN`～`SUB5.BIN`，共13个文件。从网盘获取副板素材和工具，使用副板工具转换配套视频、音频和字幕，生成后复制到FAT32副板TF卡根目录。

视频包采用MVID v2，字幕采用MSUB v3。`GUIDE.BIN`包含宣传片画面和PCM旁白，文物视频不重复保存主板讲解音轨，应急视频为静音疏散画面。FPGA运行时直接读取离线媒体包，MP4由电脑工具预先转换。源视频不烧录字幕，字幕由板端独立叠加。

## 文件保留与整理

| 内容 | 处理方式 |
|---|---|
| `.al`、`src/`、`constraints/`、`vendor/` | 保留原有相对位置，供TD读取工程、源码、约束和IP依赖 |
| `scripts/`、`sim/`、`seed/` | 保留构建配置、专项仿真和布局种子配置 |
| 外置 `assets`、`tools` | 网盘单独提供，用于TF卡素材准备和媒体转换 |
| `release/` | 保留最终位流、时序汇总和详细时序报告 |
| `*_Runs/`、`log/`、`out/` 及 `.qor` | TD 编译时生成的运行产物 |
| `scripts/verify_gui_config.tcl` | 检查两块板的 TD 工程参数 |

搬移工程时，关闭 TD 后整体复制工程目录，保持两板同级及内部目录结构。使用Git获取含LFS对象的版本时，执行 `git lfs pull`，确认大文件已下载为实际内容。

图形界面综合编译使用TD本身。`scripts/`中的自动发布、媒体工具回归和`sim/`中的专项仿真还需各脚本指定的Python、ModelSim、Icarus Verilog及外置媒体工具开发依赖。

## 许可

项目保留原有Apache-2.0许可。官方IP及参考模块的版权和许可信息保留于 `vendor/`。外置媒体工具的第三方运行库与FFmpeg许可随各工具提供。
