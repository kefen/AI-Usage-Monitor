using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;
using System.Windows.Forms;

internal static class LocalDiagnostics {
    internal static string Snapshot(string root){
        var report=new Dictionary<string,object>{{"tool","Codex Quota Sidebar by KEFEN"},{"version","0.11.1-beta.1"},{"exportedAt",DateTime.UtcNow.ToString("o")},{"osVersion",Environment.OSVersion.Version.ToString()}};
        foreach(string file in new[]{"status.json","background.json"}){
            var safe=new Dictionary<string,object>();
            try{
                string path=Path.Combine(root,file);
                if(new FileInfo(path).Length>65536)continue;
                var data=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(path));
                foreach(string key in new[]{"stage","code","phase","updatedAt","elevated","quotaAvailable","usageAvailable"}){
                    object value;if(!data.TryGetValue(key,out value))continue;
                    string text=Convert.ToString(value);
                    // Export known scalar shapes only; never raw exception text or paths.
                    if(value is bool)safe[key]=value;
                    else if(key=="code"&&Regex.IsMatch(text,@"^E_[A-Z_]{1,60}$"))safe[key]=text;
                    else if(key=="updatedAt"){DateTime date;if(DateTime.TryParse(text,out date))safe[key]=date.ToUniversalTime().ToString("o");}
                    else if((key=="stage"||key=="phase")&&Regex.IsMatch(text,@"^[a-z-]{1,40}$"))safe[key]=text;
                }
            }catch{safe["readable"]=false;}
            report[file]=safe;
        }
        return new JavaScriptSerializer().Serialize(report);
    }
    internal static void Export(){
        using(var save=new SaveFileDialog{Title=Locale.T("Export sanitized diagnostics"),Filter="JSON (*.json)|*.json",FileName="Codex-Quota-Sidebar-diagnostics.json"}){
            if(save.ShowDialog()!=DialogResult.OK)return;
            try{File.WriteAllText(save.FileName,Snapshot(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,".runtime")),new UTF8Encoding(false));MessageBox.Show(Locale.T("Exported. No keys, chats, accounts or installation paths included."),"Codex Quota Sidebar");}
            catch(Exception ex){MeterTheme.Error(Locale.T("Export failed: ")+ex.Message);}
        }
    }
}
