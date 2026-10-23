# 电脑端离线组件说明

这些组件仅用于电脑端素材制作，不是 FPGA IP，不进入 bit 或 TF 媒体包。

- Whisper 20250625 与官方 multilingual small 模型：MIT，https://github.com/openai/whisper 。模型 SHA-256：`9ecf779972d90ba49c06d968637d720dd632c55bbf19d441fb42bf17a411e794`。
- stable-ts 2.19.1：MIT，https://github.com/jianfch/stable-ts 。上游已归档，交付固定版本，不在运行时更新或下载代码。
- PyTorch/torchaudio 2.4.1 CPU、NumPy、Numba、llvmlite、tiktoken 等：原始许可随 `offline_licenses` 分发；模型不要求 CUDA。
- Python、Pillow、Tk/Tcl、PyInstaller：随附许可和发行元数据；PyInstaller 使用其发行例外。
- FFmpeg 6.1.2 及其动态库：使用开发机现有 Conda GPL 构建，以独立进程运行，未修改二进制。GPL 许可、Conda 包来源、具体构建配方和补丁保存在 `offline_licenses`；依赖包来源清单为 `native_components.json`。FFmpeg 原始源码：https://ffmpeg.org/releases/ffmpeg-6.1.2.tar.gz ，Conda 配方：https://github.com/conda-forge/ffmpeg-feedstock 。对外发布二进制前应按各组件许可提供对应源码和构建材料，不能仅以本说明替代许可义务。
- 微软雅黑从目标电脑 `C:\Windows\Fonts\msyh.ttc` 读取，不复制或分发 Windows 字体。

校准运行组件禁止建立网络连接，输入音频和字幕留在本机。校准仍可能有误，结果必须试听；源文件不覆盖。
