# 副板倍速与 OSD v02

文物视频在自动讲解时跟随主板的 1×、2×、3× 倍速。加速时在 TF 卡读帧阶段跳过中间帧，输出视频更新目标为 30 帧/秒。副板 OSD 使用已确认的 264 像素布局，第四行显示「显示输出：1280×720 · 60帧」。SW3 静音时隐藏波形。

使用 Tang Dynasty 6.2.168116，器件为 EG4S20BG256。在副板工程目录下先设置 PowerShell 环境变量 `OFFLINE_AV_ROUTE=0`，用 `td_commands_prompt.exe` 运行 `scripts/build_project.tcl` 生成 `_build_secondary/gate.db`。随后设置 `OFFLINE_AV_SEED=23`，运行本目录的 `route.tcl` 进行布局布线。通过最终时序检查后，导入 `_build_secondary/final.db` 并生成 bitstream。

仿真覆盖倍速跳帧、文件末尾回绕、暂停、应急切换、导览音频和 OSD。建立时间余量 +0.102 ns，保持时间余量 +0.022 ns，均无违例。实板验证待完成。
