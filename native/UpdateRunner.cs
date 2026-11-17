using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;

internal sealed class UpdateResult {
    internal Dictionary<string,object> Data;
    internal string Code;
    internal bool Success {get{return Code==null;}}
}
internal static class UpdateRunner {
    internal static string Quote(string value){
        var result=new StringBuilder("\"");int slashes=0;
        foreach(char c in value){
            if(c=='\\'){slashes++;continue;}
            result.Append('\\',c=='\"'?slashes*2+1:slashes);result.Append(c);slashes=0;
        }
        result.Append('\\',slashes*2);return result.Append('"').ToString();
    }
    internal static string SafeCode(string value,string fallback){return System.Text.RegularExpressions.Regex.IsMatch(value??"",@"^E_[A-Z0-9_]{1,64}$")?value:fallback;}
    internal static UpdateResult Parse(string output,int exitCode){
        try{
            var data=new JavaScriptSerializer{MaxJsonLength=131072}.Deserialize<Dictionary<string,object>>(output.TrimStart('\uFEFF').Trim());
            object error;
            if(data==null)return Failure("E_UPDATE_JSON");
            if(data.TryGetValue("error",out error)||exitCode!=0){object code;data.TryGetValue("code",out code);return Failure(SafeCode(Convert.ToString(code??error),"E_UPDATE_PROCESS"));}
            object available,current,version;
            if(!data.TryGetValue("available",out available)||!(available is bool)||!data.TryGetValue("current",out current)||!(current is string)||String.IsNullOrWhiteSpace((string)current)||!data.TryGetValue("version",out version)||!(version is string)||String.IsNullOrWhiteSpace((string)version))return Failure("E_UPDATE_CONTRACT");
            return new UpdateResult{Data=data};
        }catch{return Failure("E_UPDATE_JSON");}
    }
    static UpdateResult Failure(string code){return new UpdateResult{Code=code};}
    internal static UpdateResult Execute(ProcessStartInfo info,int timeout){
        info.UseShellExecute=false;info.CreateNoWindow=true;info.RedirectStandardOutput=info.RedirectStandardError=true;
        info.StandardOutputEncoding=info.StandardErrorEncoding=new UTF8Encoding(false);
        try{
            using(var process=new Process{StartInfo=info}){
                var stdout=new StringBuilder();var stderr=new StringBuilder();bool overflow=false;object gate=new object();
                process.OutputDataReceived+=(s,e)=>{if(e.Data==null)return;lock(gate){if(stdout.Length+e.Data.Length>131072)overflow=true;else stdout.AppendLine(e.Data);}};
                process.ErrorDataReceived+=(s,e)=>{if(e.Data==null)return;lock(gate){if(stderr.Length+e.Data.Length>4096)overflow=true;else stderr.AppendLine(e.Data);}};
                process.Start();process.BeginOutputReadLine();process.BeginErrorReadLine();
                if(!process.WaitForExit(timeout)){try{process.Kill();process.WaitForExit();}catch{}return Failure("E_UPDATE_TIMEOUT");}
                process.WaitForExit();
                lock(gate)return overflow?Failure("E_UPDATE_OUTPUT_LIMIT"):Parse(stdout.ToString(),process.ExitCode);
            }
        }catch{return Failure("E_UPDATE_LAUNCH");}
    }
    internal static string AppRoot(string start){
        var directory=new DirectoryInfo(Path.GetFullPath(start));
        for(int i=0;directory!=null&&i<4;i++,directory=directory.Parent)if(File.Exists(Path.Combine(directory.FullName,"src","update.mjs"))&&File.Exists(Path.Combine(directory.FullName,"runtime","node.exe")))return directory.FullName;
        throw new DirectoryNotFoundException("E_UPDATE_ROOT");
    }
    internal static UpdateResult Run(string start,string operation){
        try{
            string root=AppRoot(start);
            var info=new ProcessStartInfo(Path.Combine(root,"runtime","node.exe"),Quote(Path.Combine(root,"src","update.mjs"))+" "+Quote(operation)+" "+Quote(root)+" "+Quote(root)+" "+Process.GetCurrentProcess().Id){WorkingDirectory=root};
            var result=Execute(info,180000);
            if(!result.Success)try{string folder=Path.Combine(root,".runtime","updates");Directory.CreateDirectory(folder);File.WriteAllText(Path.Combine(folder,"native-diagnostic.json"),new JavaScriptSerializer().Serialize(new{code=result.Code,operation=operation,at=DateTime.UtcNow.ToString("o")}),new UTF8Encoding(false));}catch{}
            return result;
        }catch{return Failure("E_UPDATE_ROOT");}
    }
}
