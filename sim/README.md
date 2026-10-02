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

## 音频波形单热点等效检查

```powershell
D:\Modelsim\win64\vsim.exe -c -do run_audio_visualizer_overlay.do
D:\Modelsim\win64\vsim.exe -c -do run_audio_visualizer_equivalence.do
```

第一项遍历完整 16 位有符号 PCM 域及三种双声道组合，检查限幅、暂停清零和应急红色。第二项从 Git 的 `eb9c1aa` 提取已验收模块作为参考，分别使用行为 RAM 和 `D:\TD_6.2.1\sim_release\eg4` 官方物理 RAM 模型，逐周期对照像素、同步及波形状态。须保留该 Git 提交和安装路径；预期第二项输出两次 `PASS audio visualizer equivalence`，每次检查全部 262144 种纵坐标/柱高组合、99996 个像素周期、72457 次 RAM 读值及 845 个有效显示帧触发。

测试含全部 512 个逻辑 RAM 地址、双时钟、不同相邻柱高、PCM 空档、暂停、复位和应急颜色切换；不替代真实 TF、HDMI 或双板上板验收。

## 应急像素全坐标检查

```powershell
D:\Modelsim\win64\vsim.exe -c -do run_emergency_mode.do
```

`tb_museum_emergency_overlay.v` 每个坐标在独立时钟周期输入，穷举 2048×1024 全输入域，逐拍核对图案、颜色及 hs/vs/de/x/y；同时检查告警 PCM 变化、退出静音、复位及正常 RGB 透传。用于试验区域 ROM 的官方模型入口随未合入候选归档，不作为当前生产 RTL 的 RAM 验证结论；结果见 `docs/reports/emergency_region_single_hotspot_20261002.md`。
