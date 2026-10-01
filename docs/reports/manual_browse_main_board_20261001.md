# 主板静音手动浏览构建与验证

## 版本与边界

- 基线：`79037ed`恢复的`a0a6832`，负责人此前验证功能和双板联调正常。
- 本轮仅主板：复用既有讲解FSM、四图缓存、转场及MBP1事务；没有修改副板、TF图片/WAV/SUB/名称或音画时间轴。
- 发布：`release/dual_fpga_museum_terminal_main_board.bit`，634313字节。
- SHA-256：`14D503535CA033A01CE2F5AC5805E97FD7E3A994D0A3E8866D67419D75076A14`。
- 已验证基线另存`_build_museum_main_board/museum_a0a6832_board_pass.bit`，哈希`4C695F6CE48BD9826AD18A7A1A8E21EE4324630A89A2F4C05FFE7687F5B9DBF4`；历史last_verified发布文件未覆盖。
- 当前电脑物理网卡故障；本轮没有PC连板测试，也没有新手动模式双板验收。烧录默认正常模式，旧副板无需新命令仍可使用旧控制；手动功能需副板后续适配。

## 行为

`0x17`设置正常/静音手动，`0x18`选择全貌/细节1～3。HELLO build_id=`0x00050004`、capability=`0x000003ff`；新功能bit9。手动不播放音频、不显示字幕/波形、不自动切图，退出走全貌→收拢→总览，再确认才从头讲解。后台预载可能覆盖细节时拒绝切入；手动期间保护四图，退出恢复预载。

新增模式确认与KEY2同周期的启动门控，避免退出手动时绕过音频准备；模式接受前阻止新后台预载抢先启动，不中断已接受读写。详细协议、后续副板SW3与四键分配、验收步骤见`../主板静音手动浏览与副板接口_20261001.md`。

## 离线检查

工具：ModelSim SE-64 10.6e；Python3标准库loopback，不依赖有线网卡。

| 检查 | 结果 |
|---|---|
| 讲解控制器正常模式 | PASS：原时间轴、暂停、最终全貌、后台预载/复入 |
| 讲解控制器手动模式 | PASS：无需WAV入口、四图逆向选择、进度冻结、缓存保护、退出回总览、暂停切入、恢复默认正常、模式/确认同周期 |
| MBP1端点ENABLE_CONTROL=1/0 | PASS：新命令分发/不支持、长度校验、重复手动图号不重放、原会话/心跳/状态 |
| 主板远程集成（存储等为仿真stub） | PASS：BUSY/非法模式/非法图号/错误文物、静音状态回报、原预设/自定义/1×2×视口/优先级与KEY4恢复 |
| 本地控制 | PASS：KEY3总览OSD/讲解波形分工 |
| 缩放回归 | PASS：原MAIN3 KEY1缩放与退出归零 |
| 字幕overlay | PASS：原TF字幕及restart流程 |
| 应用恢复/应急 | PASS：KEY4 drain/reset/reinit、超时重试与重复键隔离；SW4抢占及帧边界解除 |
| `tools/test_mbp1_pc_control.py` | PASS：loopback会话、ACK/实际状态、BUSY后恢复、手动图号、退出帧边界等待、重连、超时、故障网卡绑定失败处理 |

日志在工程根目录`_manual_*.log`（Git忽略）；新增可重复入口`sim/run_museum_manual.do`。仿真未发现Fatal或Error；既有stub未外接端口警告仍保留。模块/存储stub仿真不代表真实SD物理链路、HDMI整机或双板新功能已通过。

## 资源与时序

TD6.2.168116，EG4S20BG256；原ADC/SDC、place seed1，high effort，route routability，修复hold后最终STA。构建脚本使用根目录相对路径，修正TD stdin对嵌套路径表达式解析为空的问题；从根目录按HANDOFF原命令运行即可。

| 资源 | 已验证基线 | 本轮最终 | 增量 |
|---|---:|---:|---:|
| LUT/19600 | 16737（85.39%） | 16829（85.86%） | +92 |
| 寄存器/19600 | 11371（58.02%） | 11380（58.06%） | +9 |
| Slice/9800 | 9437（96.30%） | 9522（97.16%） | +85 |
| BRAM9K/64 | 43 | 43（67.19%） | 0 |
| BRAM32K/16 | 10 | 10（62.50%） | 0 |
| DSP/29 | 13 | 13（44.83%） | 0 |
| PLL/4 | 4 | 4（100%） | 0 |
| GCLK/16 | 3 | 3（18.75%） | 0 |

- setup WNS +0.008ns，TNS0，违例端点0。
- hold WNS +0.021ns，TNS0，违例端点0。
- STA覆盖99.68%，slow/fast均检查。setup余量小；不能仅依据正slack承诺实板已稳定。
- DRC复查：无多驱动、无异常时序路径，路由完成；保留基线SDRAM相移时钟单负载本地路由警告。没有为闭合时序放宽约束或更换资源实现。
- bitgen确认生成完成；发布SHA与`.bit.sha256`一致。

原始报告：`museum_main_board_area.rpt`、`museum_main_board_timing.rpt`、`museum_main_board_drc_bitgen.rpt`；QoR与timing_status原文件在`_build_museum_main_board`。本轮只完成主板工程交付，不替副板负责人宣称新功能BOARD PASS。
