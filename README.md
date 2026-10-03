# HX4S20 副屏工程

正式分支：`secondary-main5e`。唯一 TD 工程入口：`hx4s20_secondary_main5e.al`，顶层 `top_secondary_main5e`。当前已验收发布为 `release/hx4s20_secondary_help_fixed720.bit`；本轮用户确认正常，详细输入、位流和验证校验见 `release/manifest_secondary_help_fixed720.json`。

历史已验收的远程说明页版本：`release/hx4s20_secondary_help_v2.bit`，说明页左栏为主板三种模式及拨码，右栏为副板四组按键及拨码，底部为通信与主板实际状态；统一原生字模，不再放大16像素文字。主板工程、协议、原媒体和音画时间轴不变。[布局、资源及上板检查](docs/副板SW4双栏说明页_20261002.md)。上一版 `release/hx4s20_secondary_help.bit` 保留用于回溯。

保留远程双栏说明页 v2、旧手动浏览 bit（SHA256 开头 `41B81E03`）及 v06 发布。旧 bit 的 SW4 本地手动轮播定义仅用于历史回退，不是当前工程的操作定义。[网线重连修复记录](docs/网线重连模式恢复_20261001.md)。

## 使用

1. TF 卡使用 FAT32，根目录放 `IMAGE0.BMP`～`IMAGE9.BMP`、`IMAGEA.BMP`。全部为 1280×720、24 位未压缩 BMP。插入读卡器后，在工程根目录执行：

   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/copy_secondary_native720_to_sd.ps1 -DriveLetter F
   ```

   这会写入 11 张图片并逐文件核对 SHA256。盘符按实际情况修改。
2. 说明页另需 TF 根目录 `IMAGEB.BMP`（160×90、24 位 BMP）。如果卡上缺少该文件，在工程根目录执行 `Copy-Item -LiteralPath assets\secondary_help\IMAGEB.BMP -Destination F:\IMAGEB.BMP`，盘符按实际副板 TF 卡修改。只新增现成说明背景，不重写现有 11 张素材或重新生成字模；四组硬件排版预览在 `assets/secondary_help/preview_group0.png`～`preview_group3.png`。
3. 将 TF 卡安全弹出并插回副板，烧录集成后的 `release/hx4s20_secondary_help_fixed720.bit`。SW4=0 正常展示，SW4=1 双栏操作说明；四组说明同时显示，SW2:SW1 标示当前控制组，四键保留原远程控制。IMAGEB背景与上一版相同，不需重写卡；主板保持当前已验收 bit。
4. 主板预载命令只在后台缓存简介；确认讲解后淡出／淡入对应简介与路线图。应急命令优先直接显示逃生图，红色路线、当前位置及绿色出口周期增强。说明页不暂停主板或后台轮播；应急解除后按 SW4 位置恢复页面。

以太网地址、按键表及电脑模拟主板的操作见 [联调说明](docs/SECONDARY_MAIN5E_联调说明.md)，本轮双板操作及边界见 [静音手动浏览接入与验收](docs/副板静音手动浏览接入与验收_20261001.md)。原 11 张 TF 素材保持不变；缺少说明背景时仅补充 IMAGEB。原始素材保存在 `assets/`，可用 `tools/prepare_secondary_exhibit_720p.py` 和 `tools/prepare_secondary_emergency_720p_v2.py` 重新生成 BMP（需要 Pillow）。

## 重建和验证

在工程根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1
```

默认调用 `D:/TD_6.2.1/bin/td_commands_prompt.exe`（6.2.168116）。其他安装位置使用 `-TD` 参数。脚本先布局布线，再检查时序、警告和输入文件新鲜度，符合条件才生成位流；报告位于 `_build_secondary_help_fixed720_seed6/`。重建输出 `release/hx4s20_secondary_help_fixed720.bit`，保留队友已验收的说明页 v2 和 v06 bit。

回归命令见 [sim/README.md](sim/README.md)。清理后 9 组仿真、15 个用例通过。目录只保留正式工程依赖、素材、必要工具、说明和回归；构建与仿真缓存可重新生成。

2026-10-01本次残留归档见 [工程整理记录](docs/工程残留整理_20261001.md)。当前bit、工程源码、构建脚本及manifest哈希未改变；当前bitgen与发布校验依赖继续保留。

## 当前验收主干（2026-10-03）

远程基线 `769d5b1`，保留队友 SW4 双栏说明、SW3 模式同步、原按键与 MBP1。当前构建把固定 BMP 读取及讲解淡出／淡入与说明页合并，应急仍直接切换。

- 输出：`release/hx4s20_secondary_help_fixed720.bit`；校验及验证记录见 `release/manifest_secondary_help_fixed720.json`。
- 11 张原媒体仍严格要求 1280×720 RGB24；IMAGEB 背景仍为原有 160×90 RGB24，直接读取原生像素后写入原有 BRAM 缓存，不恢复通用缩放器，不改变 SDRAM 的四个帧区域。
- 用户已于 2026-10-03 确认新集成版本“现象没错”。烧录后 SW4 向上显示两栏操作说明，向下恢复正常展示；SW2:SW1 切换当前控制组标示，四键仍向主板发送原功能。
- 预载时仍轮播，主板确认讲解后约半秒淡出／淡入简介，应急中断转场直接显示逃生图，解除后按 SW4 恢复说明页或普通展示。

本轮 15 组仿真、38 项 PASS；布局后 LUT 9905/19600，寄存器 6468/19600，BRAM9K 20/64，BRAM32K 13/16，DSP 5/29，PLL 4/4。setup +309 ps、hold +22 ps，TNS 均为 0。新 bit SHA256 开头 `91A70946`，**硬件：用户反馈通过**。
