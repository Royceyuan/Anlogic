# 博物馆 TF 素材打包工具

这是主板媒体格式的 Windows 图形化检查与打包工具。它不会修改源素材或 FPGA 工程。

## 使用方法

1. 双击 `启动素材打包工具.bat`。
2. 选择包含 `01_文物名`～`05_文物名` 的素材根目录。
3. 先点“检查素材”，再点“生成 TF 素材包”。
4. 将生成目录中 `TF_CARD` 文件夹内的 **31 个文件**复制到 FAT32 TF 卡根目录。

生成目录同时包含 `package_report.txt` 和 `package_manifest.json`，记录图片尺寸、音频时长、字幕条数及每个板端文件的 SHA-256。这两个报告文件不要复制到 TF 卡。

## 每个文物目录必须包含

- `全貌图.png` 或 `全貌图.jpg`
- `细节1_*.png/.jpg`、`细节2_*.png/.jpg`、`细节3_*.png/.jpg`
- `讲解音频.wav`
- `字幕.srt`
- `图片切换脚本.md`

图片保持原宽高比和分辨率，只有超过主板上限 1920×1080 时才等比例缩小。音频统一转换为主板要求的 PCM16、48 kHz、双声道标准 WAV；字幕默认保留 SRT 原始时间戳（`direct`）。

若检查提示字幕结束时间超过音频，先核对是否选错音频。只有确认需要按音频总时长等比例压缩字幕时，才选择 `fit`；该模式会改变所有字幕时间点，生成后必须试听验收。

## 环境

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
