using System;
using System.IO;
using System.Threading;
internal static class SetupSupportTest {
    static void Assert(bool ok,string reason){if(!ok)throw new Exception(reason);}
    static void Reject(string path){bool rejected=false;try{SetupSupport.ValidateDestination(path);}catch{rejected=true;}Assert(rejected,"Accepted unsafe destination: "+path);}
    static int Main(string[] args){
        string root=Path.GetFullPath(args[0]);Directory.CreateDirectory(root);
        Reject("relative");Reject("C:relative");Reject("\\relative");Reject(Path.GetPathRoot(root));Reject(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"Sidebar"));
        Reject(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"WindowsApps","Sidebar"));
        string foreign=Path.Combine(root,"foreign");Directory.CreateDirectory(foreign);File.WriteAllText(Path.Combine(foreign,"keep.txt"),"keep");Reject(foreign);
        string app=Path.Combine(root,"custom folder",Guid.NewGuid().ToString("N").Substring(0,6));Assert(SetupSupport.ValidateDestination(app)==app,"Custom directory changed");Assert(!Directory.Exists(app),"Validation left an install directory");
        Directory.CreateDirectory(app);File.WriteAllText(Path.Combine(app,"installation.json"),"{\"id\":\"local-codex-sidebar-meter\"}");
        Assert(SetupSupport.Owned(app),"Owned installation missed");
        using(var mutex=new Mutex(false,SetupSupport.LockName(app,"monitor"))){
            var ready=new ManualResetEvent(false);var done=new ManualResetEvent(false);
            var thread=new Thread(()=>{mutex.WaitOne();ready.Set();done.WaitOne();mutex.ReleaseMutex();});thread.Start();ready.WaitOne();
            Assert(SetupSupport.IsRunning(app),"Running monitor missed");done.Set();thread.Join();
        }
        Assert(!SetupSupport.IsRunning(app),"Released monitor still running");
        using(var mutex=new Mutex(false,SetupSupport.LockName(app,"monitor"))){
            var ready=new ManualResetEvent(false);bool requested=false;
            var thread=new Thread(()=>{mutex.WaitOne();ready.Set();var end=DateTime.UtcNow.AddSeconds(5);while(DateTime.UtcNow<end){if(File.Exists(Path.Combine(app,".runtime","background-stop.request"))){requested=true;break;}Thread.Sleep(20);}mutex.ReleaseMutex();});
            thread.Start();ready.WaitOne();SetupSupport.StopOwned(app);thread.Join();Assert(requested,"Graceful shutdown request missing");
        }
        Assert(SetupSupport.FriendlyError("Stop the existing meter before upgrading").Contains("Codex"),"Missing recovery instruction");
        Console.WriteLine("PASS: custom directory, protected paths, foreign directory, ownership and running monitor");return 0;
    }
}
