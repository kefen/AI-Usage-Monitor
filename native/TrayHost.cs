using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.ComponentModel;
using System.Drawing;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

internal static class TrayHost {
    static readonly string Root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar);
    static readonly string Runtime = Path.Combine(Root, ".runtime");
    static readonly string StopPath = Path.Combine(Runtime, "background-stop.request");
    static readonly string OpenPath = Path.Combine(Runtime, "background-open.request");
    static readonly string Title = "Codex Quota Sidebar";
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
    static readonly string Ps = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell\\v1.0\\powershell.exe");
    static Process child;
    static NotifyIcon tray;
    static LaunchWindow window;
    static DateTime mountedAt=DateTime.MinValue;
    static DateTime monitorStarted=DateTime.MaxValue;
    static bool autoHidden;
    static System.Windows.Forms.Timer timer;
    static string nonce, stage="starting";
    static bool preparing=true, stopping;
    static bool reconnecting,opening;
    static DateTime reconnectAt;
    static void Reconnect(){
        if(stopping||reconnecting)return;
        window.Feedback(Locale.T("Reconnecting; Codex will not be closed automatically."));
        if(child==null){Prepare();return;}
        reconnecting=true;reconnectAt=DateTime.UtcNow;File.WriteAllText(StopPath,"reconnect");
        window.UpdateState("starting",new Dictionary<string,object>());
    }
    static DateTime lastReport=DateTime.MinValue;
    static StreamWriter output, errors;
    static string Q(string s) { return "\"" + s.Replace("\"", "\\\"") + "\""; }
    static string LockName(string kind) {
        using(var sha=SHA256.Create()) return "Local\\CodexMeter-"+kind+"-"+BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(Path.GetFullPath(Root).ToUpperInvariant()))).Replace("-", "");
    }
    static bool Acquire(Mutex m) {try{return m.WaitOne(0);}catch(AbandonedMutexException){return true;}}
    static Dictionary<string,object> Read(string name) {
        return Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(Path.Combine(Runtime,name),Encoding.UTF8));
    }
    static void Report() {
        using(var self=Process.GetCurrentProcess()) {
            var data=new Dictionary<string,object>{{"version","0.12.6"},{"stage",stage},{"pid",self.Id},{"monitorPid",child==null?0:child.Id},{"host","native"},{"workingSetBytes",self.WorkingSet64},{"cpuSeconds",self.TotalProcessorTime.TotalSeconds},{"updatedAt",DateTime.UtcNow.ToString("o")}};
            if(!preparing && child!=null && !child.HasExited){child.Refresh();data["nodeWorkingSetBytes"]=child.WorkingSet64;data["nodeCpuSeconds"]=child.TotalProcessorTime.TotalSeconds;}
            File.WriteAllText(Path.Combine(Runtime,"background.json"),Json.Serialize(data),Encoding.UTF8);
        }
        lastReport=DateTime.UtcNow;
    }
    static Process Launch(string file,string args) {
        var p=new Process();
        p.StartInfo=new ProcessStartInfo(file,args){UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden,WorkingDirectory=Root,RedirectStandardOutput=true,RedirectStandardError=true};
        if(String.Equals(file,Ps,StringComparison.OrdinalIgnoreCase))p.StartInfo.EnvironmentVariables.Remove("PSModulePath");
        p.OutputDataReceived+=(s,e)=>{if(e.Data!=null)lock(output){output.WriteLine(e.Data);output.Flush();}};
        p.ErrorDataReceived+=(s,e)=>{if(e.Data!=null)lock(errors){errors.WriteLine(e.Data);errors.Flush();}};
        p.Start();p.BeginOutputReadLine();p.BeginErrorReadLine();return p;
    }
    static void Stop() {stopping=true;File.WriteAllText(StopPath,"stop");tray.Text=Title+" - stopping";window.Feedback(Locale.T("Stopping the meter; Codex stays open."));}
    static void Prepare() {
        if(child!=null || stopping)return;
        try {
            if(File.Exists(StopPath))File.Delete(StopPath);
            preparing=true;stage="starting";mountedAt=DateTime.MinValue;autoHidden=false;
            window.UpdateState(stage,new Dictionary<string,object>());window.Present();
            nonce=Guid.NewGuid().ToString("N");
            child=Launch(Ps,"-NoProfile -STA -ExecutionPolicy Bypass -File "+Q(Path.Combine(Root,"Start.ps1"))+" -PrepareOnly -LaunchToken "+nonce);
            Report();
        } catch(Exception e){Fail(e);}
    }
    static void Fail(Exception error) {
        stage="failed";
        if(errors!=null){lock(errors){errors.WriteLine(error.Message);errors.Flush();}}
        window.UpdateState(stage,new Dictionary<string,object>{{"code",error.Message}});window.Present();Report();
    }
    static void OpenCodex() {
        if(preparing || stopping || opening){window.Feedback(Locale.T("Connection is busy. Please wait."));return;}
        try {
            var state=Read("status.json");int port=Convert.ToInt32(state["port"]);
            if(port<1024 || port>65535)throw new InvalidDataException("Invalid port; reconnect first.");
            var start=new ProcessStartInfo(Ps,"-NoProfile -STA -ExecutionPolicy Bypass -File "+Q(Path.Combine(Root,"vendor\\codex-quota\\codex-cdp.ps1"))+" -Action focus -Port "+port){UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden,WorkingDirectory=Root};
            start.EnvironmentVariables.Remove("PSModulePath");opening=true;window.Feedback(Locale.T("Opening Codex..."));
            var worker=new BackgroundWorker();worker.DoWork+=(s,e)=>{using(var p=Process.Start(start)){if(!p.WaitForExit(15000)){p.Kill();throw new TimeoutException("Codex activation timed out.");}if(p.ExitCode!=0)throw new InvalidOperationException("Codex activation failed; reconnect or inspect diagnostics.");}};
            worker.RunWorkerCompleted+=(s,e)=>{if(window.IsDisposed){worker.Dispose();return;}try{window.BeginInvoke((Action)(()=>{opening=false;if(!window.IsDisposed)window.Feedback(e.Error==null?Locale.T("Codex activation requested."):e.Error.Message);worker.Dispose();}));}catch(InvalidOperationException){worker.Dispose();}};worker.RunWorkerAsync();
        } catch(Exception ex) {opening=false;window.Feedback(ex.Message);}
    }
    static void Tick(object sender,EventArgs args) {
        try {
            if(File.Exists(StopPath)&&!reconnecting)stopping=true;
            if(reconnecting && child!=null && !child.HasExited){
                if((DateTime.UtcNow-reconnectAt).TotalSeconds>45)window.Feedback(Locale.T("Still waiting for the old monitor. Codex stays open."));
                return;
            }
            if(stopping && child==null){stage="stopped";Application.ExitThread();return;}
            if(child!=null && child.HasExited) {
                child.WaitForExit();int code=child.ExitCode;child.Dispose();child=null;
                if(reconnecting){reconnecting=false;Prepare();return;}
                if(stopping || (!preparing && code==0)){stage="stopped";Application.ExitThread();return;}
                if(!preparing){Fail(new InvalidOperationException("Monitor exited ("+code+"). Retry or run Diagnose.cmd."));return;}
                if(code!=0){string failure="E_STARTUP";try{var failed=Read("status.json");if(Convert.ToString(failed["stage"])=="startup-failed")failure=Convert.ToString(failed["code"]);}catch{}throw new InvalidOperationException(LaunchWindow.StartupFailure(failure));}
                Dictionary<string,object> cfg;
                try{cfg=Read("launch.json");}catch{throw new InvalidOperationException("Preparation cancelled. Retry when ready.");}
                if(!cfg.ContainsKey("nonce") || Convert.ToString(cfg["nonce"])!=nonce)throw new InvalidOperationException("Preparation cancelled. Retry when ready.");
                string node=Convert.ToString(cfg["node"]), cli=Convert.ToString(cfg["cli"]);
                int port=Convert.ToInt32(cfg["port"]);
                if(port<1024 || port>65535 || !Path.IsPathRooted(node) || !Path.IsPathRooted(cli) || !File.Exists(node) || !File.Exists(cli))throw new InvalidDataException("Invalid launch configuration.");
                monitorStarted=DateTime.UtcNow;
                child=Launch(node,Q(Path.Combine(Root,"src\\cli.mjs"))+" attach --port "+port+" --codex "+Q(cli)+" --stop-file "+Q(StopPath));
                preparing=false;stage="running";Report();
            }
            if(File.Exists(OpenPath)){File.Delete(OpenPath);autoHidden=true;window.Present();}
            string reconnectRequest=Path.Combine(Runtime,"reconnect.request");
            if(File.Exists(reconnectRequest)){File.Delete(reconnectRequest);Reconnect();return;}
            string focusRequest=Path.Combine(Runtime,"focus.request");
            if(File.Exists(focusRequest)){File.Delete(focusRequest);OpenCodex();}
            string settings=Path.Combine(Runtime,"settings.request");
            if(File.Exists(settings)){File.Delete(settings);window.ShowPage("Codex subscription record");window.Present();}
            if(!preparing && child!=null && !stopping){
                Dictionary<string,object> state=null;try{state=Read("status.json");}catch{}
                DateTime updated;
                if(state!=null && state.ContainsKey("stage") && state.ContainsKey("updatedAt") && DateTime.TryParse(Convert.ToString(state["updatedAt"]),out updated) && updated.ToUniversalTime()>=monitorStarted && (DateTime.UtcNow-updated.ToUniversalTime()).TotalSeconds<40){
                    string view=Convert.ToString(state["stage"]);window.UpdateState(view,state);
                    if(view.StartsWith("mounted",StringComparison.Ordinal)){
                        if(mountedAt==DateTime.MinValue)mountedAt=DateTime.UtcNow;
                        if(!autoHidden&&(DateTime.UtcNow-mountedAt).TotalSeconds>=3){window.Hide();autoHidden=true;}
                    }
                }
            }
            if((DateTime.UtcNow-lastReport).TotalSeconds>=30)Report();
        } catch(Exception e) {Fail(e);}
    }
    [STAThread] static int Main(string[] args) {
        Directory.CreateDirectory(Runtime);
        Locale.Load(Runtime);
        if(args.Length>0 && args[0]=="--stop"){File.WriteAllText(StopPath,"stop");return 0;}
        using(var trayLock=new Mutex(false,LockName("tray")))using(var monitorLock=new Mutex(false,LockName("monitor"))) {
            bool haveTray=Acquire(trayLock), haveMonitor=false;
            if(!haveTray){string request=args.Length>0&&args[0]=="--settings"?"settings.request":args.Length>0&&args[0]=="--reconnect"?"reconnect.request":args.Length>0&&args[0]=="--open-codex"?"focus.request":"background-open.request";File.WriteAllText(Path.Combine(Runtime,request),"open");return 0;}
            try {
                haveMonitor=Acquire(monitorLock);
                if(!haveMonitor){MeterTheme.Error(Locale.T("Stop the old monitor before opening this version."));return 0;}
                if(File.Exists(StopPath))File.Delete(StopPath);if(File.Exists(OpenPath))File.Delete(OpenPath);
                Application.EnableVisualStyles();
                if(args.Length>0&&args[0]=="--settings"){MeterPreferences.Edit(Runtime);return 0;}
                if(!MeterPreferences.EnsureReady(Runtime))return 0;
                output=new StreamWriter(Path.Combine(Runtime,"background.stdout.log"),false,Encoding.UTF8);
                errors=new StreamWriter(Path.Combine(Runtime,"background.stderr.log"),false,Encoding.UTF8);
                window=new LaunchWindow(OpenCodex,Reconnect,()=>MeterPreferences.Edit(Runtime),Stop);
                tray=new NotifyIcon{Icon=MeterTheme.TrayIcon(),Text=Title,Visible=true};
                var menu=new ContextMenuStrip();
                menu.Items.Add(Locale.T("Open Codex"),null,(s,e)=>OpenCodex());
                menu.Items.Add(Locale.T("Settings"),null,(s,e)=>{window.ShowPage("Codex subscription record");window.Present();});
                menu.Items.Add(Locale.T("Refresh data"),null,(s,e)=>File.WriteAllText(Path.Combine(Runtime,"refresh.request"),"refresh"));
                menu.Items.Add(Locale.T("View status"),null,(s,e)=>window.Present());
                menu.Items.Add(Locale.T("Exit software"),null,(s,e)=>Stop());
                tray.ContextMenuStrip=menu;tray.DoubleClick+=(s,e)=>window.Present();
                menu.Opening+=(s,e)=>{foreach(ToolStripItem item in menu.Items)item.Text=Locale.T(item.Text);};
                Prepare();
                Report();timer=new System.Windows.Forms.Timer{Interval=4000};timer.Tick+=Tick;timer.Start();
                Application.Run();return stage=="failed"?1:0;
            } catch(Exception e){stage="failed";MeterTheme.Error(e.Message);return 1;}
            finally {
                if(haveMonitor){
                    if(child!=null && !child.HasExited){File.WriteAllText(StopPath,"stop");child.WaitForExit(45000);}
                    if(timer!=null)timer.Dispose();if(window!=null)window.Finish();if(tray!=null){tray.Visible=false;tray.Icon.Dispose();tray.Dispose();}
                    if(stage!="failed")stage="stopped";Report();
                    if(output!=null)output.Dispose();if(errors!=null)errors.Dispose();
                    monitorLock.ReleaseMutex();
                }
                trayLock.ReleaseMutex();
            }
        }
    }
}
