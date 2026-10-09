# 官方 HDMI 环出 EDID 子集

来源：`HX4S20_Contest_202606/2_Example/HDMI环出实验/eg4s324_hdmi_loop`。

- `i2cSlaveTop.v`、`i2c_edid.v`来自`hdmi_lvds_rx/rtl/iic/`，内容未改。
- `myedid_new.v`来自`hdmi_loop/al_ip/`，仅将INIT_FILE改为同目录`edid_1280720_with_audio.mif`，适配TD按源文件目录查找初始化文件的行为。
- MIF来自`hdmi_loop/al_ip/edid_mif/`，内容未改。

只复用用户已确认能被PC识别的HPD/DDC/ROM，不复用RGB解码/DVI重编码链路。调用方显式连接启动复位；原例程接收顶层未连接该复位。ROM首选720p60、名称AnlogicHDMI，音频短描述符为09/04/04，即双声道48kHz、24-bit LPCM。本候选保留官方SDA驱动行为（发送数据时主动驱动高/低），没有替换成此前自制开漏控制器。

保留原版权信息。仿真读取全部256字节并验证两个块校验，不能替代实际握手、电气眼图和音频上板验收。
