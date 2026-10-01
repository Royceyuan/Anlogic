# 副屏回归测试

需要 ModelSim，`vsim`、`vlog` 已加入 PATH。先在工程根目录打开 PowerShell，再执行：

```powershell
vsim -c -do sim/run_secondary_frame_store_alignment.do -l sim/regression_alignment.log

Push-Location sim
vsim -c -do run_secondary_main5e_codec.do -l regression_codec.log
vsim -c -do run_secondary_main5e_endpoint.do -l regression_endpoint.log
vsim -c -do run_secondary_main5e_fixed_udp.do -l regression_udp.log
vsim -c -do run_secondary_main5e_keys.do -l regression_keys.log
vsim -c -do run_secondary_main5e_status_adapter.do -l regression_status.log
vsim -c -do run_secondary_local.do -l regression_local.log
vsim -c -do run_secondary_transition.do -l regression_transition.log
vsim -c -do run_secondary_native720_media.do -l regression_native720.log
Pop-Location
```

`run_secondary_frame_store_alignment.do` 必须从工程根目录运行；其余八项从 `sim` 目录运行。

## 验收

每次命令退出后检查 `$LASTEXITCODE` 为 0，并核对对应日志的 PASS 数量；仅退出码为 0 不能证明测试通过。日志不得有 `** Fatal:`、`** Error:`、`FAIL` 或非零 `Errors:` 汇总。

| 日志 | 预期 PASS 数 | 检查内容 |
| --- | ---: | --- |
| regression_alignment.log | 2 | 旧连接能复现错误，当前一拍对齐连接零错误；4 帧、2560 字 |
| regression_codec.log | 1 | MBP1 CRC、编解码及错误包拒绝 |
| regression_endpoint.log | 1 | 副板协议端点 |
| regression_udp.log | 2 | 固定地址 UDP 两个方向 |
| regression_keys.log | 1 | 正常控制、SW3 静音浏览、SW4 本地轮播隔离 |
| regression_status.log | 1 | 主板状态与副屏页面适配 |
| regression_local.log | 3 | 轮播、后台缓存、简介和应急页面 |
| regression_transition.log | 2 | 转场控制和遮罩 |
| regression_native720.log | 2 | IMAGE0、IMAGEA 原生 1280×720 BMP 读取 |

2026-10-01 清理后以上 9 项、15 个用例已通过。对齐回归使用实际帧控制器和 FIFO，SDRAM 返回由测试替身产生；它不能替代真实板卡验证。官方 FIFO 的未连接可选端口可能产生既有警告。

`work*`、日志和 `transcript` 均为可重新生成的仿真缓存，不提交到 Git。

2026-10-01 手动浏览增量：端点测试新增 capability bit9、0x17/0x18 四字节、状态5、ACK/状态先后到达、转场超过1.5秒仍等待、8秒超时释放、全貌物理槽4、退出至少100ms的新心跳、BUSY、断线及新会话取消。按键测试新增拨码意图重同步、转场按键丢弃、旧主板兼容、恢复及应急后重同步；状态适配测试确认静音详情仍显示实际文物简介，不被预载目标污染。

离线协议工具自检（不绑定网卡、不占用 UDP 5000）：

```powershell
py -3 tools/mbp1_secondary_pc_probe.py --self-test
py -3 tools/mbp1_main_simulator.py --self-test
```
