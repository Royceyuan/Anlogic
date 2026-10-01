# HX4S20 副屏工程

正式分支：`secondary-main5e`。唯一 TD 工程入口：`hx4s20_secondary_main5e.al`，顶层 `top_secondary_main5e`。

当前完整版为 `release/hx4s20_secondary_main5e_return_align_v06.bit`，包含以太网控制、原生 720p 显示、自动/手动轮播及 SDRAM 返回对齐修复。2026-10-01 用户确认当前板上效果正常；构建与验证记录见 `release/manifest.json`。

## 使用

1. TF 卡使用 FAT32，根目录放 `IMAGE0.BMP`～`IMAGE9.BMP`、`IMAGEA.BMP`。全部为 1280×720、24 位未压缩 BMP。插入读卡器后，在工程根目录执行：

   ```powershell
   powershell -ExecutionPolicy Bypass -File tools/copy_secondary_native720_to_sd.ps1 -DriveLetter F
   ```

   这会写入 11 张图片并逐文件核对 SHA256。盘符按实际情况修改。
2. 将 TF 卡插回副板，SRAM 烧录上述 v06 bit。SW4 向下自动轮播五张文物大图；向上停用自动轮播，用 KEY1 切下一张。
3. 主板预载命令只在后台缓存简介；确认讲解后显示对应简介与路线图。应急命令优先显示逃生图，红色路线、当前位置及绿色出口周期增强。简介页按键保持主板画面控制功能。

以太网地址、按键表及电脑模拟主板的操作见 [联调说明](docs/SECONDARY_MAIN5E_联调说明.md)。原始素材保存在 `assets/`，可用 `tools/prepare_secondary_exhibit_720p.py` 和 `tools/prepare_secondary_emergency_720p_v2.py` 重新生成 BMP（需要 Pillow）。

## 重建和验证

在工程根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1
```

默认调用 `D:/Anlogic/TD5.6.2/bin/td_commands_prompt.exe`（实际工具版本 6.2.168116）。其他安装位置使用 `-TD` 参数。脚本先布局布线，再检查时序、警告和输入文件新鲜度，符合条件才生成位流；报告位于 `_build_secondary_main5e_return_align_v06_seed6/`。重建会覆盖 release 中的 bit，manifest 记录的是本次发布位流。

回归命令见 [sim/README.md](sim/README.md)。清理后 9 组仿真、15 个用例通过。目录只保留正式工程依赖、素材、必要工具、说明和回归；构建与仿真缓存可重新生成。
