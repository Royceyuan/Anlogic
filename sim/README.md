# Simulation Notes

当前 `sim/` 先放最小冒烟仿真入口，后续按模块扩展：

- `tb_top_smoke.v`：顶层骨架冒烟测试
- `run_top_smoke.do`：ModelSim 命令脚本

后续建议继续添加：

- `tb_key_debounce.v`
- `tb_video_timing_640x480.v`
- `tb_scaler_fit.v`
- `tb_transition_engine.v`
- `tb_audio_meter.v`
