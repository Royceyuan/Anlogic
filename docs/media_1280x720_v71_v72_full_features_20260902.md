# v72：720p 全功能资源优化版

## 结论

当前只维护和发布 v72。它把 v69 的五图缓存、快速切图、七种转场、自动轮播、亮度/对比度、顶部 OSD、原图尺寸 DIM 和 UART 中文字幕接入 v70c 的 1280×720 HDMI / 960×540 SDRAM 链路，并用移位加减替代固定的 960/540 地址乘法，DSP 保持为 5 个。

2026-09-02 上板发现首版 v71/v72 的 720p OSD 字形不可读且字幕不可见。根因是 720p OSD 使用了过度简化的 3x5 字体，同时最终 v26 HDMI 输出寄存器直接取 OSD RGB，绕过了字幕 RGB。当前发布文件已修正为与 v69 一致的 5x7 字模，并让最终输出经过字幕层；原 SHA256 已作废。

随后发现 v72 的 OSD 背板被硬编码为 640 像素宽，字幕缓存窗口也只在居中的 800 像素内循环。当前 r3 修正版将 OSD 改为 1280×16，5×7 文字垂直居中；滚动字幕复用原 800×32 双缓冲和现有串口协议，但运动轨迹覆盖完整 1280 像素宽度，因此没有增加字幕 BRAM。

## 操作

- TF 卡根目录：`IMAGE0.BMP` 至 `IMAGE4.BMP`。
- BMP：24 位、未压缩 Windows BMP，输入上限 1920×1080；加载时等比缩放并居中到 960×540，再输出为真实 1280×720 HDMI 栅格。
- `KEY1`：复位；`KEY2`：切换下一张；`KEY3` / `KEY4`：亮度 / 对比度。
- `SW4=0`：手动切图；`SW4=1`：自动轮播。
- `SW3:SW1`：`000` 淡入淡出、`001` 横向擦除、`010` 纵向擦除、`011` 百叶窗、`100` 棋盘、`101` 中心扩散、`110` 对角擦除、`111` 回退淡入淡出。
- 字幕：继续使用 `tools/字幕发送器.vbs`，协议和 v69 相同；静态字幕居中，滚动字幕从屏幕右端进入并穿过完整 1280 像素宽度。

## 回归证据

- 五图缓存：`PASS five cached frames selected without TF reload`。
- 720p SDRAM / 线缓冲：`SELFTEST_PASS output_active=921600 output_nonzero=921600 raw_active=921600`。
- 1920×1080 BMP 自适应到 960×540：逐像素 `PASS`。
- 2-bit 居中字幕、跨字节像素、CRC 拒绝、1280 全宽滚动：`PASS uart_subtitle_overlay`。
- 720p OSD 全宽、16 行窄背板和 5x7 字形：`PASS osd_1280_full_width_slim_5x7`。
- v26 最终输出确实经过字幕层：`PASS v26 subtitle output route`。
- 全部转场模式单元回归：`PASS: video_transition_mask all modes`。

## 实现报告

| 版本 | LUT | REG | BRAM | BRAM32K | DSP | Setup WNS | Hold WNS | TNS |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| v72 r3 | 12681 / 19600 | 5276 / 19600 | 22 / 64 | 4 / 16 | 5 / 29 | +0.120 ns | +0.030 ns | 0 |

v72 r3 路由 DRC 无多驱动和异常时序路径；SDRAM 本体时钟沿用官方工程的专用局部路由提示，不是本次新增问题。没有添加数据假路径或多周期约束。

时序数值取自流程末端、执行 `fix_hold` 后生成的 `media_pr.status` / `media_pr.timing`。TD 自动提前生成的 `final_timing.rpt` 位于 `fix_hold` 之前，不作为最终发布判据。

## 发布物

- `release/hx4s20_1280x720_v72_resource_optimized.bit`
  - SHA256：`3226099D43AAE624BBAAB9AEA543901316902BC85701E0FD7CBBF1192D4DAA05`
  - 生成时间：`2026-09-02 12:31:03`

硬件状态为 `NOT TESTED`。综合、P&R、STA、DRC、bitgen 和仿真通过不等于已经完成上板验收；需要烧录验证冷启动、五图切换、全部转场、全宽窄版 OSD、静态/滚动字幕和长时间显示。
