# 副屏固定竖列重影排查（2026-09-25）

## 已观察

- 用户在原生 720p v2 板测中确认轮播、KEY2/KEY3、讲解中预缓存和 SW4 切换正常；各种图片均有固定位置的竖列错位/重影，偶发白色像素闪点。
- 异常时 LED4 亮、数码管 8008：现有 FIFO 读空锁存没有触发，但不能证明数据内容正确。
- 数码管 5000 的纯 HDMI 彩条 bit 在同一屏幕上没有竖列或白点。它绕过 SD、SDRAM 和图片像素读出；由于布局布线负载不同，尚不能完全排除 HDMI 的负载相关时序。
- 原始 `assets/secondary_exhibit_720p_tf/IMAGE9.BMP` 和 `IMAGE7.BMP` 没有用户圈出的竖列重影。

## 当前边界与假设

- 已知正常边界：纯 HDMI 图案到屏幕。
- 已知异常边界：SD 图片经 SDRAM、异步读 FIFO、RGB565 拆像素到 HDMI。
- 假设 A：128 字读突发边界发生重复/漏读。每行 640 个 32 位字，边界每 128 字即 256 像素出现一次；照片尚不足以精确证明竖列坐标与这些边界重合。
- 假设 B：50 MHz SDRAM 宏的数据采样/竞争或异步 FIFO 在实板上偶发错误；固定竖列与偶发白点可以同时由此解释，但当前没有直接读回错误记录。
- 假设 C：HDMI/像素输出在完整设计负载下出现时序或信号问题；彩条正常降低其可能性，但不能完全排除。

## 本轮实验

- `sim/tb_secondary_native720_read_bursts.v` 用生产读调度器和异步 FIFO，逐字检查一整行 640 字。理想 SDRAM 返回模型下，128 字和 64 字读突发均按序通过。此仿真不包含物理 SDRAM 数据采样。
- 单独构建 `release/hx4s20_secondary_native720_readburst64.bit`：副屏本地顶层的 `.VIDEO_READ_BURST_WORDS(128)` 改为 `64`，数码管固定显示 `8064` 以确认新 bit 已装入；保留 v2 bit 和 SD 图片。候选的其他显示/交互逻辑未修改。若竖列消失或位置/间距改变，优先调查 SDRAM 读突发边界；若完全不变，再做真实 SDRAM 读回校验和像素输出隔离。此候选在实板测试前为 **hardware = NOT TESTED**。

板测时保持同一显示器和 SD 卡，确认 `8064` 后进入同一张金缕玉衣简介图，对比竖列的位置、数量和白点。LED4 应保持点亮；若熄灭，记录画面后烧回 `release/hx4s20_secondary_native720_v2.bit`。

## 对照版构建记录

- ModelSim 10.4：640 字整行依次读出，128 字与 64 字突发均 PASS；编译 0 error / 0 warning，仿真有供应商 FIFO 未连接可选端口的 warning。该模型使用理想 SDRAM 返回，不代表实板通过。
- Tang Dynasty 6.2.168116：`scripts/build_secondary_native720_readburst64_pr.tcl` 新综合及 P&R，setup WNS +425 ps、TNS 0、违例 0；hold WNS +24 ps、TNS 0、违例 0。`scripts/build_secondary_native720_readburst64_bitgen.tcl` 时序/告警门禁通过后生成 bit。
- `release/hx4s20_secondary_native720_readburst64.bit`：629661 字节，SHA-256 `D30DD72E442A171547157C74FBDB1752BDA24122D44F1B92D9F4147D1F3E8981`。实板状态仍为 **NOT TESTED**。
