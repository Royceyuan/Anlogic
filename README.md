# 双FPGA博物馆双屏展陈与应急信息终端

基于安路 HX4S20C（EG4S20BG256）开发板的全离线双板系统。主板负责图片浏览和语音讲解，副板负责本地视频、字幕与导览音频；两板通过以太网交换状态和控制信息，HDMI 均输出 1280×720。

## 目录与工程入口

```text
Museum_Dual_FPGA/
├─ Museum_Main/                  主板工程
│  ├─ museum_main_final.al       TD 正式入口
│  ├─ src/ constraints/ vendor/  RTL、约束和官方依赖
│  ├─ scripts/ sim/ seed/        构建、仿真和匹配种子
│  ├─ tools/MuseumTFPackager/    主板 TF 素材打包工具
│  └─ release/museum_main_final/ 当前选用 bit 与 SHA-256
├─ Museum_Secondary/             副板工程
│  ├─ museum_secondary_final.al  TD 正式入口
│  ├─ src/ constraints/ vendor/  RTL、约束和官方依赖
│  ├─ scripts/ sim/ seed/        构建、仿真和匹配种子
│  ├─ tools/OfflineVideo/        副板离线媒体打包工具
│  ├─ assets/视频/              本地自备视频目录，不上传
│  ├─ assets/音频/              六份配套音频
│  ├─ assets/字幕/              六份独立字幕
│  └─ release/museum_secondary_final/
├─ docs/技术报告.pdf
└─ LICENSE
```

两个工程需保持同级目录。主板构建入口复用副板目录中的发布和验证脚本；各工程只有一个 `.al` 入口和一份选用 bit。

## 获取完整文件

工程包含 Git LFS 文件。克隆后需拉取 LFS 内容，否则 bit、音频、数据库和打包工具的大文件可能只是指针文件。七支源视频仅在本地保留，不进入仓库。

```powershell
git lfs install
git clone https://github.com/Royceyuan/Anlogic.git
cd Anlogic
git lfs pull
```

## 运行与素材

主板支持 TF 卡 24 位 BMP 读取、多尺寸图片适配、0.5×／1×／2×缩放、1×／2×／3×讲解、字幕、波形与转场。副板以 640×480、30fps 播放本地 RGB565 视频，放大输出至 720p；讲解时视频保持正常速度，字幕跟随主板进度。总览和手动浏览时播放宣传片，进入讲解时副板静音，进入应急时切换疏散画面。

- [主板 bit](Museum_Main/release/museum_main_final/museum_main_final.bit)
- [副板 bit](Museum_Secondary/release/museum_secondary_final/museum_secondary_final.bit)
- [主板素材工具](Museum_Main/tools/MuseumTFPackager/MuseumTFPackager.exe)
- [副板素材工具](Museum_Secondary/tools/OfflineVideo/MuseumOfflinePackager.exe)
- [技术报告](docs/技术报告.pdf)

主板卡使用 20 张 BMP、5 份 WAV、5 份字幕数据及 OSD 名称数据，由主板工具生成。副板卡使用 `ART0.BIN`～`ART4.BIN`、`GUIDE.BIN`、`EVAC.BIN` 和 `SUB0.BIN`～`SUB5.BIN`，由副板工具生成；FPGA 不直接解码 MP4。视频包为 MVID v2，字幕为独立 MSUB v3；宣传片包包含 PCM 音频，其余文物视频不重复保存讲解音轨。

七支源视频需自行准备：五件文物、总览宣传片和应急疏散视频，在副板工具中分别选择即可。推荐输入 MP4／H.264，画面不烧录字幕；总览宣传片保留声音，文物与应急视频使用静音版本。工具统一转换为 FPGA 所需的 640×480、30fps 数据，无需自行修改编号映射。

副板工具的写卡脚本会校验目标卡身份并备份旧文件，当前默认匹配本项目原副板卡。更换为其他卡时须先核实并调整目标卡识别信息，不应直接跳过校验。此仓库不包含已经写入 TF 卡的大型 BIN 包。

## 构建与验证

现有脚本默认使用 TD 6.2.168116、ModelSim、Icarus Verilog 与 Python；具体工具路径可在 `scripts/build.ps1` 参数中设置。媒体转换使用随附 FFmpeg，Python 工具需要 Pillow。主板打包工具的离线语音对齐运行库随工具保留。

从仓库根目录先检查工程依赖：

```powershell
.\Museum_Main\scripts\build.ps1 -CheckOnly
.\Museum_Secondary\scripts\build.ps1 -CheckOnly
```

去掉 `-CheckOnly` 执行综合、布局布线及发布门禁。新构建输出到独立候选目录，不覆盖当前选用 bit。TD 脚本入口均为各工程的 `scripts/build_project.tcl`；临时构建目录为 `_build_main` 和 `_build_secondary`。

匹配当前交付版本的布局种子：主板 **5**、副板 **9**，默认配置位于 `seed/formal/build_config.tcl`，对应重布线脚本位于 `seed/matched_release/route.tcl`。重布线脚本需先有匹配的综合数据库，不能替代从源码构建。

专项回归入口：

```powershell
.\Museum_Main\scripts\verify_zoom.ps1
.\Museum_Secondary\scripts\verify_offline_media.ps1
```

验证区分仿真、布局布线和实板结果。主板与副板 RTL、约束、工具运行库及交付 bit 在本次目录合并中不作功能修改。

## 许可

项目保留原有 Apache-2.0 许可。官方 IP、随附运行库与 FFmpeg 的许可证、版权声明分别保留于 `vendor` 和工具目录内。
