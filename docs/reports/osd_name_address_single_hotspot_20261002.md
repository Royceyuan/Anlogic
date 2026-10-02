# OSD名称地址单热点：未合入

日期：2026-10-02。结论：两种候选均撤回生产RTL，不生成新bit、不要求上板测试。本轮完成双板回溯及验收记录收口，但没有获得可交付的新增资源优化。

## 1. 已验收基线及回溯

- 主板基线为 `aa6292d` 对应的纵坐标优化候选，bit SHA256 `7EE6C57AE2DD2231AB5B76E7F7AC73C9032CADF72063F07378003877646005C9`。此前主板短流程通过，后续用户确认副板SW3重连恢复正常。
- 副板基线为 `7efd48c` 双栏说明页，bit SHA256 `B36B3D6E5E0A4FD77A023F5DB5BF5706127253A54FC7ABC41C37B90484353CDA`。用户本轮确认“没问题了”。本轮副板只更新验收文档，不改RTL或bit。
- 仓库外回溯点：`D:\VSCode\CodeFiles\Git_TD\工程回溯\双板已验收_20261002_aa6292d_7efd48c`。主板363、副板173个已跟踪实文件逐项复制、SHA256核对通过；包含实际LFS文件和用户原有主板两处未提交修改。完整Git bundle均通过verify。恢复说明位于该目录README。
- 正式主板bit `36D9BB7C...` 与上述已验收候选均保留，不能混用两套资源报告。

## 2. 唯一热点与等价前提

仅试改 `src/video/museum_status_osd.v` 的名称RAM地址计算。不改FAT/SD读取、名称格式、字幕、缓存握手、媒体时间轴、按键、协议、时钟或约束。

名称窗口固定x=22～181、y=12～27，每行20字节、共16行。原计算重复执行 `(y_s0-12)` 和列偏移；已有s0寄存器已经保存相同行偏移。

第一版扩宽已有名称列寄存器7→8位，复用行/列，保留ASCII原来的低7位行为和名称末四字节。第二版不扩宽任何寄存器，只复用行偏移，保留完整列表达式：

```verilog
name_rd_addr<=({artifact,8'd0}+{artifact,6'd0})+
              {3'd0,ascii_y_s0,4'd0}+{5'd0,ascii_y_s0,2'd0}+
              ((x_s0-22)>>3);
```

名称窗口外仍不更新地址；不能把非法文物编码或越界光栅当作“不可能”而删除检查。两版均不增加像素延迟或改变字模。以上代码仅记录试验，当前生产文件已恢复原表达式。

## 3. 同配置实测结果

TD 6.2.168116、EG4S20BG256，原ADC/SDC；gate pack_effort high、place seed1/effort high、routability、一次fix_hold。不扫描种子，不降低时钟，不新增时序例外。

| 指标 | 当前已验收纵坐标基线 | 第一版：复用行列 | 第二版：只复用行 |
| --- | ---: | ---: | ---: |
| 综合LUT | 16801 | 16778（-23） | 16610（-191） |
| 综合寄存器 | 11381 | 11382 | 11381 |
| 最终LUT | 17081 / 87.15% | 17063 / 87.06% | 16884 / 86.14% |
| 最终寄存器 | 11445 | 11430 | 11436 |
| 最终Slice | 9486 / 96.80% | 9558 / 97.53%（+72） | 9550 / 97.45%（+64） |
| BRAM9K / 64 | 43 | 43 | 43 |
| BRAM32K / 16 | 10 | 10 | 10 |
| DSP / 29 | 13 | 13 | 13 |
| PLL / 4 | 4 | 4 | 4 |
| setup WNS | +0.187 ns | +0.059 ns | +0.160 ns |
| hold WNS | +0.023 ns | +0.024 ns | +0.022 ns |
| setup/hold TNS及失败端点 | 均0 | 均0 | 均0 |

综合OSD层次LUT+ripple由420+197变为403+188／399+192；全设计LUT变化不全部来自该模块本身，不能声称一条表达式必然节省191个LUT。最终决策看实际Slice和时序：第二版虽减少197个最终LUT，仍增加64个Slice，未满足当前紧缺的布局资源目标。因此两版均不发布。

原始综合与最终QoR证据保存在同目录 `osd_address_trial1_20261002_gate_area.rpt`、`_qor.rpt` 及trial2对应文件。保留既有PLL派生、SDRAM单负载本地时钟和PHY位置调整警告，无新增豁免。两个版本的setup/hold均闭合，但闭合本身不构成采用理由。

## 4. 验证

新增 `sim/run_osd_name_address_equivalence.do` 使用Git `aa6292d` 的原模块作为参考。两种候选各分别运行：SHOW_PERCENT=0/1 × SIM行为RAM/官方非SIM BRAM模型，共四项PASS，每项691874周期（每版2767496周期）。

比较每个周期的名称读地址及RGB、HS、VS、DE、X、Y；覆盖完整面板、全部8种文物编码、名称就绪及备用名称、末四字节、参数与模式、随机写RAM、复位和100000随机周期。官方BRAM32K同时加载官方glbl，保留每项两条逻辑RAM加密模型内部part-select告警。首次物理模型启动遗漏glbl的测试入口已修正后全部重跑，不把该失败算成PASS。

负向验证强制名称地址为0，在x=32、y=12捕获与旧版地址1的差异，证明检查能发现地址损坏；此故意注错的Fatal不是正常回归失败。

两种候选各完成原17个回归入口，共24项PASS：remote_controls（3）、application_recovery、emergency_recovery、sd_read_abort、museum_subtitle_overlay、museum_manual、museum_lecture、museum_status_osd、status_osd官方模型、fat32_wav_streamer、audio_visualizer_overlay、rgb888_picture_adjust、mbp1_main_endpoint_control、hdmi_local_reset、video_timing（2）、viewport_pan_stream（4）、light_band（2）。双板实际协议端点的副板 `run_mbp1_reconnect.do` 另有1项PASS。每版共19个正常入口／29项PASS、0错误。

## 5. 复现及当前使用

在主板sim目录运行 `D:\Modelsim\win64\vsim.exe -c -do run_osd_name_address_equivalence.do`，原生产RTL也应通过同一测试。候选源码副本只保存在忽略构建目录 `_build_osd_address_candidate/museum_status_osd_trial1.v` 与 `_build_osd_row_candidate/museum_status_osd_trial2.v`，不参与当前工程。

要重做试验，应在独立回溯目录应用本节记录的候选差异，再运行现有构建脚本，仅将产物目录重定向为 `_build_osd_row_candidate`；不要覆盖正式bit或放宽bitgen时序门槛。

当前继续使用已验收主板 `release/dual_fpga_museum_terminal_main_board_y_origin_candidate.bit` 和副板 `release/hx4s20_secondary_help_v2.bit`，预期界面、预载、转场、字幕、按键及通信与本轮之前完全相同。资源仍是主板基线9486 Slice（96.80%），不得把未合入候选16884 LUT当成当前用量。

撤回后再次运行四组名称地址等价检查全部PASS。生产 `museum_status_osd.v` 的原始SHA256恢复为 `EDF030B3C1117ADB90A9133DD1D7AC0BF9152FC133948E2645891664420E176A`，与回溯实文件逐字节一致；用户两处已有修改及两板所有发布bit的哈希均保持不变。主板90个工程引用文件均存在。

本轮不修改、不提交用户原有 `sim/tb_fat32_bmp_adaptive_loader.v` 和 `src/storage/bmp_sdram_row_writer.v`；不写TF卡，不push。后续热点应优先考察打包占用和寄存器/逻辑共置，不能继续只按综合LUT下降筛选。
