# HX4S20 图片播放器工程索引

## 唯一 TD 入口

直接双击 `hx4s20_museum_terminal.al`，在安路 TD 中打开统一工程。

当前选择的顶层是 `top_1280x720_main4_emergency`，在 MAIN-3 板测基线上增加 SW4 应急抢占、应急提示画面、独占告警音和红色波形。

当前 MAIN-4 发布文件为 `release/hx4s20_main4_emergency.bit`；验证、资源、时序、SHA256 与上板步骤见 `docs/main4_board_check.md`。MAIN-3、MAIN-2、MAIN-1 和 MAIN-0 的已板测 bit 均保留作为回退。

统一工程中仍登记 640×480、800×600 和 v66～v73 历史源文件用于回溯；这些名称与其实际历史输出分辨率一致。当前活动顶层和活动 SDC 均为 MAIN-4。

## 常用目录

- `src`：RTL 源码
- `constraints`：ADC/SDC 约束
- `scripts`：综合、P&R、bitgen 脚本
- `sim`：仿真与回归
- `release`：保留的发布 bit
- `tools`：BMP 与 UART 字幕工具
- `docs`：设计记录和测试证据

历史构建目录、TD 日志和 ModelSim work 目录已移出工程，当前目录只保留可复现交付所需文件。可恢复归档位于 `D:/Anlogic_information/_hx4s20_multimedia_main_cleanup_20260904`，其 `MANIFEST.csv` 记录了移出的文件。
