# 单板静音手动浏览验收 bit：构建与验证

## 发布与隔离

- 功能基线：`c5efd7a`主板MBP1静音手动浏览；本轮仅增加默认关闭的临时本地验收输入。
- 验收bit：`release/dual_fpga_museum_terminal_main_board_manual_test.bit`，634313字节。
- SHA-256：`F498100E7E5A80288D4566781DFEA7839D3484E47E006DFBB4C0A671B2D74FA1`，已与旁置`.sha256`核对。
- 正式bit未覆盖，SHA仍为`14D503535CA033A01CE2F5AC5805E97FD7E3A994D0A3E8866D67419D75076A14`。正式产品工程`.al`、顶层、管脚/时序约束均未改动。
- 源码仅在显示wrapper定义`MUSEUM_LOCAL_MANUAL_TEST`时启用`ENABLE_LOCAL_MANUAL_TEST=1`。TD展开日志确认验收参数为1，默认正式构建为0。
- 新增SW3:SW2:SW1的101/110稳定代码触发与KEY3手动切图，复用现有命令寄存器和讲解FSM；恢复/应急/转场/缓存保护未旁路。
- TF素材、音频、字幕时间轴、名称文件、副板、协议包格式未修改。两项原有用户未提交改动未纳入本轮提交。

## 验证结果

| 验证 | 结果与范围 |
|---|---|
| `sim/run_local_manual_test.do` | PASS：稳定101进入、110退出、KEY3图号递增/回绕、缓存不完整与转场期间忽略、短暂拨码跳变过滤、恢复后不重发保持的代码、BUSY后须新拨码操作且新操作可恢复 |
| `sim/run_remote_controls.do` | PASS：默认关闭本地入口，101仍无本地模式功能；原静音命令校验、画面参数、视口、KEY4恢复与优先级通过 |
| `sim/run_local_controls.do` | PASS：正式KEY3总览OSD/讲解波形分工保持 |
| `sim/run_museum_manual.do` | PASS：实际讲解FSM静音进入、四图控制、音频进度冻结、缓存固定、退出、暂停状态切入及恢复 |
| `py -3 tools/test_mbp1_pc_control.py` | PASS：loopback会话、ACK/状态、BUSY/重试、手动图号与退出、绑定失败退出等；不是电脑与板卡物理网口联调 |

ModelSim10.6e；最终日志无Error/Fatal，保留原stub未接端口警告。集成仿真以存储stub为边界；单板实测仍由负责人按操作文档验收，不宣称实板或双板新功能已经通过。

## 资源（最终布线报告）

| 资源 | 正式静音浏览基线c5efd7a | 单板验收版 | 差值 |
|---|---:|---:|---:|
| LUT/19600 | 16829（85.86%） | 16895（86.20%） | +66 |
| 寄存器/19600 | 11380（58.06%） | 11413（58.23%） | +33 |
| Slice/9800 | 9522（97.16%） | 9483（96.77%） | -39 |
| BRAM9K/64 | 43 | 43（67.19%） | 0 |
| BRAM32K/16 | 10 | 10（62.50%） | 0 |
| DSP/29 | 13 | 13（44.83%） | 0 |
| PLL/4 | 4 | 4（100%） | 0 |
| GCLK/16 | 3 | 3（18.75%） | 0 |

Slice差值包含种子/打包差异，不能解读为正式版源码资源优化成果。

## 时序与构建经过

- TD6.2.168116，EG4S20BG256，相同ADC/SDC、place high/opt_timing high/logic_level_opt on、route routability，修复hold后检查slow/fast。
- 最终seed2：setup WNS **+0.239ns**，STNS0；hold WNS **+0.024ns**，HTNS0；STA覆盖99.65%，Confidence=Routed。
- 首次seed1：setup -1.768ns，STNS -7.167ns；hold +0.022ns。bitgen检查明确拒绝生成；未交付违例bit。首轮中断后从已保存place数据库恢复布线。
- 首次违例路径为原视频域字幕坐标到应急叠加输出，未修改该像素逻辑。TD布线后`phys_opt`尝试及初始化时序后重试均异常退出，失败报告/转储保留在独立构建目录，不作为发布依据。
- 使用同一综合gate数据库改seed2重做place/route，无需改变媒体逻辑或约束；正式验收构建脚本已固定seed2。
- seed2最终report/DB复制到独立构建标准`final.*`/`pr.db`后，单独进程`import_db -check_drc`、`drc_check -all -verbose`、`report_route_status -drc`复查，并通过STA门槛执行bitgen。
- 无多驱动、无异常时序路径，bitgen明确报告生成完成。保留原SDRAM_CLK单负载本地路由警告，未隐瞒或豁免该警告。

原始证据在Git忽略的`_build_local_manual_test/seed2_final.area`、`seed2_final.timing`、`seed2_final.ts`、`seed2_pr.db`，发布所用标准路径`final.*`/`pr.db`与其一致。根目录`_local_manual_seed2.log`、`_local_manual_bitgen_final.log`及`_local_manual_*`仿真日志可本地核查；完整重建入口见`scripts/build_museum_local_manual_test*.tcl`。

setup/hold正余量仅是工具结果，不能替代真实TF读取、HDMI音频、重复模式切换、恢复与应急的上板测试。单板通过也不替代后续副板SW3/四键映射和MBP1命令、ACK、状态联动验收。
