# 主板仿真入口

每个 `run_*.do` 是一个可独立执行的 ModelSim 回归入口，文件名直接描述验证职责。运行示例：

```powershell
cd sim
D:\Modelsim\win64\vsim.exe -c -do run_remote_controls.do
```

当前最终产品整理至少回归以下入口：

- `run_remote_controls.do`：远程参数、缩放、暂停和平移控制。
- `run_application_recovery.do`：KEY4 应用恢复和状态清理。
- `run_rgb888_picture_adjust.do`：亮度、对比度、饱和度与色温像素路径。
- `run_video_timing.do`：缩放和 OSD 流水线时序等价性。
- `run_ethernet_control_plane.do`：轻量 UDP/ARP 控制面。

ModelSim 生成的 `work*`、`modelsim.ini`、`transcript` 和运行日志不属于源码，已由 `.gitignore` 排除。
