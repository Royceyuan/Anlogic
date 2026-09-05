# HX4S20 图片播放器工程索引

## 唯一 TD 入口

直接双击 `hx4s20_800x600_multimedia.al`，在安路 TD 中打开统一工程。

当前选择的顶层是 `top_1280x720_feature_v72_resource_optimized`，包含真实 1280×720 HDMI、五图缓存、转场、亮度/对比度、全宽窄版 OSD 和 UART 中文字幕。

当前只发布资源优化版 `top_1280x720_feature_v72_resource_optimized`。它保持真实 1280×720 HDMI 栅格、960×540 SDRAM 工作帧和五图缓存，DSP 为 5 个；滚动字幕跨完整 1280 像素宽度移动，OSD 背板为 1280×16。发布 bit、SHA256 和回归证据见 `docs/media_1280x720_v71_v72_full_features_20260902.md`；硬件状态为 `NOT TESTED`。

统一工程中仍登记 v66、v67、v68、v69、v71 源文件用于回溯，并全部标记为 `AutoExcluded`；活动顶层和活动 SDC 均为 v72。

## 常用目录

- `src`：RTL 源码
- `constraints`：ADC/SDC 约束
- `scripts`：综合、P&R、bitgen 脚本
- `sim`：仿真与回归
- `release`：保留的发布 bit
- `tools`：BMP 与 UART 字幕工具
- `docs`：设计记录和测试证据

历史构建目录、TD 日志和 ModelSim work 目录已移出工程，当前目录只保留可复现交付所需文件。可恢复归档位于 `D:/Anlogic_information/_hx4s20_multimedia_main_cleanup_20260904`，其 `MANIFEST.csv` 记录了移出的文件。
