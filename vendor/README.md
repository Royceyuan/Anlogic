# 复用的安路参考代码

这里只保留副板正式工程使用的参考代码和 IP：

- `anlogic_lab6/`：Lab6 SDRAM 控制器、FIFO 和帧读写控制。帧读写封装已适配本工程的突发长度、有限帧传输与 FIFO 状态接口，不能视为未修改的原始副本。
- `official_ref/lab_ex_6_tf_sdram_hdmi/`：TF 卡 SPI 读取、视频延迟和 HDMI 发送代码。
- `anlogic_hx4s20_udp/`：官方千兆以太网示例中的 TEMAC、RGMII、收发 FIFO 与时钟模块，来源见该目录的 README。

本工程的固定对端 UDP、MBP1 协议、媒体加载和显示控制位于 `src/`。各参考文件的版权声明保留在原文件中。

请保持这些目录路径：SDRAM 源码通过相对路径引用 `global_def.v`，TEMAC 的 `.ipc` 配置引用同目录的 `TEMAC_CORE_gate.v`。
