# 博物馆 TF 素材打包工具

这是主板媒体格式的 Windows 图形化检查与打包工具。它不会修改源素材或 FPGA 工程。

## 使用方法

1. 双击 `MuseumTFPackager.exe`（不弹终端，无需安装 Python/Pillow）；原 BAT 保留供源码调试。
2. 选择包含 `01_文物名`～`05_文物名` 的素材根目录。
3. 先点“检查素材”，再点“生成 TF 素材包”。
4. 将生成目录中 `TF_CARD` 文件夹内的 **31 个文件**复制到 FAT32 TF 卡根目录。

生成目录同时包含 `package_report.txt` 和 `package_manifest.json`，记录图片尺寸、音频时长、字幕条数及每个板端文件的 SHA-256。这两个报告文件不要复制到 TF 卡。

主界面右侧新增“使用说明”按钮：内置可滚动说明页，包含目录与文件命名、检查/打包/写卡流程、图片及音频格式、direct/auto/fit 区别、SRT 和切图 Markdown 示例、输出清单及常见错误。无需打开 README；关闭说明不会退出打包工具，打包及时间轴逻辑不变。

## 每个文物目录必须包含

- `全貌图.png` 或 `全貌图.jpg`
- `细节1_*.png/.jpg`、`细节2_*.png/.jpg`、`细节3_*.png/.jpg`
- `讲解音频.wav`
- `字幕.srt`
- `图片切换脚本.md`

图片保持原宽高比和分辨率，只有超过主板上限 1920×1080 时才等比例缩小。音频统一转换为主板要求的 PCM16、48 kHz、双声道标准 WAV；字幕默认保留 SRT 原始时间戳（`direct`）。

若检查提示字幕结束时间超过音频，先核对是否选错音频。只有确认需要按音频总时长等比例压缩字幕时，才选择 `fit`；该模式会改变所有字幕时间点，生成后必须试听验收。

## 环境

EXE 已包含 Python、Tkinter、Pillow 和名称/字幕生成模块。仅支持 Windows x64；依赖 Windows 自带微软雅黑字体。首次启动需要解包，可能稍等几秒。

源音频已是规范 WAV 时，EXE 可直接完成打包；非规范 WAV 仍需本机 FFmpeg（未打入 EXE），转换时不会弹终端。源图片、字幕、时间轴处理规则不变。

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

运行 `py -3 .\test_packager_exe.py` 可测试单文件 EXE 的无终端格式、打包输出和校验清单；测试素材及输出仅存在临时目录，不改动 TF 卡或当前素材。

2026-10-03 验证：GUI 窗口正常启动，PE 子系统为 Windows GUI；仅复制 EXE、移除 PATH 中的 Python 后，31 个文件生成及校验通过，并与源码版逐文件 SHA-256 一致。规范 WAV、名称、字幕和切图时间通过；本机 FFmpeg 非规范 WAV 转换及 `CREATE_NO_WINDOW` 检查通过。测试未改动真实素材或 TF 卡。

2026-10-03 说明页增量验证：内置内容、只读显示、滚动和独立关闭通过，完整 EXE 打包及音频转换回归仍通过。主界面点击“使用说明”即可查看，不依赖外部说明文件。

本次 EXE 大小 20,404,797 字节，SHA-256 见 `MuseumTFPackager.exe.sha256`。EXE 未签名，Windows 首次运行可能提示安全确认；分发前可核对校验值。

打包采用 [PyInstaller 官方单文件/无控制台选项](https://pyinstaller.org/en/stable/usage.html)。未重新实现界面或媒体转换逻辑。
