# MAIN5E 副屏以太网联调说明

## 当前实现

工程分支为 `secondary-main5e`。以太网 MAC、RGMII/UDP 栈、MBP1 编解码及主板端点代码取自 GitHub `origin/Yan_Chen_Double` 的 `8133903`，副屏在此基础上实现本机 IP/MAC、16 字节状态接收、会话/序号/心跳管理、控制事务和媒体显示适配。协议依据 `MAIN5_副板实施与协议交接_20260928.md`；展示规则按负责人的后续决定执行：空闲时循环展示五张文物大图，拨码预载仅后台缓存对应简介，主板确认进入讲解后才显示简介与路线图。应急时显示 SD 卡中的逃生图。主板的拨码变化不是讲解确认。

副板固定 MAC `02:48:58:34:20:02`、IP `192.168.10.2`、UDP 端口 `5000`，主板为 MAC `02:48:58:34:20:01`、IP `192.168.10.1`、同端口。`HEARTBEAT(0x02)` 的讲解文物和预载目标分开处理；预载目标仅在字节 7 的扩展有效位为 1 时读取。接收并保存最近的 `HEARTBEAT`、`DISPLAY_STATUS(0x16)`、`DIAGNOSTIC_STATUS(0x31)`。应急优先于工程页；失联时保留已经进入的应急页，新鲜合法的非应急心跳解除。PHY 接通本身不表示应用层在线。

副屏 SW4 切换普通展陈与工程状态页。SW2:SW1 选按键组：`00` 四种预设，`01` 亮度/对比度，`10` 饱和度/色温，`11` 水平/垂直平移；SW3 选 1/2 档或 20/40 像素。KEY1～KEY4 从左到右依次对应交接文档表格。控制按绝对目标发送，等匹配 ACK 和实际状态后解锁下一次操作。预设和图像参数可在合法主板状态下使用；视口平移只在讲解状态及匹配文物/阶段/倍率的状态快照下使用。数码管在工程页显示 `E`、链路位、文物及阶段的简写；HDMI 工程页显示更多主板回报字段。

## 构建和联调顺序

1. 独立网口诊断工程：`hx4s20_secondary_main5e_netdiag.al`；bit 为 `release/hx4s20_secondary_main5e_netdiag_v01.bit`，SHA-256 `9FFA7F66BAA42E1063C54778770CA913946B996895AA7497C234AA92697F3F0F`。它用于先检查 RGMII、ARP、UDP 回环，不验证 SD/HDMI 媒体功能。给 PC 有线网卡设置 `192.168.10.1/24`，直连副板后运行 `python tools/udp_echo_test_secondary.py`；20/20 返回才算 PC 回环通过。当前仅生成了 bit，尚未上板运行这一测试。
2. 完整副屏工程：运行 `python scripts/prepare_secondary_main5e_project.py --full` 生成 `hx4s20_secondary_main5e.al`，再执行 `scripts/build_secondary_main5e_pr.tcl` 和 `scripts/build_secondary_main5e_bitgen.tcl`。bit 为 `release/hx4s20_secondary_main5e_v01.bit`，SHA-256 `1AFE76C32924A91C5633D410398A4763201E27560EBC3784F1D3335E19F3B443`。它使用原有 SD 卡素材；本次没有重新生成或改写 SD 卡图片。给 PC 有线网卡设置 `192.168.10.1/24`，网线只接 PC 与副板，在副板烧录此完整 bit 后运行 `python tools/mbp1_secondary_pc_probe.py --seconds 20`。脚本扮演主板并检查副板 HELLO、周期心跳、状态查询、ACK 和 CRC；末尾 `HELLO`、`HEARTBEAT`、`STATUS_QUERY`、`ACK` 均大于 0 且 `BAD=0` 才算基础协议通过。运行期间按副板 KEY，可查看发出的 `DISPLAY_PRESET` 或 `DISPLAY_ADJUST` 内容；若要检查 `VIEWPORT_SET`，改用 `--lecture-artifact 0` 并把副板 SW2:SW1 设为 `11`。脚本对控制请求故意回答 `BUSY`，因此不会产生实际的主板画面调节。若 Windows 提示防火墙，允许此 Python 程序使用当前有线网络的 UDP 5000。
3. PC 协议检查完成后，再将主副板以网线直连，先看 PHY 与工程页 LINK，再核对主板 `HELLO`、心跳及三个状态快照。主板拨码切换预载目标时，副屏继续五图轮播；主板按确认进入讲解后，副屏切简介。主板进入应急，副屏覆盖逃生图；解除应急后按当前 SW4 返回普通或工程页。

## 已验证与待上板验证

本地 ModelSim 通过 MBP1 编解码、固定 UDP、端点、心跳适配、按键、工程页及旧本地控制器测试。独立网口诊断工程完成布局布线，建立 WNS +670 ps、保持 WNS +63 ps，bit 已生成。完整工程建立 WNS +125 ps、保持 WNS +24 ps、STA 覆盖率 99.79%；LUT 12523/19600、寄存器 6997/19600、BRAM9K 32/64、DSP 9/29、PLL 4/4。两份 bit 均已由对应数据库生成。完整布局布线保留工具对 SDRAM 自动放置和局部时钟布线的既有关键警告，报告未见多驱动或异常时序路径。本说明不把仿真、时序通过视为实板通信成功。

实板仍须确认：直连以太网握手和 UDP 回环、五图轮播与预载独立、主板确认后切简介、应急覆盖与恢复、SW4 工程页、四键四组控制、失联及重连。旧的 `release/hx4s20_secondary_native720_v2.bit` 是已知可用基线，不应覆盖。当前用户尚未授权自动烧录实板。

## 边界

主板当前没有独立应急事件包或路线编号；副屏只能根据新鲜心跳的应急状态切换。断网期间发生又解除的短应急无法补报。工程页中的诊断字节 14～15 不代表实测 ACK 延迟。SDRAM 原有固定竖列瑕疵尚未解决，本次网口集成没有修改该诊断结论。
