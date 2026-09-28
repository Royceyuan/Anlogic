# MAIN5E 副屏以太网联调说明

## 当前实现

工程分支为 `secondary-main5e`。以太网 MAC、RGMII/UDP 栈、MBP1 编解码及主板端点代码取自 GitHub `origin/Yan_Chen_Double` 的 `8133903`，副屏在此基础上实现本机 IP/MAC、16 字节状态接收、会话/序号/心跳管理、控制事务和媒体显示适配。协议依据 `MAIN5_副板实施与协议交接_20260928.md`；展示规则按负责人的后续决定执行：空闲时循环展示五张文物大图，拨码预载仅后台缓存对应简介，主板确认进入讲解后才显示简介与路线图。应急时显示 SD 卡中的逃生图。主板的拨码变化不是讲解确认。

副板固定 MAC `02:48:58:34:20:02`、IP `192.168.10.2`、UDP 端口 `5000`，主板为 MAC `02:48:58:34:20:01`、IP `192.168.10.1`、同端口。`HEARTBEAT(0x02)` 的讲解文物和预载目标分开处理；预载目标仅在字节 7 的扩展有效位为 1 时读取。接收并保存最近的 `HEARTBEAT`、`DISPLAY_STATUS(0x16)`、`DIAGNOSTIC_STATUS(0x31)`。应急优先于工程页；失联时保留已经进入的应急页，新鲜合法的非应急心跳解除。PHY 接通本身不表示应用层在线。

副屏 SW4 切换普通展陈与工程状态页。SW2:SW1 选按键组：`00` 四种预设，`01` 亮度/对比度，`10` 饱和度/色温，`11` 水平/垂直平移；SW3 选 1/2 档或 20/40 像素。KEY1～KEY4 从左到右依次对应交接文档表格。控制按绝对目标发送，等匹配 ACK 和实际状态后解锁下一次操作。预设和图像参数可在合法主板状态下使用；视口平移只在讲解状态及匹配文物/阶段/倍率的状态快照下使用。数码管在工程页显示 `E`、链路位、文物及阶段的简写；HDMI 工程页显示更多主板回报字段。

## 构建和联调顺序

1. 独立网口诊断工程：`hx4s20_secondary_main5e_netdiag.al`；bit 为 `release/hx4s20_secondary_main5e_netdiag_v01.bit`，SHA-256 `9FFA7F66BAA42E1063C54778770CA913946B996895AA7497C234AA92697F3F0F`。它用于先检查 RGMII、ARP、UDP 回环，不验证 SD/HDMI 媒体功能。给 PC 有线网卡设置 `192.168.10.1/24`，直连副板后运行 `python tools/udp_echo_test_secondary.py`；20/20 返回才算 PC 回环通过。当前仅生成了 bit，尚未上板运行这一测试。
2. 完整副屏工程：运行 `python scripts/prepare_secondary_main5e_project.py --full` 生成 `hx4s20_secondary_main5e.al`，再执行 `scripts/build_secondary_main5e_pr.tcl` 和 `scripts/build_secondary_main5e_bitgen.tcl`。bit 为 `release/hx4s20_secondary_main5e_v01.bit`，SHA-256 `1AFE76C32924A91C5633D410398A4763201E27560EBC3784F1D3335E19F3B443`。它使用原有 SD 卡素材；本次没有重新生成或改写 SD 卡图片。给 PC 有线网卡设置 `192.168.10.1/24`，网线只接 PC 与副板，在副板烧录此完整 bit 后运行 `python tools/mbp1_secondary_pc_probe.py --seconds 20`。脚本扮演主板并检查副板 HELLO、周期心跳、状态查询、ACK 和 CRC；末尾 `HELLO`、`HEARTBEAT`、`STATUS_QUERY`、`ACK` 均大于 0 且 `BAD=0` 才算基础协议通过。运行期间按副板 KEY，可查看发出的 `DISPLAY_PRESET` 或 `DISPLAY_ADJUST` 内容；若要检查 `VIEWPORT_SET`，改用 `--lecture-artifact 0` 并把副板 SW2:SW1 设为 `11`。脚本对控制请求故意回答 `BUSY`，因此不会产生实际的主板画面调节。若 Windows 提示防火墙，允许此 Python 程序使用当前有线网络的 UDP 5000。
   交互式联调可运行 `python tools/mbp1_main_simulator.py`，在终端输入 `highlight 1`、`preload 2`、`lecture 2`、`emergency on`、`emergency off`、`overview`、`status`、`quit`。文物编号为 0～4；高亮和预载目标可独立设置，预载完成由脚本即时模拟。脚本每 500 ms 发送主板心跳和显示状态，打印副板的 HELLO、状态查询、ACK 及三类按键控制；收到有效控制后回 ACK 和更新后的 DISPLAY_STATUS。它模拟主板的协议状态，不读取主板 TF 卡，也不代替主板实际画面验证。同一时刻只能运行一个占用 PC UDP 5000 的探针或模拟器。
3. PC 协议检查完成后，再将主副板以网线直连，先看 PHY 与工程页 LINK，再核对主板 `HELLO`、心跳及三个状态快照。主板拨码切换预载目标时，副屏继续五图轮播；主板按确认进入讲解后，副屏切简介。主板进入应急，副屏覆盖逃生图；解除应急后按当前 SW4 返回普通或工程页。

## 已验证与待上板验证

本地 ModelSim 通过 MBP1 编解码、固定 UDP、端点、心跳适配、按键、工程页及旧本地控制器测试。独立网口诊断工程完成布局布线，建立 WNS +670 ps、保持 WNS +63 ps，bit 已生成。完整工程建立 WNS +125 ps、保持 WNS +24 ps、STA 覆盖率 99.79%；LUT 12523/19600、寄存器 6997/19600、BRAM9K 32/64、DSP 9/29、PLL 4/4。两份 bit 均已由对应数据库生成。完整布局布线保留工具对 SDRAM 自动放置和局部时钟布线的既有关键警告，报告未见多驱动或异常时序路径。本说明不把仿真、时序通过视为实板通信成功。

2026-09-28 PC 直连完整 bit 的协议探针实测：20 秒收到副板 HELLO 1、HEARTBEAT 40、STATUS_QUERY 1、ACK 1、BAD 0。主板模拟器发送 `lecture 2` 后收到副板对 PLAYBACK_STATE 的 `result=0` ACK。随后约 156 秒联调中收到 HELLO 1、HEARTBEAT 313、STATUS_QUERY 1、ACK 1、CONTROL 1、BAD 0；操作者设置 S-SW2:S-SW1=`00` 并按 KEY1，模拟器收到 `DISPLAY_PRESET seq=3231 preset=0`，回复 OK ACK 和 DISPLAY_STATUS。说明此板当前可完成基本双向 UDP/MBP1 收发及一项实板按键控制；副屏实际跳页和其余三组按键尚未由本次日志验证。PC 的 UDP 5000 曾被 NI Time Synchronization (`lkTimeSync`) 占用；测试时临时停止该服务，测试结束应恢复。

### 2026-09-28 轮播心跳修复 v02

完整 v01 bit 与 PC 模拟主板握手后，SW4 返回展陈页时始终停在越王勾践剑。根因由 ModelSim 复现：主板每 500 ms 发一次总览心跳，`secondary_carousel_controller` 每次都把 5 秒轮播计时清零。v02 只在从简介返回总览时重置一次。新增的周期心跳回归在修复前报 `periodic overview heartbeat stopped the carousel`，修复后通过；原有轮播、简介、应急与页面测试通过。

在工程根目录执行 `D:\Anlogic\TD5.6.2\bin\td_commands_prompt.exe ./scripts/build_secondary_main5e_pr.tcl`，再执行同一工具的 `./scripts/build_secondary_main5e_carousel_fix_v02_bitgen.tcl`。构建脚本使用相对路径，运行时当前目录须为工程根目录。新 bit 为 `release/hx4s20_secondary_main5e_carousel_fix_v02.bit`，2026-09-28 12:58 生成，提交 `db42c7c`，SHA-256 `676BE738DE57DF6288495D81BBFA0CC86083FA141FCA90FC2F2DD8F3633881E7`；最终 setup WNS +112 ps/TNS 0、hold WNS +27 ps/TNS 0，STA 覆盖率 99.79%，LUT 12408/19600、寄存器 7008/19600、BRAM9K 32/64、DSP 9/29、PLL 4/4。旧 `release/hx4s20_secondary_main5e_v01.bit` 的 SHA-256 仍为 `1AFE76C32924A91C5633D410398A4763201E27560EBC3784F1D3335E19F3B443`。

**v02 实板分项通过：**操作者 SRAM 烧录后，PC 模拟主板连续 25 秒发心跳，收到副板 HELLO 1、HEARTBEAT 50、STATUS_QUERY 1、ACK 1、BAD 0；副屏在心跳期间继续切图。发送 `preload 2` 后仍轮播；发送 `lecture 2` 后收到 PLAYBACK_STATE 成功 ACK，副屏显示金缕玉衣简介与路线图；`emergency on` 显示逃生图，`emergency off` 恢复轮播；讲解后 `overview` 返回轮播且继续切图。操作者在 S-SW2:S-SW1=`00` 按 KEY2，模拟器收到 `DISPLAY_PRESET seq=607 preset=1 -> OK`，回报参数 `[5,3,4,4]`；该轮监听统计 HELLO 1、HEARTBEAT 236、STATUS_QUERY 1、ACK 3、CONTROL 1、BAD 0。上述为 PC 模拟主板联调，不等同双板直连验证。此次 PC 直连还观察到一次 PHY 为 1 Gbps 但无 ARP/MBP1 报文，拔插网线后恢复握手；原因未确认。

实板仍须确认：主副板直连联动、其余按键模式、断线重连与长时间稳定性；独立网口诊断工程的 UDP 回环尚未单独上板。旧的 `release/hx4s20_secondary_native720_v2.bit` 是已知可用基线，不应覆盖。当前用户尚未授权自动烧录实板。

## 边界

主板当前没有独立应急事件包或路线编号；副屏只能根据新鲜心跳的应急状态切换。断网期间发生又解除的短应急无法补报。工程页中的诊断字节 14～15 不代表实测 ACK 延迟。SDRAM 原有固定竖列瑕疵尚未解决，本次网口集成没有修改该诊断结论。
