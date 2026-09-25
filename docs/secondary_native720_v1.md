# 副屏原生 720p 候选版（2026-09-25）

## 改动与容量

- HDMI 仍输出 1280×720；BMP 读取、SDRAM 帧和显示现在均为 1280×720，不再经过 960×540 缩小再放大。
- SDRAM 使用 50 MHz、144° 相位的专用 PLL。该改动仅在副屏构建项目中启用。
- 8 MiB SDRAM 按 32 位字分配：两张轮播文物图各 460800 字，预缓存简介图 460800 字，逃生图 460800 字，共 1843200 / 2097152 字。五张文物图仍轮播，但仅缓存当前图和下一张图。
- SD 卡根目录 `IMAGE0.BMP`～`IMAGE4.BMP` 是五张文物图，`IMAGE5.BMP`～`IMAGE9.BMP` 是对应简介，`IMAGEA.BMP` 是用户提供的逃生图；11 张均为 1280×720、24 位 BMP。

## 构建和校验

- 工程：`hx4s20_secondary_native720_phase144.al`；顶层：`top_1280x720_secondary_local`。
- 综合与布局布线：`scripts/build_secondary_native720_final_pr.tcl`；bitgen：`scripts/build_secondary_native720_final_bitgen.tcl`。bitgen 脚本会检查本次布局布线记录及时序门槛。
- Tang Dynasty 6.2.168116 实际最终时序：setup WNS +341 ps、TNS 0、违例 0；hold WNS +38 ps、TNS 0、违例 0。记录在 `_build_secondary_native720_final/secondary_native720_final_pr.status`。
- ModelSim 已通过：720p HDMI 时序、SD/BMP 加载首张及逃生图、轮播缺页等待与讲解保持、原有转场测试。仿真不能代替实板持续播放检查。
- 新 bit：`release/hx4s20_secondary_native720_v1.bit`，SHA-256 `748E55FE2A59F3DD71E65889F31A0181C91C8DF9F5EFE7EA0D9F8F1B3B88C3B5`。
- 回退 bit：`release/hx4s20_secondary_local_info720_v6.bit`，SHA-256 `CF747D1E7985966A46414903C52CA527DEA8EA76EC2280C61215946194CE550D`，未修改。
- 2026-09-25 已将 11 张 BMP 写入 F: SD 卡，并逐文件与源文件做 SHA-256 比对。重新插卡时可运行 `tools/copy_secondary_native720_to_sd.ps1 -DriveLetter F`，先确认盘符确为 SD 卡。

## 实板操作与预期

1. 安全弹出 SD 卡，插回副屏板 TF 卡槽；通过 Tang Dynasty SRAM 下载新 bit。
2. 上电后先等首图从 SD 卡载入。空闲时五张文物大图按顺序轮播，约每张 5 秒；下一张未载入完时应保持当前图，载入后再切换，转场特效保留。
3. SW1～SW3 设为 0～4，触发对应简介图后台预缓存，轮播应继续。预缓存完成后按 KEY2，进入该文物的简介与路线图；按 KEY3 返回轮播。
4. SW4 切到紧急位置，显示 `IMAGEA.BMP` 逃生路线；恢复 SW4 后回到轮播。
5. 重点检查整屏清晰度、简介文字、五图持续轮播、按键切换、逃生图，以及长时间显示是否出现撕裂、花屏或读图超时。记录数码管与 LED 状态。

本地预览尚未接入主板以太网接收器，底部显示 `MAIN LINK LOST` 属于当前预览模式的链路状态提示。

当前状态：**构建和仿真通过；实板未验证**。50 MHz SDRAM 的时序闭合仅说明 FPGA 内部静态时序满足约束，不能证明 SDRAM 芯片在实板上持续读写稳定。若新 bit 实板失败，恢复上述回退 bit 并保留错误画面/数码管/LED 记录。
