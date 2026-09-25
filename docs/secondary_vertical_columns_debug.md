# 副屏固定竖列重影排查（2026-09-25）

## 已观察

- 用户在原生 720p v2 板测中确认轮播、KEY2/KEY3、讲解中预缓存和 SW4 切换正常；各种图片均有固定位置的竖列错位/重影，偶发白色像素闪点。
- 异常时 LED4 亮、数码管 8008：现有 FIFO 读空锁存没有触发，但不能证明数据内容正确。
- 数码管 5000 的纯 HDMI 彩条 bit 在同一屏幕上没有竖列或白点。它绕过 SD、SDRAM 和图片像素读出；由于布局布线负载不同，尚不能完全排除 HDMI 的负载相关时序。
- 原始 `assets/secondary_exhibit_720p_tf/IMAGE9.BMP` 和 `IMAGE7.BMP` 没有用户圈出的竖列重影。

## 当前边界与假设

- 已知正常边界：纯 HDMI 图案到屏幕。
- 已知异常边界：SD 图片经 SDRAM、异步读 FIFO、RGB565 拆像素到 HDMI。
- 假设 A：128 字读突发边界发生重复/漏读。每行 640 个 32 位字，边界每 128 字即 256 像素出现一次；照片尚不足以精确证明竖列坐标与这些边界重合。64 字候选上板后竖列完全不变，故该假设的支持度下降。
- 假设 B：50 MHz SDRAM 宏的数据采样/竞争或异步 FIFO 在实板上偶发错误；固定竖列与偶发白点可以同时由此解释，但当前没有直接读回错误记录。
- 假设 C：HDMI/像素输出在完整设计负载下出现时序或信号问题；彩条正常降低其可能性，但不能完全排除。

## 本轮实验

- `sim/tb_secondary_native720_read_bursts.v` 用生产读调度器和异步 FIFO，逐字检查一整行 640 字。理想 SDRAM 返回模型下，128 字和 64 字读突发均按序通过。此仿真不包含物理 SDRAM 数据采样。
- 单独构建 `release/hx4s20_secondary_native720_readburst64.bit`：副屏本地顶层的 `.VIDEO_READ_BURST_WORDS(128)` 改为 `64`，数码管固定显示 `8064` 以确认新 bit 已装入；保留 v2 bit 和 SD 图片。用户报告竖列完全不变、LED4 亮；回复中未单独写明 8064 读数，因此这个对比以新 bit 确实加载为前提。
- 下一边界测试为 `release/hx4s20_secondary_native720_fullframe_diag.bit`：不读 SD 卡，按正常 50 MHz SDRAM 时钟写入一帧 1280×720 RGB565 大小的 460800 个已知 32 位字，经真实 SDRAM 和读 FIFO 全部读回比较。读写突发分别保持生产值 128/16。初始 HDMI 蓝屏；通过后绿屏、数码管 `6xxx`、LED4 亮；首个错误后红屏、数码管 `Fxxx`、LED4 灭。`Fxxx` 的低 12 位是首错字地址低位，完整地址寄存器保留在 RTL 中。此候选仍需实板测试；它不覆盖 SD 解码/写图逻辑，读 FIFO 时钟也为 50 MHz 而非正式显示的 75 MHz。

整帧诊断只需 SRAM 烧录，SD 卡可以保持原样。记录最终屏幕颜色、数码管和 LED4；如一直蓝屏，也需记录停留时间和数码管。测试后烧回 `release/hx4s20_secondary_native720_v2.bit` 即可恢复原有展示。

## 对照版构建记录

- ModelSim 10.4：640 字整行依次读出，128 字与 64 字突发均 PASS；编译 0 error / 0 warning，仿真有供应商 FIFO 未连接可选端口的 warning。该模型使用理想 SDRAM 返回，不代表实板通过。
- Tang Dynasty 6.2.168116：`scripts/build_secondary_native720_readburst64_pr.tcl` 新综合及 P&R，setup WNS +425 ps、TNS 0、违例 0；hold WNS +24 ps、TNS 0、违例 0。`scripts/build_secondary_native720_readburst64_bitgen.tcl` 时序/告警门禁通过后生成 bit。
- `release/hx4s20_secondary_native720_readburst64.bit`：629661 字节，SHA-256 `D30DD72E442A171547157C74FBDB1752BDA24122D44F1B92D9F4147D1F3E8981`。实板报告：竖列完全不变、LED4 亮；8064 读数未单独确认。
- 整帧诊断顶层 ModelSim 10.4 语法编译 0 error / 0 warning；Tang Dynasty 6.2.168116 新综合、P&R 后 setup WNS +757 ps、TNS 0、违例 0；hold WNS +30 ps、TNS 0、违例 0；保留供应商宏的既有告警，未见 multi-drive 或异常时序路径。
- `release/hx4s20_secondary_native720_fullframe_diag.bit`：629654 字节，SHA-256 `9E940BD6B50793D4D4C027038B25BE3023E5FF3CDE572E212C11BAA0F1F91CD7`。用户实板重复报告 **红屏、F000、LED4 灭**。F000 只提供首错字地址的低 12 位；首错并不一定在地址 0，也可能在 4096 的倍数。
- `sim/tb_secondary_fullframe_rw_path.v` 对生产写/读控制器及异步 FIFO 接入理想一周期 SDRAM，检查 1280 个连续字，ModelSim PASS。它覆盖诊断器使用的请求、FIFO 和比较节奏，不覆盖加密 SDRAM 宏与板上存储芯片。
- `release/hx4s20_secondary_native720_fullframe_detail.bit` 保持相同读写测试，在数码管上由 SW1～SW3 选择更完整的诊断值：`000` 为首错地址低 16 位，`001` 为首错地址高 3 位，`010`/`011` 为首错实际数据低/高 16 位，`110` 为错误总数（最多 65535），`111` 固定 `D123` 用于确认本 bit 已加载。SW1 是最低位。ModelSim 顶层语法编译 0 error / 0 warning；新 P&R setup WNS +751 ps、hold WNS +23 ps，TNS 与违例数均为 0；SHA-256 `C3DB16A14E7ECC53B1656CD38658CCA155281B802FCFF597C0E21EDB461F2B6D`。实板状态 **NOT TESTED**。
