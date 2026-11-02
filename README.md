# 双FPGA博物馆双屏展陈与应急信息终端

基于安路HX4S20C（EG4S20BG256）开发板的全离线双板系统。主板负责文物图片浏览、语音讲解与字幕显示，副板负责本地视频、导览音频和应急疏散画面。两板通过以太网交换操作指令、运行状态和讲解进度，双屏均输出1280×720画面。

## 目录与工程入口

```text
Museum_Dual_FPGA/
├─ Museum_Main/
│  ├─ museum_main_final.al        主板工程入口
│  ├─ src/                        RTL源码
│  ├─ constraints/                引脚与时序约束
│  ├─ vendor/                     官方IP和参考模块
│  ├─ scripts/ sim/ seed/         构建、仿真和匹配种子资料
│  ├─ assets/TF_CARD/             主板TF卡配套文件，共31个
│  ├─ assets/字幕/                与现用BIN匹配的5份SRT
│  ├─ reports/                   最终报告、对应bit与历史构建记录
│  └─ release/museum_main_final/  已选用的主板bit
├─ Museum_Secondary/
│  ├─ museum_secondary_final.al   副板工程入口
│  ├─ src/ constraints/ vendor/   RTL、约束和IP依赖
│  ├─ scripts/ sim/ seed/         构建、仿真和匹配种子资料
│  ├─ assets/视频/                七支配套源视频
│  ├─ assets/音频/                六份配套音频
│  ├─ assets/字幕/                六份配套字幕
│  ├─ reports/                   最终报告、对应bit与历史构建记录
│  └─ release/museum_secondary_final/
├─ docs/main.pdf                 技术报告
└─ LICENSE
```

两板工程保持同级目录，工程内部文件沿用现有名称和相对位置。主板和副板媒体制作工具单独提供，位于工程目录外。

## 软件复建

使用 **Anlogic TD 6.2.1（6.2.168116）**。图形界面复建所需的综合、布局和布线参数已保存到两个工程入口。

1. 打开 `Museum_Main/museum_main_final.al` 或 `Museum_Secondary/museum_secondary_final.al`。
2. 若出现“private parameters are not default”提示，选择 **Cancel**，保留工程中的种子和逻辑优化参数。**Revert**会将这些参数恢复默认值。
3. 若出现 **Flow Step Recovery** 提示，选择 **OK**，恢复已有构建步骤和结果。
4. 点击顶部绿色 **Run** 箭头，执行综合、布局、布线及bit生成。软件弹出任务数量或重置运行数据提示时，确认后继续。
5. 完成后查看 **Multi-Seed Result** 中的最终时序和bit。Setup、Hold的最差裕量均应不小于0，总负裕量应为0。

需要从源码重新运行全部步骤时，在 **Flow Runs** 中右键 `syn_1`，选择 **Reset Runs**，连同关联的 `phy_1` 一并重置，再点击Run。无需在Tcl Console中输入构建命令。

工程采用固定单种子模式，每块板只运行一个种子：

| 参数 | 主板 | 副板 |
|---|---|---|
| 综合 `pack_effort` | high | medium |
| 布局种子 | 5 | 9 |
| 布局 `effort` | high | high |
| 布局 `opt_timing` | high | high |
| 布局 `logic_level_opt` | on | on |
| 布线 `effort` | routability | routability |

物理实现按照“布局 → 布线 → 独立hold修复 → 最终时序分析 → bit生成”的顺序执行。

2026年11月2日，两板均已完成重新综合、布局布线和bit生成，并完成复建确认。最终时序结果如下：

| 工程 | Setup WNS | Setup TNS | Hold WNS | Hold TNS |
|---|---:|---:|---:|---:|
| 主板 | +0.129 ns | 0.000 ns | +0.022 ns | 0.000 ns |
| 副板 | +0.115 ns | 0.000 ns | +0.021 ns | 0.000 ns |

图形界面生成的结果位于：

```text
Museum_Main/museum_main_final_Runs/phy_1/seed_5/
  museum_main_final.bit
  museum_main_final_phy.ts
  museum_main_final_pr.timing

Museum_Secondary/museum_secondary_final_Runs/phy_1/seed_9/
  museum_secondary_final.bit
  museum_secondary_final_phy.ts
  museum_secondary_final_pr.timing
```

`best_result/`保存TD筛选出的实现结果。`release/`保留已选用的bit，新构建结果输出到运行目录。布局阶段的中间时序报告与最终布线报告分别保存，验收采用最终布线及hold修复后的结果。

两板工程内均保留一份固定归档：

```text
reports/
├─ final_20261102/       最终通过的报告与对应bit
│  ├─ final_timing.rpt   最终详细时序报告
│  ├─ final_timing.ts    Setup/Hold汇总
│  ├─ resources.area    最终资源报告
│  ├─ *.bit             与报告对应的位流
│  └─ …                 QoR、回标ADC、运行日志和设置
└─ previous_20261102/    整理前根目录的报告、QoR及out回标文件
```

`final_20261102/`中的文件与已通过的固定种子运行结果逐文件校验一致，作为最终报告和对应bit的备份。`previous_20261102/`保留历史记录，其中原根目录的`final_timing.rpt`为Hold尚未通过的旧报告。TD运行目录继续保留，后续构建仍按原路径生成文件。

## 上板与配套素材

- [已选用的主板bit](Museum_Main/release/museum_main_final/museum_main_final.bit)
- [已选用的副板bit](Museum_Secondary/release/museum_secondary_final/museum_secondary_final.bit)
- [技术报告](docs/main.pdf)

主板支持24位BMP读取、多尺寸图片适配、0.5×／1×／2×缩放、1×／2×／3×讲解、字幕、波形和转场。副板以640×480、30fps播放本地RGB565视频，放大输出至720p；文物视频保持1×播放，讲解字幕跟随主板进度。总览和手动浏览时播放宣传片，进入讲解后副板静音，应急状态下优先显示疏散指引。

### 主板TF卡

将 `Museum_Main/assets/TF_CARD/` 内全部31个文件复制到FAT32主板TF卡根目录：

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

副板使用 `ART0.BIN`～`ART4.BIN`、`GUIDE.BIN`、`EVAC.BIN` 和 `SUB0.BIN`～`SUB5.BIN`，共13个文件。使用外置副板工具转换配套视频、音频和字幕，生成后复制到FAT32副板TF卡根目录。

视频包采用MVID v2，字幕采用MSUB v3。`GUIDE.BIN`包含宣传片画面和PCM旁白，文物视频不重复保存主板讲解音轨，应急视频为静音疏散画面。FPGA运行时直接读取离线媒体包，MP4由电脑工具预先转换。源视频不烧录字幕，字幕由板端独立叠加。

## 文件保留与整理

| 内容 | 处理方式 |
|---|---|
| `.al`、`src/`、`constraints/`、`vendor/` | 保留原有相对位置，供TD读取工程、源码、约束和IP依赖 |
| `scripts/`、`sim/`、`seed/` | 保留构建配置、专项验证和匹配数据库资料 |
| `assets/`、`release/` | 保留配套运行素材和已选用的bit |
| `reports/final_20261102/` | 保留最终通过的报告及其对应bit，用于交付和结果核对 |
| `reports/previous_20261102/` | 保留历史构建记录，不参与综合和布局布线 |
| `*_Runs/`、`_build_main/`、`_build_secondary/`、`log/`及生成的时序报告、`.qor` | 编译产物，可重新生成；整理前保存需要使用的bit和最终报告 |
| `scripts/verify_gui_config.tcl` | 配置检查辅助脚本，不参与RTL综合 |

搬移工程时，关闭TD后整体复制 `Museum_Dual_FPGA`，保持两板同级及内部目录结构。使用Git获取含LFS对象的版本时，执行 `git lfs pull`，确认大文件已下载为实际内容。

图形界面综合编译使用TD本身。`scripts/`中的自动发布、媒体工具回归和`sim/`中的专项仿真还需各脚本指定的Python、ModelSim、Icarus Verilog及外置媒体工具开发依赖。

## 许可

项目保留原有Apache-2.0许可。官方IP及参考模块的版权和许可信息保留于 `vendor/`。外置媒体工具的第三方运行库与FFmpeg许可随各工具提供。
