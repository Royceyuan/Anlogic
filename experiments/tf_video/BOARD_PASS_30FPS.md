# 30fps离线视频已验证基线

2026-10-20，用户确认换向保护候选恢复播放后“没有噪点了”。作为后续提高源分辨率的回退基线，保留以下文件，不覆盖：

- 源码与构建检查点：`cec53ed`
- 工程：`secondary_tf_video.al`，顶层`top_secondary_tf_video`
- 已通过bit：`experiments/tf_video/secondary_tf_video_turnaround_guard8.bit`
- bit SHA256：`3078dbe550d90fbd6a8d36fb81b82c1d879463773922a748371f7316119d7854`
- 原生视频：640×360、30fps、RGB565大端、静音，HDMIB输出1280×720
- 配套文件：工作区`素材/离线视频/VIDEO0.BIN`，TF卡根目录同名文件
- 配套文件SHA256：`0a32f84a054bdc0db0c80ed5df2778170d62b3ca6530905227a128d85ab531a6`
- 2471帧，约82.3667秒；每帧460800字节，整文件1138637312字节
- 成功种子与构建报告：`seed/tf_video/turnaround_guard8`
- seed=8，setup +0.105ns、hold +0.030ns、TNS均0；4962 LUT、3303寄存器、8 BRAM9K、0 DSP、2 PLL

上板反馈说明播放和左侧噪点对照通过，不等于仪器实测平均30fps或长时间可靠性统计。正式博物馆入口、Flash和release位流未被此独立工程替换。

从正式SPI读卡工程转入本原生4位测试工程时，先JTAG下载bit，再拔插TF卡，最后按KEY1；仅FPGA复位不能给卡重新上电。F0910009为CMD8应答超时，发生在视频文件读取之前。本次重新上电恢复后未修改SD接口RTL、未重新生成bit。

40fps试验已移入工作区`rubbish/secondary_tf_video_40fps_20261020`，不再推进。本基线后续升级使用独立命名bit和素材；源码回退以本条所列检查点为准，不能将后续未验证的工作树当作已上板版本。
