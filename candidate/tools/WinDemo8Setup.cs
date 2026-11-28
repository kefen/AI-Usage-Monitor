using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

[assembly: AssemblyProduct("AI Usage Monitor")]
[assembly: AssemblyVersion("0.16.17.0")]
[assembly: AssemblyFileVersion("0.16.17.0")]
internal static class WinDemo8Setup
{
    private const string Version = "0.16.17";
    private const string Title = "AI Usage Monitor " + Version + " Setup";
    private const string AppName = "AI Usage Monitor";
    private const string LegacyMarkerValue = "AI Usage Monitor Demo.8 Test";
    private const string Executable = "AI Usage Monitor.exe";
    private const string Marker = "aum-demo8-test-install.txt";
    private const string SlotPrefix = ".files-";

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CreateDirectory(string path, IntPtr attributes);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool MoveFileEx(string source, string destination, int flags);

    [STAThread]
    private static int Main(string[] args)
    {
        bool test = (args.Length == 2 || args.Length == 3) && args[0] == "--test-install";
        bool appUpdate = args.Length == 1 && args[0] == "--app-update";
        if (!test && !appUpdate && args.Length != 0) return 2;
        try
        {
            string root = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string path = test ? Path.GetFullPath(args[1]) : Path.Combine(root, "Programs", AppName);
            bool upgrade = Directory.Exists(path);
            if (!test && !appUpdate && MessageBox.Show(
                "Install AI Usage Monitor " + Version + " for this user?\n\n" + path +
                "\n\nExit the old monitor before upgrading. Your settings and history will be kept." +
                (upgrade ? "\nThe current program files will be replaced." : ""),
                Title, MessageBoxButtons.OKCancel, MessageBoxIcon.Information) != DialogResult.OK)
                return 0;
            for (int attempt = 0; !test && MonitorIsRunning(root, path); attempt++)
            {
                if (appUpdate && attempt < 60) { System.Threading.Thread.Sleep(500); continue; }
                if (MessageBox.Show(
                    "A previous AI Usage Monitor is still running. Quit it from its tray menu, then click Retry. Codex can stay open.",
                    Title, MessageBoxButtons.RetryCancel, MessageBoxIcon.Warning) != DialogResult.Retry)
                    return 0;
            }
            string requested = path;
            if (!test) Directory.CreateDirectory(Path.GetDirectoryName(requested));
            string retainedBackup;
            path = Install(path, out retainedBackup);
            bool fallback = !String.Equals(path, requested, StringComparison.OrdinalIgnoreCase);
            string shortcut = "";
            if (!test || args.Length == 3)
            {
                try
                {
                    string programs = test ? Path.GetFullPath(args[2]) : Environment.GetFolderPath(Environment.SpecialFolder.Programs);
                    CreateStartShortcut(path, requested, programs, root);
                    RetirePreviewShortcuts(programs, root, requested);
                    if (!test) RetargetDesktopShortcut(path, requested, root);
                    shortcut = "\n\nStart menu: " + AppName;
                }
                catch (Exception error)
                {
                    if (test) throw;
                    shortcut = "\n\nCould not create the Start menu shortcut: " + error.Message +
                        "\nOpen the application from:\n" + path;
                }
            }
            if (fallback && !test)
                shortcut += "\n\nWindows prevented replacing the old app folder. The new app is installed at:\n" + path +
                    "\nThe old app files were kept at:\n" + (retainedBackup ?? requested);
            if (appUpdate || (!test && MessageBox.Show("Installation complete. Open AI Usage Monitor now?" + shortcut,
                Title, MessageBoxButtons.YesNo, MessageBoxIcon.Information) == DialogResult.Yes))
                Process.Start(new ProcessStartInfo(Path.Combine(path, Executable)) {
                    WorkingDirectory = path, UseShellExecute = true
                });
            return 0;
        }
        catch (Exception error)
        {
            if (test) Console.Error.WriteLine(error.Message);
            else MessageBox.Show(error.Message, Title, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    private static bool IsOwned(string path)
    {
        if (!Directory.Exists(path) || (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0) return false;
        string shell = Path.Combine(path, "resources", "app");
        string main = Path.Combine(shell, "desktop", "demo8", "main.mjs");
        string manifest = Path.Combine(shell, "package.json");
        foreach (string part in new[]{Path.Combine(path, "resources"), shell, Path.Combine(shell,"desktop"), Path.GetDirectoryName(main), main, manifest, Path.Combine(path, Executable)})
            if ((!Directory.Exists(part) && !File.Exists(part)) || (File.GetAttributes(part) & FileAttributes.ReparsePoint) != 0) return false;
        string identity = File.ReadAllText(manifest);
        if (!identity.Contains("\"ai-usage-monitor-demo8\"") && !identity.Contains("\"ai-usage-monitor\"")) return false;
        string marker = Path.Combine(path, Marker);
        if (File.Exists(marker) && (File.GetAttributes(marker) & FileAttributes.ReparsePoint) == 0 &&
            (File.ReadAllText(marker) == LegacyMarkerValue || File.ReadAllText(marker) == AppName)) return true;
        return File.ReadAllText(main).Contains("installedShell?'r13':''");
    }

    private static bool BelongsTo(string candidate, string requested)
    {
        if (String.Equals(candidate, requested, StringComparison.OrdinalIgnoreCase)) return true;
        string prefix = requested + SlotPrefix;
        Guid id;
        return candidate != null && candidate.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) &&
            Guid.TryParseExact(candidate.Substring(prefix.Length), "N", out id);
    }

    private static bool LegacyShortcut(string path)
    {
        string legacy = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
            "Codex", "Apps", "CodexSidebarMeter");
        string marker = Path.Combine(legacy, "installation.json");
        return String.Equals(path, Path.Combine(legacy, "CodexMeter.exe"), StringComparison.OrdinalIgnoreCase) &&
            File.Exists(marker) && File.ReadAllText(marker).Contains("\"local-codex-sidebar-meter\"");
    }

    private static void CreateStartShortcut(string installPath, string requested, string programsPath, string localRoot)
    {
        if (String.IsNullOrEmpty(programsPath)) throw new IOException("Cannot resolve the Start menu folder.");
        Directory.CreateDirectory(programsPath);
        string linkPath = Path.Combine(programsPath, AppName + ".lnk");
        dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell", true));
        dynamic link = shell.CreateShortcut(linkPath);
        string replacement = null;
        if (File.Exists(linkPath))
        {
            if ((File.GetAttributes(linkPath) & FileAttributes.ReparsePoint) != 0)
                throw new IOException("The shortcut is redirected.");
            string existing = (string)link.TargetPath;
            string old = String.IsNullOrEmpty(existing) ? null : Path.GetDirectoryName(existing);
            bool legacy = LegacyShortcut(existing);
            if (!legacy && (!String.Equals(Path.GetFileName(existing), Executable, StringComparison.OrdinalIgnoreCase) ||
                !(BelongsTo(old, requested) && (String.Equals(old, requested, StringComparison.OrdinalIgnoreCase) || IsOwned(old))
                  || IsPreviewInstall(old, localRoot))))
                throw new IOException("A shortcut with this name points to a different app.");
            // An old link may carry an AppUserModelID that WScript preserves on edit.
            if (legacy) {
                replacement = Path.Combine(programsPath, Guid.NewGuid().ToString("N") + ".lnk");
                link = shell.CreateShortcut(replacement);
            }
        }
        try {
            link.TargetPath = Path.Combine(installPath, Executable);
            link.WorkingDirectory = installPath;
            link.Description = AppName;
            link.Save();
            if (replacement != null) File.Replace(replacement, linkPath, null);
        }
        finally { if (replacement != null && File.Exists(replacement)) File.Delete(replacement); }
        if (!File.Exists(linkPath)) throw new IOException("The shortcut was not saved.");
    }

    private static bool IsPreviewInstall(string path, string localRoot)
    {
        return !String.IsNullOrEmpty(path) &&
            String.Equals(Path.GetDirectoryName(path), localRoot, StringComparison.OrdinalIgnoreCase) &&
            System.Text.RegularExpressions.Regex.IsMatch(Path.GetFileName(path), @"^AI Usage Monitor Demo\.8(?: r\d+| Test(?:\.files-[a-f0-9]{32})?)?$") &&
            IsOwned(path);
    }

    private static void RetargetDesktopShortcut(string installPath, string requested, string localRoot)
    {
        string desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        if (String.IsNullOrEmpty(desktop)) return;
        string file = Path.Combine(desktop, AppName + ".lnk");
        if (!File.Exists(file) || (File.GetAttributes(file) & FileAttributes.ReparsePoint) != 0) return;
        dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell", true));
        string target = shell.CreateShortcut(file).TargetPath;
        string folder = Path.GetDirectoryName(target);
        if (LegacyShortcut(target) || IsPreviewInstall(folder, localRoot) || BelongsTo(folder, requested) && IsOwned(folder))
            CreateStartShortcut(installPath, requested, desktop, localRoot);
    }

    private static bool MonitorIsRunning(string localRoot, string requested)
    {
        foreach (Process process in Process.GetProcessesByName(Path.GetFileNameWithoutExtension(Executable)))
        using (process)
        {
            string image = null;
            try { image = process.MainModule.FileName; }
            catch (Win32Exception) { }
            catch (InvalidOperationException) { }
            if (image == null) continue;
            string folder = Path.GetDirectoryName(image);
            if (BelongsTo(folder, requested) && IsOwned(folder) || IsPreviewInstall(folder, localRoot))
                return true;
        }
        return false;
    }

    private static void RetirePreviewShortcuts(string programsPath, string localRoot, string requested)
    {
        dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell", true));
        foreach (string file in Directory.GetFiles(programsPath, "AI Usage Monitor Demo.8*.lnk"))
        {
            if ((File.GetAttributes(file) & FileAttributes.ReparsePoint) != 0) continue;
            dynamic shortcut = shell.CreateShortcut(file);
            string target = shortcut.TargetPath;
            string folder = Path.GetDirectoryName(target);
            if (String.Equals(Path.GetFileName(target), Executable, StringComparison.OrdinalIgnoreCase) &&
                (IsPreviewInstall(folder, localRoot) || BelongsTo(folder, requested) && IsOwned(folder)))
                File.Delete(file);
        }
    }

    private static string Install(string destination, out string retainedBackup)
    {
        retainedBackup = null;
        bool upgrading = Directory.Exists(destination);
        if (upgrading && !IsOwned(destination)) throw new IOException("This folder is not a recognized Demo.8 test installation. Nothing was overwritten.");
        if (upgrading)
        {
            foreach (Process process in Process.GetProcessesByName(Path.GetFileNameWithoutExtension(Executable)))
            using (process)
            {
                string image = null;
                try { image = process.MainModule.FileName; }
                catch (Win32Exception) { }
                catch (InvalidOperationException) { }
                if (image != null && BelongsTo(Path.GetDirectoryName(image), destination))
                    throw new IOException("Exit the running test monitor and retry. Codex can stay open.");
            }
        }
        string stage = upgrading ? destination + SlotPrefix + Guid.NewGuid().ToString("N") : destination;
        if (!CreateDirectory(stage, IntPtr.Zero))
        {
            int code = Marshal.GetLastWin32Error();
            if (code == 183 || code == 80) throw new IOException("The installation folder already exists. Nothing was overwritten.");
            throw new IOException("Could not create the installation folder:\n" + destination +
                "\n\n" + new Win32Exception(code).Message + " (" + code + ")");
        }
        try
        {
            Extract(stage);
            File.WriteAllText(Path.Combine(stage, Marker), AppName);
            if (upgrading)
            {
                string backup = destination + ".backup-" + Guid.NewGuid().ToString("N");
                int oldMove = TryMoveDirectory(destination, backup);
                if (IsLocked(oldMove)) return stage;
                if (oldMove != 0) throw MoveError(oldMove);
                int promote = TryMoveDirectory(stage, destination);
                if (promote != 0)
                {
                    int rollback = TryMoveDirectory(backup, destination);
                    if (rollback != 0) retainedBackup = backup;
                    if (IsLocked(promote) || rollback != 0) return stage;
                    throw MoveError(promote);
                }
            }
            return destination;
        }
        catch (Exception error)
        {
            string cleanup = "";
            try { if (Directory.Exists(stage)) Directory.Delete(stage, true); }
            catch (IOException) { cleanup = "\n\nThe incomplete folder could not be removed."; }
            catch (UnauthorizedAccessException) { cleanup = "\n\nThe incomplete folder could not be removed."; }
            throw new IOException("Could not extract the application to:\n" + destination +
                "\n\n" + error.Message + cleanup, error);
        }
    }

    private static bool IsLocked(int code) { return code == 5 || code == 32 || code == 33; }
    private static IOException MoveError(int code) {
        return new IOException("Could not replace the test app folder (" + code + "): " + new Win32Exception(code).Message);
    }

    private static int TryMoveDirectory(string source, string target)
    {
        for (int i = 0; ; i++)
        {
            if (MoveFileEx(source, target, 0)) return 0;
            int code = Marshal.GetLastWin32Error();
            if (i >= 7 || !IsLocked(code)) return code;
            System.Threading.Thread.Sleep(180);
        }
    }

    private static void Extract(string destination)
    {
        using (Stream packed = Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.cab"))
        {
            if (packed == null)
            {
                using (Stream legacy = Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip"))
                    ExtractZip(destination, legacy);
                return;
            }
            string temp = Path.Combine(destination, ".unpack-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(temp);
            try
            {
                string cab = Path.Combine(temp, "payload.cab");
                using (var output = File.Create(cab)) packed.CopyTo(output);
                var info = new ProcessStartInfo(Path.Combine(Environment.SystemDirectory, "expand.exe"),
                    "\"" + cab + "\" \"" + Path.Combine(temp, "payload.zip") + "\"") { UseShellExecute=false, CreateNoWindow=true };
                using (var process = Process.Start(info))
                {
                    process.WaitForExit();
                    if (process.ExitCode != 0) throw new InvalidDataException("Package decompression failed.");
                }
                using (var raw = File.OpenRead(Path.Combine(temp, "payload.zip"))) ExtractZip(destination, raw);
            }
            finally { Directory.Delete(temp, true); }
        }
    }

    private static void ExtractZip(string destination, Stream data)
    {
        string prefix = destination + Path.DirectorySeparatorChar;
        using (var zip = new ZipArchive(data, ZipArchiveMode.Read))
        {
            foreach (ZipArchiveEntry entry in zip.Entries)
            {
                if (entry.FullName == "./") continue;
                string name = entry.FullName.Replace('/', Path.DirectorySeparatorChar);
                if (name.IndexOf(':') != -1) throw new InvalidDataException("Invalid archive entry.");
                string target = Path.GetFullPath(Path.Combine(destination, name));
                if (!target.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException("Archive entry is outside the installation folder.");
                if (entry.Name.Length == 0) Directory.CreateDirectory(target);
                else
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    entry.ExtractToFile(target);
                }
            }
        }
        if (!File.Exists(Path.Combine(destination, Executable)) ||
            !File.Exists(Path.Combine(destination, "resources", "app", "package.json")))
            throw new InvalidDataException("The application payload is incomplete.");
    }
}
