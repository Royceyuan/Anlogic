# MAIN-5B 独立 MBP1 协议诊断

本 bit 是独立网络诊断入口，不显示展陈画面，不会覆盖已经板测通过的 MAIN-5 本地控制 bit。其主板地址为 `192.168.10.1:5000`，电脑模拟副板使用 `192.168.10.2:5000`。

- bit：`release/hx4s20_main5b_mbp1_diag.bit`
- SHA-256：`5DAF7C97258D35901618B63DB6545A98736B8CA763693A551F8AE4F1C8671A15`
- 回退 bit：`release/hx4s20_main5_local_controls.bit`
- ModelSim：`sim/run_mbp1_codec.do`、`sim/run_mbp1_main_endpoint.do`、`sim/run_mbp1_main_endpoint_control.do`，均 PASS。
- TD 6.2.1 seed 17：setup WNS `+69 ps`、hold WNS `+22 ps`，TNS 均为 0；LUT `5921/19600`、BRAM9K `10/64`、BRAM32K `0/16`、DSP `0/29`。

电脑有线网卡设为 `192.168.10.2/24`，网线直连主板。烧录本 bit 后，在仓库根目录运行：

```powershell
py -3 .\tools\mbp1_pc_peer.py
```

脚本发送 HELLO、STATUS_QUERY、重复查询、错误 CRC、错误长度、DISPLAY_PRESET、HEARTBEAT 和新 boot_id 会话；期待各项 `PASS`。本独立诊断版未连接媒体工程，`DISPLAY_PRESET` 应回 `UNSUPPORTED=3`，不是主板调参故障。若电脑报 `WinError 10013`，检查 UDP 5000 是否仍被 NI Domain Service 等进程占用；不要关闭整个 Windows 防火墙。

本轮只完成离线仿真、综合和可烧录 bit 生成；尚无该 bit 的实际 PC↔主板结果，不能记录 `MAIN-5B MBP1 PASS`。MAIN-5C/5D 也尚未完成。

资源预检：媒体工程与当前官方完整 UDP 栈直接并置时，尚未加入远程调参就达到 `18889/19600 LUT`（96.37%），4/4 PLL、58/64 BRAM9K。该探针仅做综合面积估计，未布线，也不是可烧录设计。须先减少网络/媒体资源并完成合并时序验证，再发布 5C/5D bit。
