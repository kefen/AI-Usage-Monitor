using System;
using System.IO;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Collections.Generic;
using System.Web.Script.Serialization;

internal static class SetupSupport {
    internal static bool Owned(string root){
        try{var data=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(Path.Combine(root,"installation.json")));return Convert.ToString(data["id"])=="local-codex-sidebar-meter";}catch{return false;}
    }
    internal static string LockName(string root,string kind){using(var sha=SHA256.Create())return "Local\\CodexMeter-"+kind+"-"+BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(Path.GetFullPath(root).ToUpperInvariant()))).Replace("-","");}
    internal static bool IsRunning(string root){
        foreach(string kind in new[]{"tray","monitor"})using(var mutex=new Mutex(false,LockName(root,kind))){bool taken=false;try{try{taken=mutex.WaitOne(0);}catch(AbandonedMutexException){taken=true;}if(!taken)return true;}finally{if(taken)mutex.ReleaseMutex();}}
        return false;
    }
    internal static void StopOwned(string root){
        ValidateDestination(root);if(!Owned(root))throw new IOException(Locale.T("Installation not recognized. Exit the old meter from the tray."));
        string runtime=Path.Combine(root,".runtime");RejectLinks(runtime);Directory.CreateDirectory(runtime);
        string request=Path.Combine(runtime,"background-stop.request");RejectLinks(request);File.WriteAllText(request,"stop");
        for(int i=0;i<100;i++){if(!IsRunning(root))return;Thread.Sleep(150);}
        throw new IOException(Locale.T("The old meter has not stopped. Exit it from the tray and check again. Leave Codex open."));
    }
    static void RejectLinks(string path){for(string p=path;!String.IsNullOrEmpty(p);p=Path.GetDirectoryName(p))if((Directory.Exists(p)||File.Exists(p))&&(File.GetAttributes(p)&FileAttributes.ReparsePoint)!=0)throw new IOException(Locale.T("Symbolic links and junctions are not supported. Choose a normal folder."));}
    internal static string ValidateDestination(string input){
        if(String.IsNullOrWhiteSpace(input)||input.Length<3||!Char.IsLetter(input[0])||input[1]!=':'||(input[2]!='\\'&&input[2]!='/')||input.IndexOf('"')>=0)throw new IOException(Locale.T("Choose a full path on a local disk."));
        string path=Path.GetFullPath(input).TrimEnd('\\');
        if(path.Length<4||path.Length>160||path.IndexOf(':',2)>=0)throw new IOException(Locale.T("Choose a dedicated folder with a path under 160 characters."));
        foreach(string part in path.Substring(3).Split('\\'))if(part.EndsWith(".")||part.EndsWith(" "))throw new IOException(Locale.T("Folder names cannot end with spaces or dots."));
        string windows=Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        if(path.Equals(windows,StringComparison.OrdinalIgnoreCase)||path.StartsWith(windows+"\\",StringComparison.OrdinalIgnoreCase)||path.IndexOf("\\WindowsApps",StringComparison.OrdinalIgnoreCase)>=0)throw new IOException(Locale.T("Do not install into Windows or Codex WindowsApps."));
        RejectLinks(path);
        if(File.Exists(path))throw new IOException(Locale.T("This path is a file. Choose a folder."));
        if(Directory.Exists(path)&&Directory.GetFileSystemEntries(path).Length>0&&!Owned(path))throw new IOException(Locale.T("This folder contains other files. Choose an empty folder or the existing meter installation."));
        RejectLinks(Path.Combine(path,"installation.json"));RejectLinks(Path.Combine(path,".runtime"));
        var drive=new DriveInfo(Path.GetPathRoot(path));if(!drive.IsReady||drive.DriveType==DriveType.Network)throw new IOException(Locale.T("Choose a connected local disk."));
        if(drive.AvailableFreeSpace<400L*1024*1024)throw new IOException(Locale.T("Less than 400 MB available. Choose another disk."));
        string parent=path;while(!Directory.Exists(parent))parent=Path.GetDirectoryName(parent);
        string probe=Path.Combine(parent,".cqs-write-"+Guid.NewGuid().ToString("N"));
        try{using(var file=new FileStream(probe,FileMode.CreateNew,FileAccess.Write,FileShare.None)){} }finally{if(File.Exists(probe))File.Delete(probe);}
        return path;
    }
    internal static string FindCodex(){
        string ps=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"WindowsPowerShell\\v1.0\\powershell.exe");
        var start=new ProcessStartInfo(ps,"-NoProfile -NonInteractive -Command \"$ErrorActionPreference='Stop'; $p=Get-AppxPackage -Name OpenAI.Codex; if($p){$p | Select-Object -First 1 -ExpandProperty InstallLocation}\""){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true};
        start.EnvironmentVariables.Remove("PSModulePath");
        using(var process=Process.Start(start)){var output=process.StandardOutput.ReadToEndAsync();var error=process.StandardError.ReadToEndAsync();if(!process.WaitForExit(20000)){process.Kill();throw new IOException(Locale.T("Environment check timed out. Try again."));}if(process.ExitCode!=0)throw new IOException(Locale.T("Cannot inspect Codex. Run the installer as a normal user and retry."));return output.Result.Trim();}
    }
    internal static string DefaultDestination(){
        string legacy=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),"Documents\\Codex\\Apps\\CodexSidebarMeter");
        // Resolve an existing shortcut without executing its target.
        try{Type type=Type.GetTypeFromProgID("WScript.Shell");dynamic shell=Activator.CreateInstance(type);string link=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),"Codex Quota Sidebar.lnk");if(File.Exists(link)){dynamic shortcut=shell.CreateShortcut(link);string root=Path.GetDirectoryName((string)shortcut.TargetPath);if(Owned(root))return root;}}catch{}
        return legacy;
    }
    internal static string FriendlyError(string message){
        if(message.Contains("Stop the existing meter"))return Locale.T("The old meter is running. Exit it and retry; leave Codex open.");
        if(message.Contains("modified")||message.Contains("installer-owned"))return Locale.T("Existing program files were modified. Keep the folder and contact the maintainer; files have not been overwritten.");
        if(message.Contains("shortcut"))return Locale.T("Shortcut points to another folder. Upgrade in the original folder, or back up settings and uninstall before moving.");
        if(message.Contains("denied")||message.Contains("\u62d2\u7edd"))return Locale.T("Folder is not writable. Choose a user-writable location; administrator mode is not required.");
        return message;
    }
}
