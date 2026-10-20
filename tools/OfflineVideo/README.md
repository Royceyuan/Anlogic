# TF离线视频转换

这是独立TF视频验证工程的命令行转换工具，不是MP4硬件解码器。电脑将视频预转为640×360或640×480、RGB565大端、静音的MVID文件；副板从TF读取原始像素。原博物馆TF打包软件与此独立试验分开使用。

在副板根目录执行：

```powershell
D:/Anaconda/python.exe tools/OfflineVideo/convert_video.py --self-test
D:/Anaconda/python.exe tools/OfflineVideo/convert_video.py --fps 30 --input "D:/VSCode/CodeFiles/Git_TD/素材/01_越王勾践剑_平放环绕正式版.mp4" --output "D:/VSCode/CodeFiles/Git_TD/素材/离线视频/VIDEO0.BIN" --ffmpeg "../Anlogic/tools/MuseumTFPackager/ffmpeg/ffmpeg.exe"
D:/Anaconda/python.exe tools/OfflineVideo/convert_video.py --check "D:/VSCode/CodeFiles/Git_TD/素材/离线视频/VIDEO0.BIN"
```

480行候选使用独立输出目录，不覆盖已通过素材：

```powershell
D:/Anaconda/python.exe tools/OfflineVideo/convert_video.py --height 480 --fps 30 --input "D:/VSCode/CodeFiles/Git_TD/素材/01_越王勾践剑_平放环绕正式版.mp4" --output "D:/VSCode/CodeFiles/Git_TD/素材/离线视频_640x480_30fps/VIDEO0.BIN" --ffmpeg "../Anlogic/tools/MuseumTFPackager/ffmpeg/ffmpeg.exe"
```

`--fps`只接受30或40，默认30。必须匹配烧录的验证bit；不能只修改旧文件头，否则会改变播放时长。源视频不足40fps时，普通重复采样不会产生新的动作细节。

转换保持原始时间轴，按目标帧率采样。默认360行等比缩放、必要时补边，每帧460800字节/900扇区；480行版将原16:9视场重新采样为640×480（样本宽高比4:3），FPGA横向2倍、纵向3:2放大后恢复为1280×720，不裁切或对原16:9片补黑边。480行均为新采样的有效内容，不是将360行上下加黑边；每帧614400字节/1200扇区。若原输入非16:9，先等比置入16:9视场，再作相同采样。

输出512字节头，包含版本、尺寸、帧率、帧数、长度、像素格式及CRC32。FPGA严格匹配构建的高度和帧率，360/480行素材错配会被拒绝。转换完成后重新读取整文件计算SHA256并生成同名JSON，不覆盖已有文件；失败的.part和日志保留用于检查。480行暂仅支持30fps，40fps仅用于识别历史360行文件。

将匹配的VIDEO0.BIN复制到FAT32 TF根目录之前，请先备份原文件，不格式化卡。现有输出文件不会覆盖，重新转换时请另选文件名或先备份移动原文件。当前仅推进30fps，40fps专用产物已归档至工作区 `rubbish/secondary_tf_video_40fps_20261020`；转换器保留对历史40fps文件的识别能力。播放说明见 `experiments/tf_video/PLAYBACK.md`。
