# 画面参数流水线单热点资源对照

日期：2026-10-02。结论：候选最终减少14个Slice，但setup未闭合，已撤回生产RTL，不生成新bit。现有双板已验收功能和位流保留；本轮没有获得可交付的新增资源优化。

## 范围与基线

仅试改 `src/video/rgb888_picture_adjust.v` 的中间数据寄存器复位和位宽。亮度、对比度、饱和度、色温的公式、舍入、档位、最终裁剪和三拍像素时延不变。不改控制、协议、TF读取、音画字幕时间轴、时钟及约束；副板源码和bit不变。

主板当前源码基线为 `13494cd`，已验收bit仍为纵坐标候选 `release/dual_fpga_museum_terminal_main_board_y_origin_candidate.bit`，SHA256 `7EE6C57AE2DD2231AB5B76E7F7AC73C9032CADF72063F07378003877646005C9`。对照其最终Slice 9486、LUT 17081、寄存器11445，setup +0.187ns、hold +0.023ns。不得与较早正式bit `36D9BB7C...` 的资源报告混用。

回读UDP发送通路后保留TX数据快照：快照用于同一包的内容原子性，不能为节省寄存器直接删除。此次没有修改网络层。

## 等价前提与边界

- 仅取消两个中间数据级的复位，保留 `de_q`、`de_q2` 和最终 `rgb_out` 的异步复位。两个有效标志在复位后屏蔽尚未完全覆盖的数据，输出仍立即变黑，原三拍时延不变。
- 对全部8种编码（含默认档），contrast+brightness范围为 -112～366；`floor(R/4)+floor(G/2)+floor(B/4)` 范围为 -112～365。
- 色差R-Y/B-Y范围 -358～359、G-Y范围 -238～239，均在10位有符号范围 -512～511内。色差关于本通道单调递增、关于其他通道单调递减，所以端点直接给出极值；包括移位加法的部分和均不会溢出10位。
- 仅将RGB中间值、亮度和色差字段12→10位。饱和度放大、色温和最后裁剪仍为12位，不能继续按中间值界限截短最终结果。正负数符号扩展与旧版逐周期比较。

第一轮仅取消数据复位：综合LUT16801（不变）、寄存器11378（-3），该模块LUT+ripple为104+52、seq71、DSP5。第二轮再缩窄字段：全设计综合LUT16804（+3）、寄存器11373（-8）；该模块95+46、seq66、DSP5。综合变化不能代替实际Slice变化。

两轮候选源码副本及完整工具产物只留在忽略目录 `_build_picture_reset_candidate`、`_build_picture_width_candidate`，不增加生产工程入口。

## 验证与复现

新增 `sim/run_picture_adjust_reset_equivalence.do` 通过Git读取 `13494cd` 的原模块作为参考，逐周期比较RGB输出，并在有效拍比较所有缩窄字段。运行命令（工作目录为主板sim）：

```powershell
& D:\Modelsim\win64\vsim.exe -c -do run_picture_adjust_reset_equivalence.do
```

最终测试覆盖所有4096种参数编码组合、每通道256值的排列、每个参数组合的8种RGB立方体角点，共1081344组固定向量；另有200000随机周期、消隐、2261次复位（包括短于一个时钟的脉冲）和DE持续有效的复位释放。总计1281954周期PASS，0错误、0告警。它不是对所有RGB×参数笛卡尔积的穷举；位宽安全同时依据上述完整范围推导。

强制 `dut.de_q2=1` 的负向验证在第0个输入即捕获旧数据输出不一致，证明有效级复位不可删除；该故意注错的Fatal不算正常回归失败。

两种候选各完成原17个回归入口、24项PASS：remote_controls（3）、application_recovery、emergency_recovery、sd_read_abort、museum_subtitle_overlay、museum_manual、museum_lecture、museum_status_osd、status_osd官方模型、fat32_wav_streamer、audio_visualizer_overlay、rgb888_picture_adjust、mbp1_main_endpoint_control、hdmi_local_reset、video_timing（2）、viewport_pan_stream（4）、light_band（2）。副板实际协议端点 `run_mbp1_reconnect.do` 另有1项PASS。最终候选含新增对照，共19个正常入口、26项PASS；不是实板验收。

主板90个工程文件引用存在。原有官方BRAM模型告警保留，不新增豁免。用户原有 `src/storage/bmp_sdram_row_writer.v` 和 `sim/tb_fat32_bmp_adaptive_loader.v` 不修改、不提交，SHA256分别为 `F3955F055576D2A9372E0B5B433B09173C3C4754287CEC2B3E003A8B00401C82`、`9E91CC4676453AABE241AD3DE964F3878030E1CD6D78101C5048CF22C8D544D8`。

## 最终布局门槛

TD 6.2.168116、EG4S20BG256，复用原构建脚本、ADC/SDC：gate pack_effort high、place seed1/effort high、logic_level_opt on、route routability、fix_hold。不扫描种子、不降低时钟、不放宽约束。候选必须最终Slice低于9486并同时闭合setup/hold才保留。

| 指标 | 已验收纵坐标基线 | 数据复位＋位宽候选 |
| --- | ---: | ---: |
| 综合LUT | 16801 | 16804（+3） |
| 综合寄存器 | 11381 | 11373（-8） |
| 最终LUT | 17081 / 87.15% | 17065 / 87.07%（-16） |
| 最终寄存器 | 11445 | 11405（-40） |
| 最终Slice | 9486 / 96.80% | 9472 / 96.65%（-14） |
| BRAM9K / 64 | 43 | 43 |
| BRAM32K / 16 | 10 | 10 |
| DSP / 29 | 13 | 13 |
| PLL / 4 | 4 | 4 |
| setup WNS / TNS | +0.187 / 0 ns | -0.325 / -0.785 ns |
| setup失败端点 | 0 | 3 |
| hold WNS / TNS | +0.023 / 0 ns | +0.027 / 0 ns |
| hold失败端点 | 0 | 0 |
| STA覆盖 | 99.66% | 99.67% |

三个setup失败端点的工具起点实例均名为75MHz视频域 `main5_pan_hold_y_reg[1]_syn_3`，分别通向 `pending_media_index[0]`、`pending_source_height_bcd[15]` 的使能及 `transition_pace` 逻辑。核对路径逐项网络可见该起点Q实际驱动 `transition_mode[2]`，不是对平移Y坐标的比较，不能从综合后的实例名字误判逻辑功能。最坏路径7层逻辑、最大扇出41，数据延迟13.378ns中11.088ns（83%）为布线延迟。不能断言是画面算术公式错误；目前证据说明这次映射/布局变化暴露了既有转场→视口更新控制链的物理时序瓶颈。它没有达到稳定发布要求，不能为14个Slice收益忽略违例。

因此完整撤回本轮生产修改。原始综合、最终QoR、时序报告留于本目录 `picture_reset_trial_20261002_gate_area.rpt`、`picture_width_trial_20261002_gate_area.rpt`、`picture_width_trial_20261002_qor.rpt`、`picture_width_trial_20261002_timing.rpt`。现有PLL派生、SDRAM本地时钟、PHY位置及PLL反馈布线工具警告保留，不用新增例外掩盖失败；未执行bitgen。

撤回后再次运行新增逐周期对照，生产模块与参考版本完全相同，SHA256恢复为 `9F27E04B627AB07BF37FADA4CB2BB32E09489B89DB665AB0A3D3BE48F57AE46F`。正式主板bit `36D9BB7C...`、已验收纵坐标bit `7EE6C57A...`、副板说明页bit `B36B3D6E...` 均未改变。无需重新烧录，预期功能与本轮之前相同；当前资源仍是基线9486 Slice，不能使用未合入的9472作为当前资源。

后续应优先考察平移/转场共享控制条件及其寄存边界，而不是继续只缩短像素数据字段；仍需独立等价和按键/缓存/转场回归，不在本轮顺手修改控制逻辑。本轮自动提交仅含验证和结果记录，不提交用户已有改动，不push。
