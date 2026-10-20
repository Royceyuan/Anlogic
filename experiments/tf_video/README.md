# TF离线视频：原生4位读取测速

当前阶段是只读吞吐量验证，尚未接入博物馆视频播放。当前下载文件为 `secondary_tf_read_probe_gap8.bit`，不输出HDMI，不替换正式Flash版本。原 `secondary_tf_read_probe.bit` 为首次测试版，保留用于对照，不再推荐下载。

## 上板

1. 安全弹出电脑上的TF卡，以JTAG临时下载本目录bit。
2. 下载后再将TF卡插入副板，按KEY1开始。旧SPI工程用过的卡须拔插重新上电。
3. 等LED3亮，回报完整A、C、D页；有F页则回报完整错误值。

- `A0000001`：50MHz高速模式；`A0000000`：仅25MHz
- `C0tttttt`：读取16MiB耗时，tttttt为十六进制毫秒
- `D0008000`：32768块全部通过CRC
- `F0ss00ee`：阶段ss、错误ee

视频文件已准备为TF根目录 `VIDEO0.BIN`，640×360、30fps、RGB565，不能用当前正式博物馆bit播放。读取速度通过后仍需接入FAT32、双缓冲、放大与播放控制。

## 复现

副板根目录运行 `scripts/build_tf_read_probe.ps1`，先仿真再综合布线与生成bit。构建输出在 `_build_tf_read_probe/secondary_tf_read_probe.bit`，本次交付复制为上述gap8名称。工程入口为 `secondary_tf_read_probe.al`，当前成功布线结果在 `seed/tf_read_probe/gap8`。

实板首次报F0910009，重新初始化后报F0920011，分别为CMD8、第一条CMD55应答超时。补充命令间隔检查后，旧代码仿真以“仅2个SD时钟间隔”失败；驱动现统一在发命令前等待8个SD时钟。0ns/14ns返回延迟下的原有测试和新增间隔检查通过。实板是否完全恢复仍待验证。

完整设计、文件格式、素材校验和验证边界见工作区 `记录文档/副板_TF离线视频实施与验证_20261020.md`。

gap8 bit SHA256：`be2f8ee444d448548a8047ae8b373a8e203bb1982fb3477a0e86903f8219ba9a`
