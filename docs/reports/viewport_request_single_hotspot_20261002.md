# 视口刷新请求单热点对照

日期：2026-10-02。结论：合并请求候选增加169个Slice且setup未闭合，已完整撤回生产RTL，不生成新bit。当前双板功能、资源与已验收位流不变。

## 1. 范围与依据

仅试改主板 `src/memory/museum_media_core.v` 中缩放、平移两支直接刷新请求；副板不变。基线为 `6c46807` 的生产RTL，主板当前已验收bit仍是纵坐标候选 `7EE6C57A...`（9486 Slice、17081 LUT、11445寄存器、setup +0.187ns / hold +0.023ns）。

上一画面数据流水线候选虽然减少14个Slice，但setup未闭合，已撤回；其最坏路径Q实际网络是 `transition_mode[2]`，经过 `transition_active`、视口刷新优先链到pending缓存元数据使能。不能根据工具起点实例 `main5_pan_hold_y_reg[1]_syn_3` 的名字误认为坐标计算路径。详细证据见 `picture_pipeline_single_hotspot_20261002.md`。

原缩放和平移两支写相同的媒体编号、帧编号、源尺寸及直接刷新状态，仅倍率和偏移数据不同。候选合并为一个公共请求分支：

```verilog
ENABLE_MULTI_FRAME_PRELOAD && video_run && !overview_enable_video &&
!transition_active &&
((detail_zoom_2x_ff2 != display_zoom_2x) ||
 (ENABLE_MAIN5_REMOTE && !switch_pending && main5_pan_changed))
```

有倍率变化时仍优先缩放并居中；只有平移时，倍率保持不变、锁存新的XY。缩放仍可取代待提交的平移请求；平移仍要求没有pending请求。没有新增寄存器或时钟周期，不改变先前媒体切换分支的优先级、后续取消逻辑、帧边界提交和KEY4/应急恢复覆盖。

不改缓存布局、TF读取、字幕、音画时间轴、图片顺序、转场类型/时长、画面参数、协议、像素时延或约束。原有用户两处未提交修改保留，不混入提交。

## 2. 验证

新增 `sim/run_viewport_request_equivalence.do` 从Git读取基线，再从基线/候选实际源文件各抽取这两支请求逻辑，自动生成对照模块；不是手工抄一份期望算法。

```powershell
# 在主板sim目录运行
& D:\Modelsim\win64\vsim.exe -c -do run_viewport_request_equivalence.do
```

- 512种二值控制组合，包含旧入口特性开关关闭、总览、转场、视频未运行、倍率相同/不同、pending和pan_changed。
- 每种组合测试512对偏移，XY分别覆盖9位有符号范围 -256～255；不是XY笛卡尔积穷举。
- 缓存元数据随机值、50000随机连续周期、无动作保持和短复位；逐周期比较全部75位请求结果。最终312152周期PASS，0错误、0告警。
- 正常RTL使用已复位的二值状态。该对照没有证明任意X/Z输入的四态语义；不将未初始化仿真状态当作合法远程请求。
- 负向验证先运行50ns完成复位，再强制候选pending_pan_x=0，在控制码111000001的合法平移请求处捕获差异，证明检查能检测平移丢失。

原17个回归入口24项PASS：remote_controls（3）、application_recovery、emergency_recovery、sd_read_abort、museum_subtitle_overlay、museum_manual、museum_lecture、museum_status_osd、status_osd官方模型、fat32_wav_streamer、audio_visualizer_overlay、rgb888_picture_adjust、mbp1_main_endpoint_control、hdmi_local_reset、video_timing（2）、viewport_pan_stream（4）、light_band（2）。副板实际端点 `run_mbp1_reconnect.do` 另有1项PASS；连同新增对照，共19个正常入口26项PASS。

首轮生成测试包装器时的子串替换误伤direct_switch_pending和优化掉test_pass的问题已修正，最终完整重跑0错误后才计PASS；故意注错不计为正常回归失败。官方BRAM模型原有告警保留。

## 3. 资源与发布门槛

TD 6.2.168116、EG4S20BG256；复用原ADC/SDC和构建参数，固定seed1，不扫描种子、不降低时钟、不新增时序例外。综合LUT16819（较基线+18），寄存器11381（不变），DSP/BRAM/PLL不变。不能以减少代码行数当作硬件资源收益。

最终Slice必须小于9486，setup/hold均闭合，才保留该候选。实际结果：

| 指标 | 已验收纵坐标基线 | 合并请求候选 |
| --- | ---: | ---: |
| 综合LUT | 16801 | 16819（+18） |
| 综合寄存器 | 11381 | 11381 |
| 最终LUT | 17081 / 87.15% | 17124 / 87.37%（+43） |
| 最终寄存器 | 11445 | 11442（-3） |
| 最终Slice | 9486 / 96.80% | 9655 / 98.52%（+169） |
| BRAM9K / 64 | 43 | 43 |
| BRAM32K / 16 | 10 | 10 |
| DSP / 29 | 13 | 13 |
| PLL / 4 | 4 | 4 |
| setup WNS / TNS | +0.187 / 0 ns | -1.540 / -7.783 ns |
| setup失败端点 | 0 | 14 |
| hold WNS / TNS | +0.023 / 0 ns | +0.024 / 0 ns |
| hold失败端点 | 0 | 0 |
| STA覆盖 | 99.66% | 99.66% |

最坏setup路径为视频Y计数→行缓冲slot_valid，不能把物理布局的变化归结为新请求语义错误；也不能因为仿真等价便忽略实际时序失败。相同参数下它同时违背资源及setup门槛，所以撤回。不为了该候选扫描种子或再修改其他模块。

综合与QoR原始证据存于同目录 `viewport_request_trial_20261002_gate_area.rpt`、`viewport_request_trial_20261002_qor.rpt`；完整布局、STA和候选源码 `museum_media_core_request_trial.v` 只留在忽略目录 `_build_viewport_request_candidate`，不增加产品入口。不执行bitgen，原ADC/SDC及PLL/SDRAM本地时钟警告保留，无新增时序豁免。

撤回后重新运行新增对照，312152周期PASS、0错误。`museum_media_core.v` 恢复为原SHA256 `E7BE3A2F83F2D958412C87B0D5573663838516EA609218CA7A3BDFFA7A76295B`，画面参数模块亦为原版 `9F27E04B...`；两处用户原有改动、主副板发布bit的哈希未变。无需重新烧录，预期功能与此前相同；当前资源仍是9486 Slice / 17081 LUT，不得用未合入的9655或上一试验9472作为当前用量。

此次保留的是可运行的请求对照测试与失败证据，不声称已完成新增资源优化。后续应依据真实大热点取得足够资源余量，不继续用少量表达式改写碰运气；任何RAM化或寄存边界变化应作为独立试验重新验证，不能破坏素材/字幕/恢复握手。自动commit仅含测试与报告，不push，不提交用户已有修改。
