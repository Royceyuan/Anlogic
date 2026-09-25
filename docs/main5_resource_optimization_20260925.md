# MAIN-5 资源优化记录（2026-09-25）

本轮仅处理主板资源占用，不发布 MAIN-5C/5D 上板 bit。已上板通过的 MAIN-5B 诊断 bit 仍使用官方 UDP 栈；MAIN-5C/5D 预备顶层改用定址 UDP/ARP 层，保留官方 TEMAC、RGMII 和收发 FIFO。PC 端地址和 MBP1 报文格式不变：主板 `192.168.10.1:5000`，对端 `192.168.10.2:5000`。

| MAIN-5D 合并综合配置 | LUT | BRAM9K | BRAM32K | DSP |
|---|---:|---:|---:|---:|
| 原始媒体 + 官方 UDP 栈 | 20,626/19,600（105.23%） | 58/64 | 5/16 | 7/29 |
| 算术与协议寄存器优化 + 官方 UDP 栈 | 19,911/19,600（101.59%） | 58/64 | 5/16 | 11/29 |
| 同样优化 + 定址 UDP/ARP | **17,476/19,600（89.16%）** | **56/64** | 5/16 | 11/29 |

复现综合：在仓库根目录将 `scripts/probe_main5d_area.tcl` 输入 `D:\TD_6.2.1\bin\td_commands_prompt.exe`；结果见 `_build_main5d_control/main5d_gate.area`。这是门级面积，不是布局布线或时序验收。轻量链路仅支持单播固定 IPv4/UDP、ARP、无 IP 分片；MBP1 自身 CRC 校验应用报文。

已通过 ModelSim：`run_mbp1_fixed_udp.do`（ARP、UDP 22/38 字节、TX 背压）、`run_mbp1_endpoint_direct.do`、`run_mbp1_main_endpoint.do`、`run_mbp1_codec.do`、`run_mbp1_media_bridge.do`、`run_rgb888_adjust_main5.do`（4000 组像素比对）、`run_fat32_wav_streamer.do`、`run_museum_subtitle_overlay.do`、`run_main5_local_controls.do`、`run_main5_remote.do`。尚需在后续 MAIN-5C/5D 阶段完成完整顶层布局布线、STA、DRC、bitgen 和 PC 模拟副板实板联调。

MAIN-5B 已单独上板通过 `tools/mbp1_pc_peer.py`，其发布 bit SHA-256 为 `E0462C439F4E01E6A7918E6D79AA48DC0A22724ADF74944A9D4311BB1A390F5A`。此结果不代表 MAIN-5C/5D 已通过。
