using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Ports;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Xml;
using System.Xml.Linq;
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
        readonly byte[] bytes = new byte[8];
        int index;
        internal bool HasContext;
        internal byte Artifact, State, Scene;
        internal bool Feed(byte value, out byte seq, out byte flags)
        {
            seq = flags = 0;
            if (index == 0) { if (value == 0x5a) { bytes[0] = value; index = 1; } return false; }
            if (index == 1 && value != 0xa5 && value != 0xa6) { index = value == 0x5a ? 1 : 0; return false; }
            bytes[index++] = value;
            int length = bytes[1] == 0xa6 ? 8 : 5;
            if (index != length) return false;
            index = 0;
            if (Crc(bytes, length-1) != bytes[length-1]) { if (value == 0x5a) index = 1; return false; }
            HasContext = length == 8;
            if (HasContext) { Artifact = bytes[4]; State = bytes[5]; Scene = bytes[6]; }
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
        byte[] context = { 0x5a,0xa6,8,1,4,7,2,0 }; context[7] = Crc(context,7);
        decoded = 0;
        foreach (byte b in context) if (decoder.Feed(b,out seq,out flags)) decoded++;
        if (decoded != 1 || !decoder.HasContext || decoder.Artifact != 4 || decoder.State != 7 || decoder.Scene != 2) throw new Exception("Context framing");
        context[7] ^= 1;
        foreach (byte b in context) if (decoder.Feed(b,out seq,out flags)) throw new Exception("Context CRC rejection");
        foreach (byte b in ack) decoder.Feed(b,out seq,out flags);
        if (decoder.HasContext) throw new Exception("Legacy ACK compatibility");
        VideoSettings.SelfTest();
        if (LinkedArtifact(3,2) != 2 || LinkedArtifact(7,2) != 2 || LinkedArtifact(0x1b,2) != 5 ||
            LinkedArtifact(9,255)!=5 || LinkedArtifact(8,2)!=-1 || LinkedArtifact(0x49,2)!=-1 ||
            LinkedArtifact(2,2) != -1 || LinkedArtifact(0x43,2) != -1 || LinkedArtifact(3,255) != -1) throw new Exception("Link policy");
    }
    internal static int LinkedArtifact(byte state, byte artifact)
    { return (state&0x49)==9 ? 5 : (state & 0x4b) == 3 && artifact < 5 ? artifact : -1; }
}

sealed class VideoSettings
{
    internal static readonly string PathName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"DualFPGAMuseum","VideoPlayer.xml");
    internal static readonly string[] Names = { "越王勾践剑", "四羊方尊", "金缕玉衣", "马踏飞燕", "长信宫灯", "应急疏散指引" };
    internal string[] Videos = new string[6];
    internal string Port = "";
    internal static VideoSettings Load(string path)
    {
        var result = new VideoSettings();
        if (!File.Exists(path)) return result;
        using (var reader = XmlReader.Create(path,new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null })) {
            var root = XDocument.Load(reader).Root;
            if (root == null || root.Name != "museumVideos") throw new XmlException("配置文件格式不正确");
            result.Port = (string)root.Element("port") ?? "";
            result.Videos[5] = (string)root.Element("emergencyVideo") ?? "";
            foreach (var row in root.Elements("video")) {
                int id; if (Int32.TryParse((string)row.Attribute("id"),out id) && id >= 0 && id < 5) result.Videos[id] = row.Value;
            }
        }
        return result;
    }
    internal void Save(string path)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        var root = new XElement("museumVideos",new XElement("port",Port));
        for (int i=0;i<5;i++) root.Add(new XElement("video",new XAttribute("id",i),Videos[i] ?? ""));
        root.Add(new XElement("emergencyVideo",Videos[5] ?? ""));
        string temporary = path+".tmp"; new XDocument(root).Save(temporary);
        if (File.Exists(path)) File.Replace(temporary,path,null); else File.Move(temporary,path);
    }
    internal static void SelfTest()
    {
        string folder = Path.Combine(Path.GetTempPath(),"MuseumVideoConfig_"+Guid.NewGuid().ToString("N"));
        string path = Path.Combine(folder,"settings.xml");
        try {
            var value = new VideoSettings { Port = "COM7", Videos = new[] { "D:\\可移动素材\\视频&1.mp4", "", "E:\\其他位置\\2.mp4", "", "", "D:\\应急\\疏散.mp4" } };
            value.Save(path); value.Save(path); var loaded = Load(path);
            if (loaded.Port != value.Port || !loaded.Videos.SequenceEqual(value.Videos)) throw new Exception("Settings roundtrip");
            File.WriteAllText(path,"<museumVideos><video id='2'>old.mp4</video></museumVideos>");
            loaded=Load(path);if(loaded.Videos[2]!="old.mp4"||loaded.Videos[5]!="") throw new Exception("Legacy five-video settings compatibility");
            File.WriteAllText(path,"<invalid>");
            try { Load(path); throw new Exception("Malformed settings accepted"); } catch (XmlException) { }
        } finally { File.Delete(path);File.Delete(path+".tmp");if(Directory.Exists(folder)) Directory.Delete(folder); }
    }
}

sealed class VideoWindow : Window
{
    internal readonly MediaElement Media;
    internal static MediaElement CreateMedia() { return new MediaElement {
        LoadedBehavior = MediaState.Manual, UnloadedBehavior = MediaState.Close,
        ScrubbingEnabled = true, Stretch = Stretch.Uniform, IsMuted = true
    }; }
    internal VideoWindow(Forms.Screen screen, MediaElement prepared = null)
    {
        Media = prepared ?? CreateMedia();
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
    enum Phase { Idle, Warming, Preparing, Authorizing, Playing, Paused, Stopping }
    readonly ComboBox ports = new ComboBox(), screens = new ComboBox();
    readonly TextBox file = new TextBox { IsReadOnly = true };
    readonly TextBlock status = new TextBlock { TextWrapping = TextWrapping.Wrap };
    readonly TextBlock mainStatus = new TextBlock { TextWrapping = TextWrapping.Wrap, FontSize = 13, Margin = new Thickness(0,8,0,0) };
    readonly CheckBox automatic = new CheckBox { Content = "联动模式：文物视频 / 应急优先（静音）", Margin = new Thickness(4,12,0,4) };
    readonly DispatcherTimer timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(50) };
    readonly Grid emergencyCacheHost = new Grid { Width=1,Height=1,Opacity=0,IsHitTestVisible=false,
        HorizontalAlignment=HorizontalAlignment.Left,VerticalAlignment=VerticalAlignment.Top };
    MediaElement emergencyCache;
    string emergencyCachePath,emergencyFailedPath;
    DateTime emergencyCacheAt,emergencyReadyAt=DateTime.MaxValue;
    bool EmergencyPrepared { get { return emergencyCache!=null&&DateTime.UtcNow>=emergencyReadyAt; } }
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
    VideoSettings settings = new VideoSettings();
    bool contextKnown,contextAvailable,nextContext=true,autoSession,autoHold,configuring,settingsValid=true;
    byte museumArtifact=255,museumState,museumScene=255;
    int activeArtifact=-1,failedArtifact=-1;
    DateTime contextAt;
    DateTime fileCheckedAt;
    bool warmHintSent,warmSupported=true,observedOverview,observedEmergency;
    bool AutoEnabled { get { return automatic.IsChecked == true; } }
    bool ContextFresh { get { return contextAvailable && (DateTime.UtcNow-contextAt).TotalMilliseconds < 1500; } }
    internal static void SelfTest()
    {
        var app=new Application();var window=new ControllerWindow();
        try {
            window.settings=new VideoSettings();window.linked=true;window.flags=1;
            window.contextAvailable=true;window.contextAt=DateTime.UtcNow;
            window.museumArtifact=2;window.museumState=3;window.automatic.IsChecked=true;
            window.UpdateAutomatic();
            if(window.video!=null||window.failedArtifact!=2||!window.status.Text.Contains("未配置")) throw new Exception("Missing video must stay local");
            window.UpdateAutomatic();
            if(window.failedArtifact!=2) throw new Exception("Repeated missing-path control");
            window.museumArtifact=4;window.UpdateAutomatic();
            if(window.failedArtifact!=4) throw new Exception("One missing artifact blocked another");
            window.autoSession=true;window.activeArtifact=4;window.museumState=11;window.UpdateAutomatic();
            if(!window.observedEmergency||window.phase!=Phase.Idle) throw new Exception("Emergency did not revoke ordinary video");
            window.autoSession=false;window.autoHold=false;window.UpdateAutomatic();
            if(window.failedArtifact!=5||window.video!=null) throw new Exception("Missing emergency video bypassed local fallback");
            window.museumState=8;window.UpdateAutomatic();
            if(!window.autoHold||window.observedEmergency) throw new Exception("Lost emergency state retained eligibility");
            window.museumState=9;window.UpdateAutomatic();
            if(window.autoHold||window.failedArtifact!=5) throw new Exception("Fresh emergency reconnect did not select emergency fallback");
            window.FinishStop();window.museumState=3;window.UpdateAutomatic();
            if(!window.autoHold||window.video!=null) throw new Exception("Emergency clear resumed old video");
            window.museumState=1;window.museumScene=255;window.UpdateAutomatic();
            if(window.autoHold||window.failedArtifact!=-1) throw new Exception("Fresh overview must rearm");
            window.autoSession=true;window.observedOverview=false;window.phase=Phase.Playing;window.UpdateAutomatic();
            if(window.autoHold) throw new Exception("Normal return to overview blocked the next exhibit");
            window.FinishStop();window.UpdateAutomatic();
            if(window.autoHold) throw new Exception("Overview remained blocked after stop confirmation");
            window.autoSession=true;window.activeArtifact=4;window.contextAt=DateTime.UtcNow.AddSeconds(-2);window.UpdateAutomatic();
            if(!window.autoHold) throw new Exception("Stale status retained automatic playback");
            window.FinishStop();
            string warmed=Path.GetTempFileName();
            try {
                window.settings.Videos[4]=warmed;window.contextAt=DateTime.UtcNow;window.museumState=0x23;
                window.museumArtifact=4;window.phase=Phase.Warming;window.activeArtifact=4;
                window.opened=true;window.firstFrameAt=DateTime.UtcNow.AddSeconds(-1);window.autoHold=false;window.pending=false;
                window.UpdateAutomatic();
                if(window.phase!=Phase.Preparing||!window.autoSession) throw new Exception("Ready first frame waited for main transition");
                window.autoSession=false;window.phase=Phase.Warming;File.Delete(warmed);window.UpdateAutomatic();
                if(window.failedArtifact!=4) throw new Exception("Moved warm video was authorized");
                var prepared=VideoWindow.CreateMedia();prepared.UnloadedBehavior=MediaState.Manual;
                prepared.Source=new Uri(warmed);window.emergencyCache=prepared;
                window.emergencyCachePath=warmed;window.emergencyReadyAt=DateTime.UtcNow.AddSeconds(-1);
                window.emergencyCacheHost.Children.Add(prepared);
                if(!window.EmergencyPrepared) throw new Exception("Prepared emergency cache not ready");
                var taken=window.TakeEmergencyCache();
                if(!ReferenceEquals(prepared,taken)||taken.Source.LocalPath!=warmed||window.emergencyCacheHost.Children.Count!=0||
                   taken.UnloadedBehavior!=MediaState.Manual||window.EmergencyPrepared) throw new Exception("Emergency handoff reopened/closed media or retained parent");
                taken.Close();
            } finally { if(File.Exists(warmed)) File.Delete(warmed); }
        } finally { window.Close();app.Shutdown(); }
    }
    internal static int CacheMediaTest(string path,string report)
    {
        var app=new Application();var window=new ControllerWindow { Opacity=0,ShowInTaskbar=false,ShowActivated=false };
        var watch=System.Diagnostics.Stopwatch.StartNew();var frame=new DispatcherFrame();
        var poll=new DispatcherTimer { Interval=TimeSpan.FromMilliseconds(25) };
        MediaElement prepared=null;bool transferred=false,passed=false;int opens=0;double readyMs=0;
        try {
            window.Show();window.settings=new VideoSettings();window.settings.Videos[5]=Path.GetFullPath(path);
            window.linked=true;window.flags=1;window.contextAvailable=true;window.contextAt=DateTime.UtcNow;
            window.museumState=1;window.automatic.IsChecked=true;window.PrepareEmergencyCache();
            prepared=window.emergencyCache;if(prepared==null) return 1;
            prepared.MediaOpened+=(s,e)=>opens++;
            prepared.MediaEnded+=(s,e)=> { passed=transferred&&opens==1&&prepared.NaturalVideoWidth==1280&&prepared.NaturalVideoHeight==720;frame.Continue=false; };
            prepared.MediaFailed+=(s,e)=>frame.Continue=false;
            poll.Tick+=(s,e)=> {
                if(watch.Elapsed.TotalSeconds>10) { frame.Continue=false;return; }
                if(!transferred&&window.EmergencyPrepared) {
                    readyMs=watch.Elapsed.TotalMilliseconds;prepared=window.TakeEmergencyCache();
                    var host=new Grid { Width=1,Height=1,Opacity=0 };((Grid)window.Content).Children.Add(host);
                    host.Children.Add(prepared);transferred=true;prepared.Play();
                }
            };
            poll.Start();Dispatcher.PushFrame(frame);
            if(report!=null) new XDocument(new XElement("emergencyCacheTest",new XAttribute("passed",passed),
                new XAttribute("ready_ms",readyMs),new XAttribute("media_open_count",opens),new XAttribute("reparented",transferred))).Save(report);
            return passed ? 0 : 1;
        } finally { poll.Stop();if(prepared!=null) prepared.Close();window.Close();app.Shutdown(); }
    }
    internal ControllerWindow()
    {
        Title = "博物馆副屏 · 本地视频播放"; Width = 940; Height = 790; MinWidth = 860; MinHeight = 650;
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
        var layout = new StackPanel { Margin = new Thickness(26) };
        var design = new Grid { Width=940,Height=750 };
        design.Children.Add(new ScrollViewer { Content=layout,VerticalScrollBarVisibility=ScrollBarVisibility.Auto,HorizontalScrollBarVisibility=ScrollBarVisibility.Disabled });
        root.Children.Add(new Viewbox { Child=design,Stretch=Stretch.Uniform });
        root.Children.Add(emergencyCacheHost);
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
        actions.Children.Add(play); actions.Children.Add(pause); actions.Children.Add(MakeButton("停止并回本地", () => { if(AutoEnabled) automatic.IsChecked=false;autoHold=true; StopVideo("已停止并释放首帧缓存；重新勾选联动可继续。"); }));
        actions.Children.Add(MakeButton("使用说明", () => MessageBox.Show(
            "1. 电脑HDMI→副板HDMIA；副板HDMIB→屏幕。\n2. 电脑USB→副板USB-UART Type-C，不是USB-JTAG。\n"+
            "3. Windows扩展AnlogicHDMI：1280×720、60/59.94Hz、RGB8、SDR。\n4. 手动有声播放选择HDMI音频输出，48kHz/24-bit双声道PCM。\n"+
            "5. 点击“文物与应急视频配置”，选择五件文物及一支应急视频，再勾选联动。文件可放任意目录，路径自动保存。\n"+
            "文物视频静音循环，暂停随主板。主板SW4进入应急后，普通视频被撤销，改为静音循环应急指引。\n"+
            "联动开启后后台准备应急首帧；下方显示“应急首帧：已缓存”后切入可复用缓存。停止或关闭联动会释放缓存。\n"+
            "应急解除立即撤销应急视频，不恢复旧文物视频。视频缺失、解码失败、信源或通信失效时保留板载应急图。\n"+
            "关闭联动仍使用原本地应急图。重连后若主板仍应急，重新申请应急授权；普通视频不会自行复播。\n"+
            "启动不自动开启联动；电脑和本程序必须持续运行。旧bit不支持应急视频，需烧新副板bit。\n"+
            "软件使用Windows媒体组件，建议MP4(H.264/AAC)。演示地图不是实际场馆消防设施，请遵循现场标识与工作人员指引。", "使用说明")));
        panel.Children.Add(actions);
        panel.Children.Add(MakeButton("文物与应急视频配置", ConfigureVideos));
        panel.Children.Add(automatic);
        automatic.Checked += (s,e) => { autoHold=false;failedArtifact=-1; if (video!=null) StopVideo("先退出手动视频，再按主板状态联动。"); else SetStatus("联动已开启；等待主板实际展示状态。"); };
        automatic.Unchecked += (s,e) => { observedEmergency=false;ClearEmergencyCache();emergencyFailedPath=null;if (autoSession||phase==Phase.Warming) StopVideo("联动已关闭，释放缓存并恢复本地显示。"); else { if(linked&&warmSupported&&(flags&16)!=0) Send(7);SetStatus("手动模式。"); } };
        var statePanel = new StackPanel();
        statePanel.Children.Add(new TextBlock { Text = "02  播放与连接状态", FontWeight = FontWeights.SemiBold, FontSize = 16, Margin = new Thickness(0,0,0,10) });
        status.MinHeight = 46; status.LineHeight = 24; statePanel.Children.Add(status);
        statePanel.Children.Add(mainStatus);
        var stateCard = Card(statePanel); stateCard.Margin = new Thickness(0,16,0,0); layout.Children.Add(stateCard);
        Refresh(); SetStatus("先连接副板串口；未点击播放时，HDMI 常连接仍保持本地展示。");
        try { settings=VideoSettings.Load(VideoSettings.PathName); Refresh(); }
        catch (Exception error) { if (!(error is IOException || error is UnauthorizedAccessException || error is XmlException)) throw;settingsValid=false; SetStatus("配置读取失败，原文件保留，请重新配置视频："+error.Message); }
        mainStatus.Text="主板状态：尚未连接；联动需要新版副板bit。";
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
    void SetStatus(string text) { status.Text = text; play.IsEnabled = linked && phase == Phase.Idle && !AutoEnabled; pause.IsEnabled = !autoSession && (phase == Phase.Playing || phase == Phase.Paused); }
    void ConfigureVideos()
    {
        if (phase != Phase.Idle && phase != Phase.Warming) { SetStatus("请先停止视频，再修改联动配置。"); return; }
        configuring=true;
        try {
            var dialog = new Window { Title="文物与应急视频配置", Owner=this, Icon=Icon, Width=900, Height=510,
                WindowStartupLocation=WindowStartupLocation.CenterOwner, FontFamily=FontFamily, FontSize=14, Background=Brushes.FloralWhite, Resources=Resources };
            var body=new StackPanel { Margin=new Thickness(22) };
            var design=new Grid { Width=900,Height=470 };design.Children.Add(body);
            dialog.Content=new Viewbox { Child=design,Stretch=Stretch.Uniform };
            body.Children.Add(new TextBlock { Text="五件文物及应急视频可放任意位置；应急缺片时保留板载逃生图。", Margin=new Thickness(0,0,0,14) });
            string[] paths=(string[])settings.Videos.Clone();
            for(int i=0;i<6;i++) {
                int id=i; var box=new TextBox { Text=paths[id] ?? "", IsReadOnly=true };
                body.Children.Add(Row(id+"  "+VideoSettings.Names[id],box,MakeButton("选择视频",()=> {
                    var pick=new OpenFileDialog { Filter="视频文件|*.mp4;*.wmv;*.avi;*.mkv;*.mov|全部文件|*.*" };
                    if(pick.ShowDialog(dialog)==true) { paths[id]=pick.FileName;box.Text=pick.FileName; }
                })));
            }
            body.Children.Add(MakeButton("保存配置",()=> {
                var updated=new VideoSettings { Videos=paths,Port=ports.SelectedItem as string ?? settings.Port };
                try { updated.Save(VideoSettings.PathName);settings=updated;settingsValid=true;failedArtifact=-1;autoHold=false;ClearEmergencyCache();emergencyFailedPath=null;if(phase==Phase.Warming) StopVideo("配置更新，重新准备首帧。");dialog.Close();SetStatus("视频配置已保存，移动文件后需重新选择。"); }
                catch(IOException error) { MessageBox.Show(dialog,"保存失败："+error.Message); }
                catch(UnauthorizedAccessException error) { MessageBox.Show(dialog,"保存失败："+error.Message); }
            }));
            dialog.ShowDialog();
        } finally { configuring=false; }
    }
    void Refresh()
    {
        if (phase != Phase.Idle && phase != Phase.Warming) return;
        failedArtifact=-1;
        ClearEmergencyCache();emergencyFailedPath=null;
        string selected = ports.SelectedItem as string ?? settings.Port;
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
        if (phase != Phase.Idle) { if(phase==Phase.Warming) automatic.IsChecked=false;StopVideo("先停止视频，再重新连接。"); return; }
        StopVideo("重新连接"); Disconnect();
        string name = ports.SelectedItem as string;
        if (name == null) { SetStatus("请选择副板 CH340 对应的 COM 口。"); return; }
        try {
            settings.Port=name;
            try { if(settingsValid) settings.Save(VideoSettings.PathName); } catch(IOException) { } catch(UnauthorizedAccessException) { }
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
                    byte capturedSeq=seq,capturedFlags=value,artifact=decoder.Artifact,state=decoder.State,scene=decoder.Scene;
                    bool context=decoder.HasContext;
                    Dispatcher.BeginInvoke(new Action(() => Acknowledge(current,capturedSeq,capturedFlags,context,artifact,state,scene)));
                }
            }
        } catch (InvalidOperationException) { } catch (IOException) { } catch (TimeoutException) { }
    }
    void Acknowledge(SerialPort current, byte seq, byte value, bool context, byte artifact, byte state, byte scene)
    {
        if (!ReferenceEquals(current,port) || !pending || seq != pendingSeq) return;
        byte acknowledgedCommand = pendingCommand;
        pending = false; flags = value; linked = true; replyAt = DateTime.UtcNow;
        if(!AutoEnabled&&warmSupported&&(flags&16)!=0&&acknowledgedCommand!=7) { Send(7);return; }
        if(acknowledgedCommand>=0x20&&acknowledgedCommand<=0x24&&(flags&128)!=0) {
            warmSupported=false;flags=(byte)(flags&127);SetStatus("当前bit不支持返回缓存保持，请更新副板bit；首帧准备仍可使用。");return;
        }
        if (acknowledgedCommand==5) {
            contextKnown=true;contextAvailable=context;
            if(!context) { flags=(byte)(flags&127);mainStatus.Text="旧版副板bit：可手动播放，不能联动。";if(AutoEnabled) automatic.IsChecked=false;return; }
            museumArtifact=artifact;museumState=state;museumScene=scene;contextAt=DateTime.UtcNow;
            mainStatus.Text="主板："+((state&8)!=0 ? "应急" : (state&1)==0 ? "失联/未就绪" : (state&64)!=0 ? "启动/故障/恢复" : (state&2)==0 ? "总览" : (state&4)!=0 ? "暂停" : "展示")+
                "  |  文物 "+(artifact<5 ? artifact.ToString() : "--")+"  |  "+((state&16)!=0 ? "手动浏览" : "自动讲解")+
                (AutoEnabled ? "  |  应急首帧："+(EmergencyPrepared ? "已缓存" : activeArtifact==5 ? "使用中" : emergencyCache!=null ? "准备中" : emergencyFailedPath!=null&&emergencyFailedPath==settings.Videos[5] ? "准备失败" : "未缓存") : "");
        }
        if ((flags & 128) != 0) { if(autoSession) { autoHold=true;failedArtifact=activeArtifact; } StopVideo("副板拒绝授权：请检查信源和主板状态，重新开启联动可重试。"); return; }
        if (phase == Phase.Stopping && (acknowledgedCommand == 2 || acknowledgedCommand == 3 || acknowledgedCommand == 5 || acknowledgedCommand == 7) && (flags & 14) == 0) stopConfirmed = true;
        if (phase == Phase.Idle && !AutoEnabled) SetStatus("已连接；HDMI输入" + ((flags & 1) != 0 ? "有效" : "未就绪") + "，当前保持副板本地内容。");
        else if (phase == Phase.Authorizing || phase == Phase.Playing || phase == Phase.Paused)
            if ((flags & 9) != 9 || autoSession&&activeArtifact==5&&(flags&32)==0) { if(autoSession) autoHold=true;StopVideo("HDMI信源失效或授权已撤销，已退回本地。请重新开启联动或从总览重新进入。"); }
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
        ClearEmergencyCache();
        contextKnown=false;contextAvailable=false;nextContext=true;warmSupported=true;warmHintSent=false;observedOverview=false;observedEmergency=false;
        if(autoSession) autoHold=true;
        var current = port; port = null;
        if (current != null) current.Dispose();
    }
    void StartVideo()
    { PrepareVideo(false); }
    void ClearEmergencyCache()
    {
        var previous=emergencyCache;emergencyCache=null;emergencyCachePath=null;emergencyReadyAt=DateTime.MaxValue;
        emergencyCacheHost.Children.Clear();
        if(previous!=null) { previous.Stop();previous.Close(); }
    }
    MediaElement TakeEmergencyCache()
    {
        var prepared=emergencyCache;emergencyCache=null;emergencyCachePath=null;emergencyReadyAt=DateTime.MaxValue;
        emergencyCacheHost.Children.Remove(prepared);return prepared;
    }
    void PrepareEmergencyCache()
    {
        if(!AutoEnabled||configuring||closeAfterStop||!linked||!ContextFresh||(flags&1)==0||activeArtifact==5) return;
        string path=settings.Videos[5];
        if(emergencyCache!=null) {
            if(emergencyCachePath!=path||!File.Exists(path)) ClearEmergencyCache();
            else { if((DateTime.UtcNow-emergencyCacheAt).TotalSeconds>10&&emergencyReadyAt==DateTime.MaxValue) {
                       emergencyFailedPath=path;ClearEmergencyCache();SetStatus("应急首帧准备超时；保留板载应急图。"); }
                   return; }
        }
        if(emergencyFailedPath==path||!File.Exists(path)) return;
        try {
            var prepared=VideoWindow.CreateMedia();prepared.UnloadedBehavior=MediaState.Manual;
            emergencyCache=prepared;emergencyCachePath=path;emergencyCacheAt=DateTime.UtcNow;
            emergencyCacheHost.Children.Add(prepared);
            prepared.MediaOpened+=(s,e)=> {
                if(!ReferenceEquals(emergencyCache,prepared)) return;
                if(!prepared.HasVideo) { emergencyFailedPath=path;ClearEmergencyCache();return; }
                prepared.Pause();prepared.Position=TimeSpan.Zero;emergencyReadyAt=DateTime.UtcNow.AddMilliseconds(120);
            };
            prepared.MediaFailed+=(s,e)=> { if(ReferenceEquals(emergencyCache,prepared)) {
                emergencyFailedPath=path;ClearEmergencyCache();SetStatus("应急视频无法预解码；保留板载应急图。"); } };
            prepared.Source=new Uri(path,UriKind.Absolute);prepared.Play();
        } catch(Exception error) { emergencyFailedPath=path;ClearEmergencyCache();SetStatus("应急首帧准备失败："+error.Message); }
    }
    bool ActivatePreparedEmergency()
    {
        if(!linked||(flags&1)==0||!EmergencyPrepared||failedArtifact==5||activeArtifact==5||!File.Exists(settings.Videos[5])) return false;
        var target=screens.SelectedItem as ScreenChoice;
        if(target==null||target.Name.IndexOf("Anlogic",StringComparison.OrdinalIgnoreCase)<0||target.Screen.Primary||
           target.Screen.Bounds.Width!=1280||target.Screen.Bounds.Height!=720) return false;
        MediaElement prepared=TakeEmergencyCache();VideoWindow next=null;
        try {
            next=new VideoWindow(target.Screen,prepared);
            var previous=video;video=next;activeArtifact=5;autoSession=true;autoHold=false;
            opened=true;warmHintSent=false;phase=Phase.Preparing;releaseAt=DateTime.MaxValue;fileCheckedAt=DateTime.UtcNow;
            prepareAt=DateTime.UtcNow;firstFrameAt=prepareAt.AddMilliseconds(34);
            AttachVideoEvents(next);file.Text=settings.Videos[5];prepared.Play();
            // Discard an old STOP/query ACK. Give the reparented surface two
            // display frames before CMD06; do not reopen/decode the file.
            if(previous!=null) { previous.Media.Stop();previous.Media.Close();previous.Close(); }
            pending=false;
            SetStatus("接管已缓存的应急首帧，即将申请应急显示授权。");return true;
        } catch(Exception error) {
            if(next==null) prepared.Close();failedArtifact=5;StopVideo("应急切入失败："+error.Message);return false;
        }
    }
    void PrepareVideo(bool warm)
    {
        var target = screens.SelectedItem as ScreenChoice;
        if (!linked || phase != Phase.Idle || AutoEnabled && !autoSession && !warm) return;
        if (target == null || target.Name.IndexOf("Anlogic",StringComparison.OrdinalIgnoreCase) < 0 || target.Screen.Primary || target.Screen.Bounds.Width != 1280 || target.Screen.Bounds.Height != 720) { SetStatus("请选择1280×720的AnlogicHDMI扩展屏，不要选择电脑主屏或独立DP显示器。"); return; }
        if (!File.Exists(file.Text)) { SetStatus("请先选择存在的本地视频文件。"); return; }
        try {
            phase = warm ? Phase.Warming : Phase.Preparing; opened = false;warmHintSent=false;releaseAt = DateTime.MaxValue; prepareAt = DateTime.UtcNow;
            video = new VideoWindow(target.Screen);
            AttachVideoEvents(video);
            video.Media.Source = new Uri(file.Text, UriKind.Absolute); video.Media.Play();
            SetStatus("准备静音首帧；副板仍保持本地，待视频就绪后授权显示。");
        } catch (Exception e) { if(AutoEnabled) failedArtifact=activeArtifact;StopVideo("无法播放：" + e.Message); }
    }
    void AttachVideoEvents(VideoWindow currentVideo)
    {
            video.Media.MediaOpened += (s,e) => {
                if (!ReferenceEquals(video,currentVideo) || phase != Phase.Preparing && phase != Phase.Warming) return;
                if (!currentVideo.Media.HasVideo) { if(AutoEnabled) failedArtifact=activeArtifact;StopVideo("所选文件不包含可解码的视频画面。"); return; }
                currentVideo.Media.Pause(); currentVideo.Media.Position = TimeSpan.Zero;
                opened = true; firstFrameAt = DateTime.UtcNow.AddMilliseconds(120);
                if(phase==Phase.Warming) SetStatus("文物"+activeArtifact+"首帧已准备；确认进入后直接申请显示，不主动展示电脑画面。");
            };
            video.Media.MediaEnded += (s,e) => {
                if(!ReferenceEquals(video,currentVideo)) return;
                if(autoSession&&AutoEnabled&&ContextFresh&&!autoHold&&Protocol.LinkedArtifact(museumState,museumArtifact)==activeArtifact) {
                    currentVideo.Media.Position=TimeSpan.Zero;
                    if(activeArtifact==5||(museumState&4)==0) currentVideo.Media.Play();else currentVideo.Media.Pause();
                } else StopVideo("视频结束，副板恢复本地内容。");
            };
            video.Media.MediaFailed += (s,e) => { if (ReferenceEquals(video,currentVideo)) { if(AutoEnabled) failedArtifact=activeArtifact; StopVideo("视频解码失败：" + e.ErrorException.Message); } };
            video.Closing += (s,e) => { if (ReferenceEquals(video,currentVideo)) { e.Cancel = true; StopVideo("播放窗口关闭，副板恢复本地内容。"); } };
    }
    void PauseVideo()
    {
        if (video == null || autoSession) return;
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
        try { Send(warmSupported&&(flags&16)!=0 ? (byte)7 : (byte)2); } catch (InvalidOperationException) { } catch (IOException) { } catch (TimeoutException) { }
        SetStatus(message);
    }
    void FinishStop()
    {
        phase = Phase.Idle; var previous = video; video = null;
        autoSession=false;activeArtifact=-1;warmHintSent=false;
        if (previous != null) { previous.Media.Stop(); previous.Media.Close(); previous.Close(); }
        SetStatus(stopMessage ?? "已停止。");
        if (closeAfterStop && !closeNow) { closeNow = true; Close(); }
    }
    void UpdateAutomatic()
    {
        if(!AutoEnabled||configuring||closeAfterStop) return;
        if(ContextFresh) {
            bool emergency=(museumState&0x49)==9;
            if(emergency&&!observedEmergency) { autoHold=false;failedArtifact=-1; }
            if(!emergency&&observedEmergency) autoHold=true;
            observedEmergency=emergency;
            if((museumState&64)!=0) autoHold=true;
        }
        bool overview=ContextFresh&&(museumState&0x6b)==1&&museumScene==255;
        if(overview&&!observedOverview) { autoHold=false;failedArtifact=-1; }
        observedOverview=overview;
        int desired=ContextFresh ? Protocol.LinkedArtifact(museumState,museumArtifact) : -1;
        if(desired==5&&ActivatePreparedEmergency()) return;
        if(autoSession&&video!=null&&activeArtifact>=0&&(DateTime.UtcNow-fileCheckedAt).TotalMilliseconds>=500) {
            fileCheckedAt=DateTime.UtcNow;
            if(!File.Exists(settings.Videos[activeArtifact])) { failedArtifact=activeArtifact;StopVideo("联动视频已移动或不可访问，请重新配置；回到本地显示。");return; }
        }
        if(desired<0) {
            if(autoSession) { autoHold=!overview;StopVideo("主板应急、恢复、失联或已退出，回到副板本地。"); }
            else if(ContextFresh&&(museumState&0x6b)==1&&museumArtifact<5&&!autoHold) {
                if(phase==Phase.Warming&&activeArtifact!=museumArtifact) { StopVideo("总览高亮变化，准备下一件首帧。");return; }
                if(phase==Phase.Idle&&!pending&&linked&&failedArtifact!=museumArtifact&&(flags&1)!=0) {
                    string warmPath=settings.Videos[museumArtifact];
                    if(File.Exists(warmPath)) { file.Text=warmPath;activeArtifact=museumArtifact;fileCheckedAt=DateTime.UtcNow;PrepareVideo(true); }
                }
            } else if(phase==Phase.Warming) { autoHold=true;StopVideo("暂停首帧准备，回到本地。"); }
            return;
        }
        if(phase==Phase.Warming) {
            if(activeArtifact!=desired) { StopVideo("文物变化，重新准备视频。");return; }
            if(!File.Exists(settings.Videos[activeArtifact])) { failedArtifact=activeArtifact;StopVideo("已准备的视频被移动，请重新配置。");return; }
            if(opened&&DateTime.UtcNow>=firstFrameAt&&!pending) { autoSession=true;phase=Phase.Preparing;prepareAt=DateTime.UtcNow; }
            return;
        }
        if(autoSession&&desired!=activeArtifact) { StopVideo("实际展示文物变化，先撤销上一视频。");return; }
        if(video!=null && (phase==Phase.Playing||phase==Phase.Paused) && autoSession) {
            bool paused=activeArtifact!=5&&(museumState&4)!=0;
            if(paused && phase==Phase.Playing) { video.Media.Pause();phase=Phase.Paused;SetStatus("联动视频随主板暂停。"); }
            if(!paused && phase==Phase.Paused) { video.Media.Play();phase=Phase.Playing;SetStatus("联动视频随主板继续，静音循环。"); }
        }
        if(phase!=Phase.Idle||pending||!linked||autoHold||failedArtifact==desired||(flags&1)==0) return;
        if(desired==5&&emergencyCache!=null) { SetStatus("正在准备应急首帧，板载应急图保持显示。");return; }
        if(desired==5&&emergencyFailedPath==settings.Videos[5]) { failedArtifact=5;SetStatus("应急视频准备失败，保留板载应急图。");return; }
        string path=settings.Videos[desired];
        if(!File.Exists(path)) { failedArtifact=desired;SetStatus(VideoSettings.Names[desired]+"视频未配置或已移动，请重新选择；应急时保留板载逃生图。");return; }
        file.Text=path;autoSession=true;activeArtifact=desired;fileCheckedAt=DateTime.UtcNow;StartVideo();
        if(video==null) { failedArtifact=desired;autoSession=false;activeArtifact=-1; }
    }
    void Tick(object sender, EventArgs e)
    {
        DateTime now = DateTime.UtcNow;
        try {
            if (phase == Phase.Stopping && (stopConfirmed || now >= stopDeadline)) {
                if(AutoEnabled&&ContextFresh&&Protocol.LinkedArtifact(museumState,museumArtifact)==5&&EmergencyPrepared) UpdateAutomatic();
                if(phase==Phase.Stopping) { FinishStop();return; }
            }
            if (port == null || !port.IsOpen) return;
            if (pending && (now - sentAt).TotalMilliseconds > 250) {
                if (attempts++ >= 3) { StopVideo("串口应答超时；请确认COM口和新副板bit。硬件最长约3秒回退。"); Disconnect(); return; }
                port.Write(Protocol.Request(pendingCommand,pendingSeq),0,5); sentAt = now;
            }
            PrepareEmergencyCache();UpdateAutomatic();
            if(phase==Phase.Warming) {
                if((flags&1)==0) { autoHold=true;StopVideo("HDMI信源失效，取消首帧准备。"); }
                else if((now-prepareAt).TotalSeconds>10&&!opened) { failedArtifact=activeArtifact;StopVideo("首帧准备超时，请检查视频文件。"); }
                else if(opened&&now>=firstFrameAt&&!pending&&!warmHintSent&&warmSupported) { Send((byte)(0x20+activeArtifact));warmHintSent=true; }
            }
            if(contextAvailable && (museumState&8)!=0 && video!=null&&activeArtifact!=5) StopVideo("主板应急，先撤销普通视频，再准备应急指引。");
            if (phase == Phase.Preparing) {
                if ((now - prepareAt).TotalSeconds > 10) { if(autoSession) failedArtifact=activeArtifact;StopVideo("视频或HDMI准备超时，请检查输入格式和视频编解码。"); return; }
                if (opened && now >= firstFrameAt && (flags & 1) != 0 && !pending) {
                    phase = Phase.Authorizing; Send(autoSession ? activeArtifact==5 ? (byte)6 : (byte)(0x10+activeArtifact) : (byte)1); SetStatus("切入HDMI视频，等待输出和显示器稳定。");
                }
            }
            if (phase == Phase.Authorizing && (flags & 15) == 11) {
                if (releaseAt == DateTime.MaxValue) releaseAt = now.AddMilliseconds(autoSession ? activeArtifact==5 ? 0 : 100 : 700);
                if (now >= releaseAt) {
                    video.Media.IsMuted=autoSession;
                    if(autoSession&&activeArtifact!=5&&(museumState&4)!=0) { video.Media.Pause();phase=Phase.Paused; } else { video.Media.Play();phase=Phase.Playing; }
                    SetStatus(autoSession ? activeArtifact==5 ? "应急疏散指引：静音循环，解除应急立即返回本地。" : "联动展示：文物"+activeArtifact+"，静音循环，暂停随主板。" : "正在播放；视频和声音均走HDMI，停止后回到本地内容。");
                }
            }
            if (!pending && (now - replyAt).TotalMilliseconds >= 50) {
                if(!contextKnown || contextAvailable&&nextContext) { Send(5);nextContext=false; }
                else { Send(AutoEnabled||phase==Phase.Playing||phase==Phase.Paused||phase==Phase.Authorizing ? (byte)4 : (byte)3);nextContext=true; }
            }
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
            try { Protocol.SelfTest(); ControllerWindow.SelfTest();return 0; } catch { return 1; }
        }
        if (args.Length == 2 && args[0] == "--media-test") return MediaTest(args[1]);
        if ((args.Length==2||args.Length==3)&&args[0]=="--cache-test") return ControllerWindow.CacheMediaTest(args[1],args.Length==3 ? args[2] : null);
        if ((args.Length == 2 || args.Length == 4) && args[0] == "--ui-test") {
            int width=args.Length==4 ? int.Parse(args[2]) : 940,height=args.Length==4 ? int.Parse(args[3]) : 750;
            var testApp = new Application(); var window = new ControllerWindow();
            var panel = (FrameworkElement)window.Content;
            panel.Measure(new Size(width,height)); panel.Arrange(new Rect(0,0,width,height)); panel.UpdateLayout();
            var drawing = new DrawingVisual();
            using (var context = drawing.RenderOpen()) {
                context.DrawRectangle(new VisualBrush(panel),null,new Rect(0,0,width,height));
            }
            var bitmap = new System.Windows.Media.Imaging.RenderTargetBitmap(width,height,96,96,PixelFormats.Pbgra32);
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
