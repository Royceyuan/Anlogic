# PC源帧判定缺陷复现

日期：2026-10-09。旧候选3967cf0，bit SHA开头4C311166；新候选SHA开头695D0D25，尚待上板。

## 实板证据

用户视频路径：`D:/QQ_Documents/Tencent Files/1240053410/nt_qq/nt_data/Video/2026-10/Ori/99dc494ecb66bc8f46bee7cf5468498d.mp4`；1851041字节，SHA256 `83E771C3B63E002D49EB3F238E03B80924884D0AFCB5D0F0379E8BEFF6F1AEF4`，6.1秒。这里只记录路径和读数，原用户视频未纳入仓库。

抽帧读到：1220、BFD0、AFEE/AFEF、C777/C711，后续相位继续循环。此前用户报告屏幕无信号、LED2/3常亮、LED4灭。1220对应约74.25MHz；A页R=E为时钟有效、PLL锁定、三通道对齐但格式无效。C页高7为接收/采样允许、sink读值高而TX未释放；末两位为通道偏移7/7或1/1。由此定位帧判定阻止输出，未证明实际像素流内容或唯一根因。

## 可执行复现

在`sim`目录运行ModelSim的`run_hdmi_tmds_monitor.do`，默认旧案例及PC_PAYLOAD=1案例均执行。PC_PAYLOAD用192×16缩短几何，包含96字符合法RGB、八字符前导、双字符保护带、32字符TERC4样式载荷及视频前导。不是有效LPCM/BCH数据包。

RGB：R/G=55→133，B=6d/6c/ba→28e/271/2c3；均为平衡TMDS码，运行差异维持0。没有数据岛前导的有效视频不可被当成数据岛。旧RTL失败：locked=1、offsets=111、line_bad=1、good=0，日志`monitor_alias_before.log`。修正后六条监测PASS，日志`monitor_alias_after.log`。

修正只增加四位前导计数及开始条件：[HDMI 1.3 §5.2.1.1、5.2.3](https://fpga.mit.edu/6205/_static/F23/common_files/week04/CEC_HDMI_Specification.pdf)。前导CTL0:3=1010，通道1/2控制码均0ab。数据岛内才允许解释TERC4中的同步位，普通RGB中同样码值不会产生假的HS/VS。不改变RAW发送、PLL、EDID或生产版帧几何门槛。

顶层四路位流测试也加入合法RGB碰撞和标准长度前导；平坦颜色的十位重复可导致自动延迟匹配歧义，故在变化的packet词处开始匹配，不修改发送逻辑掩盖测试问题。2000次比较仍为共同11UI。五组共37条PASS。

最终种子10，lane0/3固定2×4布局，内部setup +0.041ns、hold +0.054ns、TNS=0。LUT1062、FF698、Slice645、BRAM9K1、PLL1；无多驱动和异常时序路径。动态首级采样/固定输入延时6的电气眼图仍须实板验收。未宣称已修好全部PC源故障，未集成博物馆，未push。
