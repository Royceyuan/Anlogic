using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Ports;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Microsoft.Win32;
using Forms = System.Windows.Forms;

// PC decodes local media; HDMI carries AV, UART only authorizes the FPGA mux.
// No network, third-party player, or package-tool dependency.
static class Protocol
{
    internal static byte Crc(byte[] bytes, int length)
    {
        byte crc = 0;
        for (int n = 0; n < length; n++) {
            crc ^= bytes[n];
            for (int b = 0; b < 8; b++) crc = (byte)((crc << 1) ^ ((crc & 128) != 0 ? 7 : 0));
        }
        return crc;
    }
    internal static byte[] Request(byte command, byte seq)
    {
        byte[] data = { 0xa5, 0x5a, command, seq, 0 };
        data[4] = Crc(data, 4); return data;
    }
    internal sealed class Decoder
    {
        readonly byte[] bytes = new byte[5];
        int index;
        internal bool Feed(byte value, out byte seq, out byte flags)
        {
            seq = flags = 0;
            if (index == 0) { if (value == 0x5a) { bytes[0] = value; index = 1; } return false; }
            if (index == 1 && value != 0xa5) { index = value == 0x5a ? 1 : 0; return false; }
            bytes[index++] = value;
            if (index != 5) return false;
            index = 0;
            if (Crc(bytes, 4) != bytes[4]) { if (value == 0x5a) index = 1; return false; }
            seq = bytes[2]; flags = bytes[3]; return true;
        }
    }
    internal static void SelfTest()
    {
        if (Crc(Encoding.ASCII.GetBytes("123456789"), 9) != 0xf4) throw new Exception("CRC vector");
        var decoder = new Decoder(); byte seq, flags;
        byte[] ack = { 0x5a, 0xa5, 7, 11, 0 }; ack[4] = Crc(ack, 4);
        for (int n = 0; n < 5; n++) if (decoder.Feed(ack[n], out seq, out flags) != (n == 4)) throw new Exception("ACK framing");
        byte[] bad = (byte[])ack.Clone(); bad[4] ^= 1;
        foreach (byte b in bad) if (decoder.Feed(b, out seq, out flags)) throw new Exception("CRC rejection");
        decoder.Feed(0x5a, out seq, out flags);
        int decoded = 0;
        foreach (byte b in ack) if (decoder.Feed(b, out seq, out flags)) { decoded++; if (seq != 7 || flags != 11) throw new Exception("Resync"); }
        if (decoded != 1) throw new Exception("Missing resynchronized ACK");
        if (!Request(1, 7).Take(4).SequenceEqual(new byte[] { 0xa5, 0x5a, 1, 7 })) throw new Exception("Request");
    }
}

sealed class VideoWindow : Window
{
    internal readonly MediaElement Media = new MediaElement {
        LoadedBehavior = MediaState.Manual, UnloadedBehavior = MediaState.Close,
        ScrubbingEnabled = true, Stretch = Stretch.Uniform, IsMuted = true
    };
    internal VideoWindow(Forms.Screen screen)
    {
        WindowStyle = WindowStyle.None; ResizeMode = ResizeMode.NoResize;
        Background = Brushes.Black; ShowInTaskbar = false; ShowActivated = false; Topmost = true; Content = Media;
        Show();
        var r = screen.Bounds;
        if (!SetWindowPos(new WindowInteropHelper(this).Handle, new IntPtr(-1), r.X, r.Y, r.Width, r.Height, 0x50)) {
            Close(); throw new System.ComponentModel.Win32Exception("无法定位视频扩展屏");
        }
    }
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int width, int height, uint flags);
}

sealed class ScreenChoice
{
    internal Forms.Screen Screen;
    internal string Name;
    public override string ToString() { return Name + " | " + Screen.DeviceName + " | " + Screen.Bounds.Width + "×" + Screen.Bounds.Height; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct DisplayDevice {
        public int Size;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public uint Flags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceId;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool EnumDisplayDevices(string name, uint index, ref DisplayDevice device, uint flags);
    internal static ScreenChoice From(Forms.Screen screen)
    {
        string name = screen.Primary ? "电脑主屏" : "扩展屏";
        try {
            var device = new DisplayDevice { Size = Marshal.SizeOf(typeof(DisplayDevice)) };
            if (EnumDisplayDevices(screen.DeviceName, 0, ref device, 1) && !String.IsNullOrEmpty(device.DeviceId)) {
                string[] id = device.DeviceId.Split('#');
                if (id.Length >= 3) using (var key = Registry.LocalMachine.OpenSubKey("SYSTEM\\CurrentControlSet\\Enum\\DISPLAY\\" + id[1] + "\\" + id[2] + "\\Device Parameters")) {
                    byte[] edid = key == null ? null : key.GetValue("EDID") as byte[];
                    if (edid != null && edid.Length >= 128) for (int n = 54; n <= 108; n += 18)
                        if (edid[n] == 0 && edid[n+1] == 0 && edid[n+3] == 0xfc) name = Encoding.ASCII.GetString(edid, n+5, 13).Trim('\0', '\r', '\n', ' ');
                }
            }
        } catch (System.Security.SecurityException) { } catch (UnauthorizedAccessException) { }
        return new ScreenChoice { Screen = screen, Name = name };
    }
}

sealed class ControllerWindow : Window
{
    enum Phase { Idle, Preparing, Authorizing, Playing, Paused, Stopping }
    readonly ComboBox ports = new ComboBox(), screens = new ComboBox();
    readonly TextBox file = new TextBox { IsReadOnly = true };
    readonly TextBlock status = new TextBlock { TextWrapping = TextWrapping.Wrap };
    readonly DispatcherTimer timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(50) };
    readonly Button play, pause;
    SerialPort port;
    VideoWindow video;
    Phase phase;
    byte nextSeq, pendingSeq, pendingCommand, flags;
    bool pending, linked;
    int attempts;
    DateTime sentAt, replyAt, prepareAt, firstFrameAt, releaseAt, stopDeadline;
    bool opened, stopConfirmed, closeAfterStop, closeNow;
    string stopMessage;
    internal ControllerWindow()
    {
        Title = "博物馆副屏 · 本地视频播放"; Width = 940; Height = 690; MinWidth = 860; MinHeight = 650;
        FontFamily = new FontFamily("Microsoft YaHei UI"); FontSize = 14;
        Foreground = new SolidColorBrush(Color.FromRgb(33,62,56));
        Icon = Asset("museum_icon");
        Resources.Add(typeof(Button), System.Windows.Markup.XamlReader.Parse(@"
<Style xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' TargetType='Button'>
 <Setter Property='Background' Value='#E5EADE'/><Setter Property='Foreground' Value='#213E38'/>
 <Setter Property='BorderBrush' Value='#C1CEC3'/><Setter Property='BorderThickness' Value='1'/>
 <Setter Property='Cursor' Value='Hand'/><Setter Property='Template'><Setter.Value>
 <ControlTemplate TargetType='Button'><Border x:Name='Surface' xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
 Background='{TemplateBinding Background}' BorderBrush='{TemplateBinding BorderBrush}' BorderThickness='{TemplateBinding BorderThickness}' CornerRadius='7'>
 <ContentPresenter Margin='{TemplateBinding Padding}' HorizontalAlignment='Center' VerticalAlignment='Center'/></Border>
 <ControlTemplate.Triggers><Trigger Property='IsMouseOver' Value='True'><Setter TargetName='Surface' Property='Opacity' Value='0.82'/></Trigger>
 <Trigger Property='IsPressed' Value='True'><Setter TargetName='Surface' Property='Opacity' Value='0.65'/></Trigger>
 <Trigger Property='IsKeyboardFocused' Value='True'><Setter TargetName='Surface' Property='BorderBrush' Value='#AD8645'/><Setter TargetName='Surface' Property='BorderThickness' Value='2'/></Trigger>
 <Trigger Property='IsEnabled' Value='False'><Setter TargetName='Surface' Property='Opacity' Value='0.45'/><Setter Property='Cursor' Value='Arrow'/></Trigger>
 </ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>"));
        var root = new Grid { Background = new ImageBrush(Asset("museum_wallpaper")) { Stretch = Stretch.UniformToFill } };
        Content = root;
        var layout = new StackPanel { Margin = new Thickness(26) }; root.Children.Add(layout);
        var header = new DockPanel { Margin = new Thickness(0,0,0,24) };
        header.Children.Add(new Image { Source = Icon, Width = 72, Height = 72, Margin = new Thickness(0,0,18,0) });
        var heading = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        heading.Children.Add(new TextBlock { Text = "博物馆影像放映", FontSize = 28, FontWeight = FontWeights.SemiBold, Foreground = Brushes.Cornsilk });
        heading.Children.Add(new TextBlock { Text = "HDMI 音视频  /  USB 串口授权  /  停止后回到本地展陈", Foreground = Brushes.Wheat, FontSize = 13, Margin = new Thickness(0,8,0,0) });
        header.Children.Add(heading); layout.Children.Add(header);
        var panel = new StackPanel();
        layout.Children.Add(Card(panel));
        panel.Children.Add(new TextBlock { Text = "01  连接设备与选择视频", FontSize = 17, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0,0,0,12) });
        panel.Children.Add(Row("副板 USB-UART 串口", ports, MakeButton("刷新", Refresh), MakeButton("连接 / 重连", Connect)));
        panel.Children.Add(Row("AnlogicHDMI 扩展屏", screens, MakeButton("刷新", Refresh)));
        panel.Children.Add(Row("本地视频", file, MakeButton("选择视频", ChooseFile)));
        play = MakeButton("播放到副屏", StartVideo); pause = MakeButton("暂停 / 继续", PauseVideo);
        play.Background = new SolidColorBrush(Color.FromRgb(34,91,78)); play.Foreground = Brushes.Cornsilk;
        play.BorderBrush = play.Background;
        var actions = new WrapPanel { Margin = new Thickness(0,12,0,12) };
        actions.Children.Add(play); actions.Children.Add(pause); actions.Children.Add(MakeButton("停止并回本地", () => StopVideo("已停止，副板恢复本地内容。")));
        actions.Children.Add(MakeButton("使用说明", () => MessageBox.Show(
            "1. 电脑HDMI→副板HDMIA；副板HDMIB→屏幕。\n2. 电脑USB→副板USB-UART Type-C，不是USB-JTAG。\n3. Windows扩展AnlogicHDMI：1280×720、60/59.94Hz、RGB8、SDR。\n4. Windows声音输出选择AnlogicHDMI，双声道48kHz/24-bit PCM。\n5. 选择串口并连接，选择AnlogicHDMI扩展屏和本地视频，再播放。\n暂停保持视频画面；结束/停止恢复本地；程序异常关闭约3秒回退。\n软件使用Windows媒体组件，建议MP4(H.264/AAC)；不支持的编解码会明确报错。", "使用说明")));
        panel.Children.Add(actions);
        var statePanel = new StackPanel();
        statePanel.Children.Add(new TextBlock { Text = "02  播放与连接状态", FontWeight = FontWeights.SemiBold, FontSize = 16, Margin = new Thickness(0,0,0,10) });
        status.MinHeight = 46; status.LineHeight = 24; statePanel.Children.Add(status);
        var stateCard = Card(statePanel); stateCard.Margin = new Thickness(0,16,0,0); layout.Children.Add(stateCard);
        Refresh(); SetStatus("先连接副板串口；未点击播放时，HDMI 常连接仍保持本地展示。");
        timer.Tick += Tick; timer.Start();
        Closing += (s,e) => {
            if (!closeNow && video != null) { e.Cancel = true; closeAfterStop = true; StopVideo("撤销显示授权后关闭。"); return; }
            timer.Stop(); try { Send(2); } catch (Exception) { }
            Disconnect(); FinishStop();
        };
    }
    static BitmapFrame Asset(string name)
    {
        using (var stream = typeof(ControllerWindow).Assembly.GetManifestResourceStream(name))
            return BitmapFrame.Create(stream, BitmapCreateOptions.None, BitmapCacheOption.OnLoad);
    }
    static Border Card(UIElement content)
    {
        return new Border { Child = content, Background = new SolidColorBrush(Color.FromRgb(246,243,235)),
            BorderBrush = new SolidColorBrush(Color.FromRgb(214,214,195)), BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(12), Padding = new Thickness(22) };
    }
    static Button MakeButton(string text, Action click)
    {
        var button = new Button { Content = text, Padding = new Thickness(13,7,13,7), Margin = new Thickness(4) };
        button.Click += (s,e) => click(); return button;
    }
    static UIElement Row(string label, Control control, params Button[] buttons)
    {
        var row = new DockPanel { Margin = new Thickness(0,6,0,6) };
        row.Children.Add(new TextBlock { Text = label, Width = 154, VerticalAlignment = VerticalAlignment.Center });
        foreach (Button b in buttons) { DockPanel.SetDock(b,Dock.Right); row.Children.Add(b); }
        control.Margin = new Thickness(4); control.MinHeight = 36;
        control.Background = Brushes.FloralWhite; control.Padding = new Thickness(7,4,7,4);
        control.VerticalContentAlignment = VerticalAlignment.Center;
        control.BorderBrush = new SolidColorBrush(Color.FromRgb(193,206,195));
        row.Children.Add(control); return row;
    }
    void SetStatus(string text) { status.Text = text; play.IsEnabled = linked && phase == Phase.Idle; pause.IsEnabled = phase == Phase.Playing || phase == Phase.Paused; }
    void Refresh()
    {
        if (phase != Phase.Idle) return;
        string selected = ports.SelectedItem as string;
        ports.ItemsSource = SerialPort.GetPortNames().OrderBy(x => x).ToArray();
        ports.SelectedItem = selected; if (ports.SelectedIndex < 0 && ports.Items.Count == 1) ports.SelectedIndex = 0;
        var choices = Forms.Screen.AllScreens.Select(ScreenChoice.From).ToArray(); screens.ItemsSource = choices;
        screens.SelectedItem = choices.FirstOrDefault(x => x.Name.IndexOf("Anlogic", StringComparison.OrdinalIgnoreCase) >= 0);
    }
    void ChooseFile()
    {
        if (phase != Phase.Idle) return;
        var dialog = new OpenFileDialog { Filter = "视频文件|*.mp4;*.wmv;*.avi;*.mkv;*.mov|全部文件|*.*" };
        if (dialog.ShowDialog(this) == true) file.Text = dialog.FileName;
    }
    void Connect()
    {
        if (phase != Phase.Idle) { StopVideo("先停止视频，再重新连接。"); return; }
        StopVideo("重新连接"); Disconnect();
        string name = ports.SelectedItem as string;
        if (name == null) { SetStatus("请选择副板 CH340 对应的 COM 口。"); return; }
        try {
            var current = new SerialPort(name, 115200, Parity.None, 8, StopBits.One) { WriteTimeout = 300, ReadTimeout = 300, DtrEnable = false, RtsEnable = false };
            var decoder = new Protocol.Decoder(); port = current;
            current.DataReceived += (s,e) => Receive(current,decoder); current.Open();
            replyAt = DateTime.UtcNow; Send(2); SetStatus("验证副板应答，默认先停止外部视频。");
        } catch (Exception e) { Disconnect(); SetStatus("串口连接失败：" + e.Message); }
    }
    void Receive(SerialPort current, Protocol.Decoder decoder)
    {
        try {
            if (!ReferenceEquals(current, port)) return;
            while (current.IsOpen && current.BytesToRead > 0) {
                byte seq, value; int b = current.ReadByte();
                if (b >= 0 && decoder.Feed((byte)b, out seq, out value)) {
                    byte capturedSeq = seq, capturedFlags = value;
                    Dispatcher.BeginInvoke(new Action(() => Acknowledge(current, capturedSeq, capturedFlags)));
                }
            }
        } catch (InvalidOperationException) { } catch (IOException) { } catch (TimeoutException) { }
    }
    void Acknowledge(SerialPort current, byte seq, byte value)
    {
        if (!ReferenceEquals(current,port) || !pending || seq != pendingSeq) return;
        byte acknowledgedCommand = pendingCommand;
        pending = false; flags = value; linked = true; replyAt = DateTime.UtcNow;
        if ((flags & 128) != 0) { StopVideo("副板拒绝命令：请检查 AnlogicHDMI 是否已启用为720p扩展屏。"); return; }
        if (phase == Phase.Stopping && (acknowledgedCommand == 2 || acknowledgedCommand == 3) && (flags & 14) == 0) stopConfirmed = true;
        if (phase == Phase.Idle) SetStatus("已连接；HDMI输入" + ((flags & 1) != 0 ? "有效" : "未就绪") + "，当前保持副板本地内容。");
        else if (phase == Phase.Authorizing || phase == Phase.Playing || phase == Phase.Paused)
            if ((flags & 9) != 9) StopVideo("HDMI信源失效或授权已撤销，已退回本地。请重新播放。");
    }
    void Send(byte command)
    {
        if (port == null || !port.IsOpen) return;
        pendingCommand = command; pendingSeq = ++nextSeq; attempts = 1; pending = true; sentAt = DateTime.UtcNow;
        port.Write(Protocol.Request(command, pendingSeq), 0, 5);
    }
    void Disconnect()
    {
        linked = false; pending = false;
        var current = port; port = null;
        if (current != null) current.Dispose();
    }
    void StartVideo()
    {
        var target = screens.SelectedItem as ScreenChoice;
        if (!linked || phase != Phase.Idle) return;
        if (target == null || target.Name.IndexOf("Anlogic",StringComparison.OrdinalIgnoreCase) < 0 || target.Screen.Primary || target.Screen.Bounds.Width != 1280 || target.Screen.Bounds.Height != 720) { SetStatus("请选择1280×720的AnlogicHDMI扩展屏，不要选择电脑主屏或独立DP显示器。"); return; }
        if (!File.Exists(file.Text)) { SetStatus("请先选择存在的本地视频文件。"); return; }
        try {
            phase = Phase.Preparing; opened = false; releaseAt = DateTime.MaxValue; prepareAt = DateTime.UtcNow;
            video = new VideoWindow(target.Screen); var currentVideo = video;
            video.Media.MediaOpened += (s,e) => {
                if (!ReferenceEquals(video,currentVideo) || phase != Phase.Preparing) return;
                if (!currentVideo.Media.HasVideo) { StopVideo("所选文件不包含可解码的视频画面。"); return; }
                currentVideo.Media.Pause(); currentVideo.Media.Position = TimeSpan.Zero;
                opened = true; firstFrameAt = DateTime.UtcNow.AddMilliseconds(300);
            };
            video.Media.MediaEnded += (s,e) => { if (ReferenceEquals(video,currentVideo)) StopVideo("视频结束，副板恢复本地内容。"); };
            video.Media.MediaFailed += (s,e) => { if (ReferenceEquals(video,currentVideo)) StopVideo("视频解码失败：" + e.ErrorException.Message); };
            video.Closing += (s,e) => { if (ReferenceEquals(video,currentVideo)) { e.Cancel = true; StopVideo("播放窗口关闭，副板恢复本地内容。"); } };
            video.Media.Source = new Uri(file.Text, UriKind.Absolute); video.Media.Play();
            SetStatus("准备静音首帧；副板仍保持本地，待视频就绪后授权显示。");
        } catch (Exception e) { StopVideo("无法播放：" + e.Message); }
    }
    void PauseVideo()
    {
        if (video == null) return;
        if (phase == Phase.Playing) { video.Media.Pause(); phase = Phase.Paused; SetStatus("已暂停；视频首选显示授权继续保活。"); }
        else if (phase == Phase.Paused) { video.Media.Play(); phase = Phase.Playing; SetStatus("继续播放。"); }
    }
    void StopVideo(string message)
    {
        if (phase == Phase.Stopping) return;
        stopMessage = message; stopConfirmed = false; opened = false;
        phase = video == null ? Phase.Idle : Phase.Stopping;
        stopDeadline = DateTime.UtcNow.AddMilliseconds(3300);
        if (video != null) { video.Media.IsMuted = true; video.Media.Pause(); }
        // Keep the paused video covering the desktop until local output is
        // confirmed, or until the hardware watchdog must have expired.
        try { Send(2); } catch (InvalidOperationException) { } catch (IOException) { } catch (TimeoutException) { }
        SetStatus(message);
    }
    void FinishStop()
    {
        phase = Phase.Idle; var previous = video; video = null;
        if (previous != null) { previous.Media.Stop(); previous.Media.Close(); previous.Close(); }
        SetStatus(stopMessage ?? "已停止。");
        if (closeAfterStop && !closeNow) { closeNow = true; Close(); }
    }
    void Tick(object sender, EventArgs e)
    {
        DateTime now = DateTime.UtcNow;
        try {
            if (phase == Phase.Stopping && (stopConfirmed || now >= stopDeadline)) { FinishStop(); return; }
            if (port == null || !port.IsOpen) return;
            if (pending && (now - sentAt).TotalMilliseconds > 250) {
                if (attempts++ >= 3) { StopVideo("串口应答超时；请确认COM口和新副板bit。硬件最长约3秒回退。"); Disconnect(); return; }
                port.Write(Protocol.Request(pendingCommand,pendingSeq),0,5); sentAt = now;
            }
            if (phase == Phase.Preparing) {
                if ((now - prepareAt).TotalSeconds > 10) { StopVideo("视频或HDMI准备超时，请检查输入格式和视频编解码。"); return; }
                if (opened && now >= firstFrameAt && (flags & 1) != 0 && !pending) {
                    phase = Phase.Authorizing; Send(1); SetStatus("切入HDMI视频，等待输出和显示器稳定。");
                }
            }
            if (phase == Phase.Authorizing && (flags & 15) == 11) {
                if (releaseAt == DateTime.MaxValue) releaseAt = now.AddMilliseconds(700);
                if (now >= releaseAt) { video.Media.IsMuted = false; video.Media.Play(); phase = Phase.Playing; SetStatus("正在播放；视频和声音均走HDMI，停止后回到本地内容。"); }
            }
            if (!pending && (now - replyAt).TotalMilliseconds >= 250) Send(phase == Phase.Idle || phase == Phase.Preparing || phase == Phase.Stopping ? (byte)3 : (byte)4);
        } catch (InvalidOperationException e2) { StopVideo("串口异常："+e2.Message); Disconnect(); }
          catch (IOException e2) { StopVideo("串口断开："+e2.Message); Disconnect(); }
          catch (TimeoutException e2) { StopVideo("串口发送超时："+e2.Message); Disconnect(); }
    }
}

static class Program
{
    [STAThread] static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--self-test") {
            try { Protocol.SelfTest(); return 0; } catch { return 1; }
        }
        if (args.Length == 2 && args[0] == "--media-test") return MediaTest(args[1]);
        if (args.Length == 2 && args[0] == "--ui-test") {
            var testApp = new Application(); var window = new ControllerWindow();
            var panel = (FrameworkElement)window.Content;
            panel.Measure(new Size(940,650)); panel.Arrange(new Rect(0,0,940,650)); panel.UpdateLayout();
            var drawing = new DrawingVisual();
            using (var context = drawing.RenderOpen()) {
                context.DrawRectangle(new VisualBrush(panel),null,new Rect(0,0,940,650));
            }
            var bitmap = new System.Windows.Media.Imaging.RenderTargetBitmap(940,650,96,96,PixelFormats.Pbgra32);
            bitmap.Render(drawing);
            var encoder = new System.Windows.Media.Imaging.PngBitmapEncoder();
            encoder.Frames.Add(System.Windows.Media.Imaging.BitmapFrame.Create(bitmap));
            using (var output = File.Create(args[1])) encoder.Save(output);
            window.Close(); testApp.Shutdown(); return 0;
        }
        if (args.Length != 0) return 2;
        var app = new Application(); return app.Run(new ControllerWindow());
    }
    static int MediaTest(string path)
    {
        bool passed = false; var frame = new DispatcherFrame(); var player = new MediaPlayer { Volume = 0 };
        var timeout = new DispatcherTimer { Interval = TimeSpan.FromSeconds(10) };
        timeout.Tick += (s,e) => frame.Continue = false;
        player.MediaOpened += (s,e) => { if (player.HasAudio && player.HasVideo && player.NaturalVideoWidth > 0) player.Play(); else frame.Continue = false; };
        player.MediaEnded += (s,e) => { passed = true; frame.Continue = false; };
        player.MediaFailed += (s,e) => frame.Continue = false;
        timeout.Start(); player.Open(new Uri(Path.GetFullPath(path))); Dispatcher.PushFrame(frame);
        timeout.Stop(); player.Close(); return passed ? 0 : 1;
    }
}
