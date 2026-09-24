# MAIN-3 主板烧录与上板检查

状态：工具链候选，尚未板测。只有用户明确回复 `MAIN-3 BOARD PASS` 后才能标记通过。

## 文件和回退

- MAIN-3 顶层：`src/memory/top_1280x720_main3_interaction.v`；约束：`constraints/top_1280x720_main3_interaction.sdc` 和现有 `constraints/top_1280x720_v73_audio_visualizer.adc`。
- 待测 bit：`release/hx4s20_main3_interaction.bit`，630815 bytes，SHA256 `6B832D403F6D13FFDA802AC1585CA2B444B91C54155C1C54F4F8FF62B115EB3E`；MAIN-2 已通过 bit：`release/hx4s20_main2_lecture.bit`，SHA256 `AA788DDEEC1FE2D40B57DB16E9243513A6C20B034497F9C006B70D39784F39C9`，不要覆盖。
- TF 根目录继续保留现有 `IMAGE0.BMP`～`IMAGE4.BMP`、`ART0D1.BMP`～`ART4D3.BMP`、`AUDIO0.WAV`～`AUDIO4.WAV`、`SUB0.BIN`～`SUB4.BIN`。新增 `OSDNAME.BIN`，只存五件文物名称，不含图片、音频或字幕时间轴。可用 `py tools/generate_museum_osd_names.py --dest E:\OSDNAME.BIN` 独立更新名称；超出 160×16 会报错，不截断。缺失/损坏时显示“文物 0～4”，正常讲解不应受影响。
- 名称包总长 3072 byte：第 0 扇区 `ONAM`、版本 1、数量 5、宽 160、高 16、1bpp；后面五个各 512 byte、按文物 0～4 排列的位图区。每行 20 byte，高位在左；不足 512 byte 的尾部填零。文件可以跨 FAT32 簇。
- 仓库 `release/media/OSDNAME.BIN` 与 `E:\OSDNAME.BIN` 的 SHA256 都是 `600E64D69B35F29B955D43DEA67C93F194C8A0317C6E5BD0DDC05A8F8B268029`。

## 正常流程

记忆方式：KEY1“看”（选择/缩放）、KEY2“播”（确认/暂停）、KEY3“调”（画面预设）、KEY4“复”（故障恢复）。

1. 保持 SW4 非应急位置，SW1～SW3 拨到 000～100 之一，烧录 MAIN-3 bit。应先看到五栏总览；顶部居中约 960×56 的半透明状态面板显示当前高亮文物名称、总览阶段、画面预设、源 BMP 宽×高、`ZOOM1x`。面板不能遮挡字幕或让原五栏边框穿过文字。
2. 总览时 KEY1 按 0→1→2→3→4→0 循环高亮，不能导致数码管重新进入素材加载。KEY2 只有高亮与有效 SW 预载目标一致、图片/WAV/字幕首条就绪时进入；SW=101～111 时保持总览、高亮默认 0，不能误入讲解。
3. 逐件验证“全貌→细节 1→细节 2→细节 3→最终全貌→音频结束后约 1.2 秒→收拢回总览”；转场、图片自适应、字幕时轴应与 MAIN-2 相同。转场期间面板保留上一阶段，结束后的帧边界更新；讲解中拨码预载下一件不能改变面板文物名称或源尺寸。
4. KEY3 每按一次依次切换标准、明亮、高对比、柔和，画面参数与面板名称在同一帧变化，不应改变转场。KEY2 在全貌、任一细节、转场及最终停留时分别暂停/继续：音频、字幕渐变、图片/转场进度和停留计时冻结；暂停时波形归零且隐藏，后台预载仍可运行。继续后从原进度衔接，不额外漂移。
5. 音频讲解中 KEY1 按一次切到中心裁剪 2×，再按回到 1×，适用于全貌和三张细节图；只在帧边界直接切换，不应启动淡入淡出、展开或其他转场，也不应停止音频、退出讲解或改变总览高亮。顶部 OSD 应随实际显示倍率变为 `ZOOM2x/ZOOM1x`。音频结束时自动恢复 1×，确保最终收拢仍从完整全貌开始；新讲解与 KEY4 恢复后也默认 1×。结束后再次进入同一文物、连续两次讲解及更换 SW 再进入不同文物，应持续有正确音频、字幕和名称。
6. 字幕重入回归：分别测试自然结束后第二次进入、KEY4 恢复并重新拨码加载后进入；两种情形都应从首句起显示字幕，连续运行同一文物至少三轮，并更换文物复测。若音频正常但字幕缺失，记录文物编号、此前退出方式及 KEY4/拨码操作顺序。

## 故障恢复

- 在总览、图片/WAV/字幕读取、各转场、暂停、最终停留期间分别按 KEY4。应立即静音并隐藏字幕/波形，待正在写的 SDRAM 突发安全结束后，在帧边界回到有效总览。HDMI 不应失锁，完整总览不应重读；按当前有效 SW 重新预载并可再进入讲解。恢复中重复按 KEY4 不应打断。
- 读卡初始化失败超过约 2 秒时，数码管应显示 `E503`，KEY4 可再次尝试；重新插卡后应能恢复，不必给 FPGA 重新上电。无效拨码不触发预载，拨回 000～100 后应自动加载。
- 快速混合按 KEY1/KEY2/KEY3/KEY4 并改变 SW，至少连续运行五件文物各两轮。特别观察 KEY4 恢复后是否出现“数码管不再加载、KEY2 无响应”的旧故障；若出现，记录具体按键/拨码时序和屏幕/数码管照片，并回退 MAIN-2 bit。

## 工具链复现

在仓库根目录执行 ModelSim：`D:\Modelsim\win64\vsim.exe -c -do "do run_museum_status_osd.do"` 等，工作目录为 `sim`。综合布局布线：把 `scripts/build_main3_interaction_pr.tcl` 内容输入 `D:\TD_6.2.1\bin\td_commands_prompt.exe`；最终检查 `_build_main3_interaction/main3_interaction_pr.status` 与 `main3_interaction_final.timing` 的 setup/hold WNS 非负、TNS 均为 0，再执行 `scripts/build_main3_interaction_bitgen.tcl`。构建目录和根目录自动报告不提交。

本候选版 setup WNS `+170 ps`、hold WNS `+24 ps`、TNS 均 `0`，STA 覆盖 99.77%。综合 LUT `13749/19600`（70.15%），放置后 LUT `13939/19600`（71.12%）、BRAM9K `48/64`、BRAM32K `5/16`、DSP `7/29`；路由 slices `8017/9800`（81.81%）。比原软目标 Slice 80% 略高，用户允许资源有余时适度增加；板测重点关注长时间稳定性。
