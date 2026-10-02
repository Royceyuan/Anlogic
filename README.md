# HX4S20 副屏工程

正式分支：`secondary-main5e`。唯一 TD 工程入口：`hx4s20_secondary_main5e.al`，顶层 `top_secondary_main5e`。

最新待上板版本：`release/hx4s20_secondary_help.bit`，副板 SW4 切换正常展示／操作说明，TF 背景配合 FPGA 动态文字。主板工程、协议、原媒体和音画时间轴不变。[功能、资源及上板检查](docs/副板SW4操作说明页_20261002.md)。

保留已上板版本 `release/hx4s20_secondary_main5e_manual_browse.bit`（SHA256 开头 `41B81E03`）及 `release/manifest_manual_browse.json`，以及更早的 v06 发布。旧 bit 的 SW4 本地手动轮播定义仅用于历史回退，不是当前工程的操作定义。[网线重连修复记录](docs/网线重连模式恢复_20261001.md)。

## 使用

1. TF 卡使用 FAT32，根目录放 `IMAGE0.BMP`～`IMAGE9.BMP`、`IMAGEA.BMP`。全部为 1280×720、24 位未压缩 BMP。插入读卡器后，在工程根目录执行：

   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/copy_secondary_native720_to_sd.ps1 -DriveLetter F
   ```

   这会写入 11 张图片并逐文件核对 SHA256。盘符按实际情况修改。
2. 说明页另需 TF 根目录 `IMAGEB.BMP`（160×90、24 位 BMP），在工程根目录执行 `py -3 tools/prepare_secondary_help.py --card E:\`，盘符按实际副板 TF 卡修改。只新增说明背景，不重写现有 11 张素材；四组硬件排版预览在 `assets/secondary_help/preview_group0.png`～`preview_group3.png`。
3. 将 TF 卡安全弹出并插回副板，烧录 `release/hx4s20_secondary_help.bit`。SW4=0 正常展示，SW4=1 操作说明；SW2:SW1 切换四组说明，四键始终保留原远程控制。主板保持当前已验收 bit。
4. 主板预载命令只在后台缓存简介；确认讲解后显示对应简介与路线图。应急命令优先显示逃生图，红色路线、当前位置及绿色出口周期增强。说明页不暂停主板或后台轮播；应急解除后按 SW4 位置恢复页面。

以太网地址、按键表及电脑模拟主板的操作见 [联调说明](docs/SECONDARY_MAIN5E_联调说明.md)，本轮双板操作及边界见 [静音手动浏览接入与验收](docs/副板静音手动浏览接入与验收_20261001.md)。不要求电脑有线网卡可用，不需要更换当前 TF 素材。原始素材保存在 `assets/`，可用 `tools/prepare_secondary_exhibit_720p.py` 和 `tools/prepare_secondary_emergency_720p_v2.py` 重新生成 BMP（需要 Pillow）。

## 重建和验证

在工程根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1
```

默认调用 `D:/TD_6.2.1/bin/td_commands_prompt.exe`（6.2.168116）。其他安装位置使用 `-TD` 参数。脚本先布局布线，再检查时序、警告和输入文件新鲜度，符合条件才生成位流；报告位于 `_build_secondary_help_20261002/`。重建仅覆盖说明页 bit，不覆盖已上板手动浏览及 v06 bit。

回归命令见 [sim/README.md](sim/README.md)。清理后 9 组仿真、15 个用例通过。目录只保留正式工程依赖、素材、必要工具、说明和回归；构建与仿真缓存可重新生成。

2026-10-01本次残留归档见 [工程整理记录](docs/工程残留整理_20261001.md)。当前bit、工程源码、构建脚本及manifest哈希未改变；当前bitgen与发布校验依赖继续保留。
