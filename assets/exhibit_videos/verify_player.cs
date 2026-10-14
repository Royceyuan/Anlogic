// Compile beside the existing VideoPlayer.cs; exercise its actual WPF surface
// and control methods offscreen, without serial commands or display takeover.
using System;
using System.IO;
using System.Reflection;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using Forms = System.Windows.Forms;

static class VideoPlaybackCheck
{
    static FieldInfo Field(string name) { return typeof(ControllerWindow).GetField(name, BindingFlags.NonPublic | BindingFlags.Instance); }
    static void Set(ControllerWindow controller, string name, object value) { Field(name).SetValue(controller, value); }
    static object Get(ControllerWindow controller, string name) { return Field(name).GetValue(controller); }
    static void Call(ControllerWindow controller, string name) { typeof(ControllerWindow).GetMethod(name, BindingFlags.NonPublic | BindingFlags.Instance).Invoke(controller, null); }

    [STAThread] static int Main(string[] files)
    {
        Console.OutputEncoding = new System.Text.UTF8Encoding(false);
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        try {
            Protocol.SelfTest();
            if (files.Length != 5) throw new Exception("Supply all five formal films");
            for (int id = 0; id < files.Length; id++) Check(files[id], id);
            Console.WriteLine("PASS: five real-media control/loop sequences; no hardware I/O");
            return 0;
        } catch (Exception error) { Console.Error.WriteLine(error); return 1; }
        finally { app.Shutdown(); }
    }

    static void Check(string file, int id)
    {
        var controller = new ControllerWindow();
        ((DispatcherTimer)Get(controller, "timer")).Stop();
        ((VideoSettings)Get(controller, "settings")).Videos[id] = Path.GetFullPath(file);
        ((CheckBox)Get(controller, "automatic")).IsChecked = true;
        var surface = new VideoWindow(Forms.Screen.PrimaryScreen, true);
        Set(controller, "video", surface);
        Set(controller, "phase", Enum.Parse(Field("phase").FieldType, "Preparing"));
        typeof(ControllerWindow).GetMethod("AttachVideoEvents", BindingFlags.NonPublic | BindingFlags.Instance).Invoke(controller, new object[] { surface });
        var media = surface.Media;
        int ends = 0, step = 0;
        TimeSpan paused = TimeSpan.Zero;
        bool pauseSettled = false;
        var frame = new DispatcherFrame();
        Exception failure = null;
        var total = System.Diagnostics.Stopwatch.StartNew();
        var stage = System.Diagnostics.Stopwatch.StartNew();
        var poll = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(25) };
        media.MediaEnded += (s, e) => ends++;
        media.MediaFailed += (s, e) => { failure = e.ErrorException; frame.Continue = false; };
        poll.Tick += (s, e) => {
            try {
                if (total.Elapsed.TotalSeconds > 12) throw new Exception("Playback check timed out at step " + step);
                Set(controller, "contextAt", DateTime.UtcNow);
                if (step == 0 && (bool)Get(controller, "opened") && total.Elapsed.TotalMilliseconds > 300) {
                    if (media.NaturalVideoWidth != 1280 || media.NaturalVideoHeight != 720 || !media.HasAudio)
                        throw new Exception("Wrong decoded media format");
                    media.Play(); Set(controller, "phase", Enum.Parse(Field("phase").FieldType, "Playing"));
                    step++; stage.Restart();
                } else if (step == 1 && stage.Elapsed.TotalMilliseconds > 700) {
                    Call(controller, "PauseVideo"); paused = media.Position;
                    if (Get(controller, "phase").ToString() != "Paused") throw new Exception("Pause rejected");
                    step++; stage.Restart();
                } else if (step == 2 && !pauseSettled && stage.Elapsed.TotalMilliseconds > 200) {
                    paused = media.Position; pauseSettled = true;
                } else if (step == 2 && pauseSettled && stage.Elapsed.TotalMilliseconds > 600) {
                    if (Math.Abs((media.Position - paused).TotalSeconds) > .15) throw new Exception("Paused media advanced");
                    Call(controller, "PauseVideo"); step++; stage.Restart();
                } else if (step == 3 && stage.Elapsed.TotalMilliseconds > 700) {
                    if (media.Position <= paused + TimeSpan.FromMilliseconds(250)) throw new Exception("Resume did not advance");
                    Set(controller, "autoSession", true); Set(controller, "autoHold", false);
                    Set(controller, "activeArtifact", id); Set(controller, "museumArtifact", (byte)id);
                    Set(controller, "museumState", (byte)3); Set(controller, "contextAvailable", true);
                    Set(controller, "linked", true); Set(controller, "flags", (byte)1);
                    if (!media.NaturalDuration.HasTimeSpan) throw new Exception("Unknown media duration");
                    media.Position = media.NaturalDuration.TimeSpan-TimeSpan.FromSeconds(1.5); media.Play(); step++; stage.Restart();
                } else if (step == 4 && ends == 1 && media.Position.TotalSeconds > .25 && media.Position.TotalSeconds < 3) {
                    Set(controller, "museumState", (byte)9); Call(controller, "UpdateAutomatic");
                    if (Get(controller, "phase").ToString() != "Stopping" || !media.IsMuted)
                        throw new Exception("Emergency did not revoke ordinary media");
                    Call(controller, "FinishStop");
                    if (Get(controller, "video") != null || Get(controller, "phase").ToString() != "Idle")
                        throw new Exception("Stop did not release video surface");
                    Console.WriteLine("PASS file=" + Path.GetFileName(file) + " open/pause/resume/loop/emergency-revoke/stop; seconds=" + total.Elapsed.TotalSeconds.ToString("F2"));
                    step++; frame.Continue = false;
                }
            } catch (Exception error) { failure = error; frame.Continue = false; }
        };
        try {
            media.Source = new Uri(Path.GetFullPath(file)); media.Play();
            poll.Start(); Dispatcher.PushFrame(frame);
            if (failure != null) throw failure;
            if (step != 5) throw new Exception("Incomplete playback check");
        } finally { poll.Stop(); Call(controller, "FinishStop"); controller.Close(); }
    }
}
