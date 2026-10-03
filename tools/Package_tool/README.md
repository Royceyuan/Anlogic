# 博物馆 TF 素材打包工具

这是主板媒体格式的 Windows 图形化检查与打包工具。它不会修改源素材或 FPGA 工程。

当前工程目录按“源码＋独立运行目录”整理：双击 `MuseumTFPackager/MuseumTFPackager.exe`。外层重复 EXE 和运行组件已移入 rubbish；源码、测试、构建脚本、文档与 ZIP 保留。独立离线包全部解压后，仍在解压目录直接双击 EXE。源码检查会查找这个运行目录。

## 使用方法

1. 双击 `MuseumTFPackager.exe`（不弹终端，无需安装 Python/Pillow）。
2. 选择包含 `01_文物名`～`05_文物名` 的素材根目录。
3. SRT 未同步时勾选“本地校准字幕”，先点“检查素材”。
4. 点击“设置切图句”，为细节1、细节2、细节3、最终全貌各选择一句字幕，再生成。
5. 启用校准时先试听输出的 `aligned_subtitles`，核对每句和四个切点。
6. 将生成目录中 `TF_CARD` 文件夹内的 **31 个文件**复制到 FAT32 TF 卡根目录。

生成目录同时包含 `package_report.txt` 和 `package_manifest.json`，记录图片尺寸、音频时长、字幕条数及每个板端文件的 SHA-256。这两个报告文件不要复制到 TF 卡。

主界面右侧“使用说明”包含完整流程；处理在后台执行，界面不因校准冻结。生成期间禁止重复提交或关闭。

## 每个文物目录必须包含

- 全貌图、细节1～3（PNG/JPG/JPEG/BMP，可带描述后缀）
- 一个有效 WAV（文件名不限）
- 一个 SRT（文件名不限）

仅需六个文件，不必写脚本。支持常见 WAV 采样率、位深和声道；PCM、浮点、ADPCM 等由 FFmpeg 转换。SRT 支持 UTF-8、UTF-16/32 BOM、GBK/GB18030、常见换行、逗号/点号毫秒、多行文字及简单样式标签。板端每件文物最多 32 条字幕，超限明确报错；名称/字幕过宽也不静默截断。

## 逐句校准与音画同步

勾选“本地校准字幕”后，使用音频重新定位每句起止时间，保留 SRT 文字、句数和顺序；校准不依赖原时间戳准确。针对中文讲解，使用 Whisper multilingual small 与 stable-ts 2.19.1，CPU 运行，无需 CUDA，校准进程禁止联网，不上传音频。

“设置切图句”指定四个字幕句：初始全貌从音频起点开始，四句分别开始细节1、细节2、细节3、最终全貌。**切点跟随校准后的句子开始时间**，不会使用过时的原时间；必须递增且在音频内部。设置仅保留在本次软件会话，换素材目录会清空，替换 SRT 后需重新设置。

未设置切图句的文物仍兼容旧 `图片切换脚本.md`；没有脚本时按音频时长五等分。五等分不识别图片语义，要精确对应讲解需选择四个字幕句。

原 SRT 不覆盖；校准结果在 `aligned_subtitles/SUB0.srt`～`SUB4.srt`，`alignment_report.json` 记录时间和试听提示。漏句、多句、噪声或错误文字可能失败或残余不同步，模型不能保证绝对准确。失败会停止生成、清理本次未完成目录，不偷偷回退到比例压缩；生成后必须试听。

图片保持原宽高比和分辨率，只有超过主板上限 1920×1080 时才等比例缩小。音频统一转换为主板要求的 PCM16、48 kHz、双声道标准 WAV；字幕默认保留 SRT 原始时间戳（`direct`）。

若检查提示字幕结束时间超过音频，先核对是否选错音频。只有确认需要按音频总时长等比例压缩字幕时，才选择 `fit`；该模式会改变所有字幕时间点，生成后必须试听验收。

## 环境

EXE 已包含 Python、Tkinter、Pillow 和名称/字幕生成模块。仅支持 Windows x64；使用系统微软雅黑，不分发 Windows 字体。首次启动需要解包，可能稍等几秒。

基础 EXE：规范 WAV 可直接打包；非规范 WAV 需 FFmpeg 和同目录 ffprobe，转换不弹终端。

完整离线包 `MuseumTFPackager_Offline.zip`：全部解压，保留 EXE 旁的 `AlignmentWorker`、`models`、`ffmpeg`、`offline_licenses`，双击 EXE 即可运行，无需安装 Python/CUDA 或联网。不只复制 EXE；这些运行文件和报告不复制到 TF 卡。

模型 `small.pt` 为 483,617,219 字节，校准组件另占电脑磁盘，不占 FPGA 资源。离线包逐文件校验值在 `offline_bundle_manifest.json`；分发需保留第三方许可及对应源码/构建材料，见 `THIRD_PARTY_NOTICES.md`。

以下仅为源码运行环境：

- Python 3（含 Tkinter）
- Pillow
- FFmpeg：仅当源音频不是主板标准 WAV 时需要。程序会自动查找 PATH、Conda 和当前开发机的 Anaconda 安装；也可用 `FFMPEG` 环境变量指定完整路径。

命令行检查：

```powershell
py -3 .\museum_media_packager.py --check "D:\VSCode\CodeFiles\Git_TD\素材"
```

命令行生成：

```powershell
py -3 .\museum_media_packager.py --build "D:\VSCode\CodeFiles\Git_TD\素材" --output "D:\打包输出"
```

## 重新生成 EXE

在此目录执行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\build_exe.ps1`。
脚本使用仓库根目录下独立的 `_build_media_packager_venv`，不修改系统 Python；构建缓存位于 `_build_media_packager`，均不参与工程构建或提交。

增加 `-WithAlignment` 构建运行组件和完整 ZIP。构建机需先准备 `_alignment_runtime` 独立环境；本次 Python 3.8.20，固定依赖 stable-ts 2.19.1、openai-whisper 20250625、torch/torchaudio 2.4.1+cpu、numpy 1.24.4、numba 0.58.1、llvmlite 0.41.1、tiktoken 0.7.0、PyInstaller 6.16.0。最终用户无需安装这些。stable-ts 上游已归档，运行不自动更新。

本次整理已归档 `_alignment_runtime` 及外层重复组件。重建校准组件或完整 ZIP 前，应按 `rubbish/整理_20261003_204041` 中的移动清单恢复它们到原路径；软件运行无需恢复。普通主程序构建仍输出外层 EXE，构建后的新产物不会自动替换已验证的解压运行目录。

`build_offline_bundle.py` 验证模型官方 SHA-256，缺失时下载；递归收集 Conda FFmpeg/ffprobe 的 DLL、许可和构建配方，输出 ZIP 和清单。构建机 FFmpeg 路径通过参数给出，最终用户无需 Anaconda。

运行 `py -3 .\test_media_formats.py`、`py -3 .\test_packager_exe.py` 和 `py -3 .\test_alignment.py --source 素材目录` 验证。源码测试需 Pillow；测试只读真实素材，输出在临时目录，不改 TF 卡。结果见 `VALIDATION.md`。

2026-10-03 验证：GUI 窗口正常启动，PE 子系统为 Windows GUI；仅复制 EXE、移除 PATH 中的 Python 后，31 个文件生成及校验通过，并与源码版逐文件 SHA-256 一致。规范 WAV、名称、字幕和切图时间通过；本机 FFmpeg 非规范 WAV 转换及 `CREATE_NO_WINDOW` 检查通过。测试未改动真实素材或 TF 卡。

2026-10-03 说明页增量验证：内置内容、只读显示、滚动和独立关闭通过，完整 EXE 打包及音频转换回归仍通过。主界面点击“使用说明”即可查看，不依赖外部说明文件。

最新 EXE SHA-256 见 `MuseumTFPackager.exe.sha256`，上面的早期验证只记录历史版本。EXE 未签名，Windows 首次运行可能提示安全确认；分发前可核对校验值。

打包采用 [PyInstaller 官方单文件/无控制台选项](https://pyinstaller.org/en/stable/usage.html)。未重新实现界面或媒体转换逻辑。
