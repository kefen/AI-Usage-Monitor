using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

internal static class Installer {
    static string Q(string s){return "\""+s.Replace("\"","\\\"")+"\"";}
    static void Extract(string root){
        root=Path.GetFullPath(root);
        if(Directory.Exists(root))throw new IOException("Extraction directory already exists.");
        Directory.CreateDirectory(root);
        using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip"))
        using(var zip=new ZipArchive(stream,ZipArchiveMode.Read))foreach(var entry in zip.Entries){
            string path=Path.GetFullPath(Path.Combine(root,entry.FullName));
            if(!path.StartsWith(root+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("Unsafe package path.");
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            if(entry.Name.Length==0)continue;
            using(var input=entry.Open())using(var output=File.Create(path))input.CopyTo(output);
        }
    }
    [STAThread] static int Main(string[] args){
        string temp=null;
        try {
            if(args.Length==2 && args[0]=="--extract"){Extract(args[1]);return 0;}
            if(args.Length!=0)throw new ArgumentException("Use --extract DIRECTORY or double-click to install.");
            Application.EnableVisualStyles();
            // Windows 0.12.0-beta.1
            string destination=SetupSupport.DefaultDestination();
            SetupWindow window=null;
            using(window=new SetupWindow(destination,()=>{
            destination=window.Destination;
            if(temp==null){temp=Path.Combine(Path.GetTempPath(),"CodexMeter-install-"+Guid.NewGuid().ToString("N"));Extract(temp);}
            string ps=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"WindowsPowerShell\\v1.0\\powershell.exe");
            var start=new ProcessStartInfo(ps,"-NoProfile -ExecutionPolicy Bypass -File "+Q(Path.Combine(temp,"Install.ps1"))+" -Destination "+Q(destination)){UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden,RedirectStandardOutput=true,RedirectStandardError=true};
            start.EnvironmentVariables.Remove("PSModulePath");
            using(var p=Process.Start(start)){
                var output=p.StandardOutput.ReadToEndAsync();var error=p.StandardError.ReadToEndAsync();p.WaitForExit();
                if(p.ExitCode!=0)throw new IOException(error.Result+"\n"+output.Result);
            }
            DisplayOptions.Save(Path.Combine(destination,".runtime"),window.SelectedVisibility);
            Locale.Save(Path.Combine(destination,".runtime"));
            },()=>Process.Start(new ProcessStartInfo(Path.Combine(destination,"CodexMeter.exe")){UseShellExecute=true}),null,()=>MeterPreferences.Edit(Path.Combine(destination,".runtime"))))window.ShowDialog();return 0;
        }catch(Exception e){MeterTheme.Error(e.Message);return 1;}
        finally{if(temp!=null && Directory.Exists(temp) && Path.GetFullPath(temp).StartsWith(Path.Combine(Path.GetTempPath(),"CodexMeter-install-"),StringComparison.OrdinalIgnoreCase))Directory.Delete(temp,true);}
    }
}
