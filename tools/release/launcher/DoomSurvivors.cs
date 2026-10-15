// Doom Survivors launcher: starts the bundled UZDoom engine with the game's IWAD and the
// settings the game expects (fullscreen by default; change it in the options). Built by tools/release/make_release.py (C# compiler that
// ships with the .NET Framework on Windows). Keeps the player's config and saves in
// "userdata" next to the exe, so the game folder is fully portable.
// Extra command-line arguments are passed through to the engine (e.g. +map MAP16).
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows.Forms;

static class DoomSurvivorsLauncher
{
    static readonly string[] GameArgs = {
        "-noautoload",
        // the engine's extra support files would put UZDoom's logo over the game's title page
        "-noextras",
        // DirectInput controller scanning can stall startup for ~20 s on some PCs;
        // XInput (Xbox-style) controllers still work without it.
        "+joy_dinput", "false",
        "+screenblocks", "11",
        "+con_notifytime", "0",
        "+chase_dist", "120", "+chase_height", "30", "+lookspring", "0",
        "+set", "ds_p030_mode", "manual",
        "+set", "ds_p030_speed", "1",
        "+set", "ds_p030_telemetry", "0",
        "+set", "ds_p030_input_trace", "0",
        "+set", "ds_p030_duration_tics", "63000",
        "+set", "ds_shell_autoopen", "1",
    };

    static string Quote(string s) { return "\"" + s.Replace("\"", "\\\"") + "\""; }

    [STAThread]
    static int Main(string[] args)
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string engine = Path.Combine(dir, "engine", "uzdoom.exe");
        string iwad = Path.Combine(dir, "doom-survivors.ipk3");
        if (!File.Exists(engine) || !File.Exists(iwad))
        {
            MessageBox.Show("Missing engine\\uzdoom.exe or doom-survivors.ipk3 next to DoomSurvivors.exe.\n" +
                            "Extract the whole zip before playing.", "Doom Survivors",
                            MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
        string user = Path.Combine(dir, "userdata");
        Directory.CreateDirectory(user);
        string config = Path.Combine(user, "config.ini");   // created by the engine on first exit

        var cmd = new StringBuilder();
        cmd.Append("-iwad ").Append(Quote(iwad))
           .Append(" -config ").Append(Quote(config))
           .Append(" -savedir ").Append(Quote(user));
        foreach (string a in GameArgs) cmd.Append(' ').Append(a.StartsWith("+") || a.StartsWith("-") ? a : Quote(a));
        foreach (string a in args) cmd.Append(' ').Append(Quote(a));

        var start = new ProcessStartInfo(engine, cmd.ToString());
        start.WorkingDirectory = user;
        start.UseShellExecute = false;
        Process.Start(start);
        return 0;
    }
}
