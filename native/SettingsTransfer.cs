using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

internal static class SettingsTransfer {
    static Dictionary<string,object> Parse(string text){if(text.Length>65536)throw new IOException(Locale.T("Settings file is too large."));return new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(text);}
    static Dictionary<string,object> Read(string path){return File.Exists(path)?Parse(File.ReadAllText(path)):new Dictionary<string,object>();}
    static bool OneOf(string value,string set){return Array.IndexOf(set.Split(','),value)>=0;}
    static void Validate(Dictionary<string,object> data,bool display){
        if(data==null)throw new IOException(Locale.T("Invalid settings format."));
        foreach(var pair in data){
            string key=pair.Key;object value=pair.Value;
            if(display){if(Array.IndexOf(DisplayOptions.Keys,key)<0||!(value is bool))throw new IOException(Locale.T("Unsupported sidebar settings."));continue;}
            bool valid=false;
            if(OneOf(key,"enabled,monthlyEstimate,annualEstimate,estimated"))valid=value is bool;
            else if(key=="plan")valid=value is string&&OneOf((string)value,"plus,pro,business,enterprise,edu,free,go,other");
            else if(key=="tier")valid=value is string&&OneOf((string)value,",unknown,100,200,500,standard,premium");
            else if(key=="kind")valid=value is string&&OneOf((string)value,"renewal,expiry");
            else if(key=="date"||key=="purchaseDate"){DateTime date;valid=value is string&&DateTime.TryParseExact((string)value,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out date);}
            if(!valid)throw new IOException(Locale.T("Unsupported subscription fields or dates."));
        }
    }
    internal static string Backup(string root){
        var membership=Read(Path.Combine(root,"membership.json"));var display=Read(Path.Combine(root,"display.json"));Validate(membership,false);Validate(display,true);
        return new JavaScriptSerializer().Serialize(new Dictionary<string,object>{{"format","codex-quota-sidebar-settings-v1"},{"membership",membership},{"display",display}});
    }
    internal static void Restore(string root,string text){
        var data=Parse(text);if(data==null||data.Count!=3||!data.ContainsKey("format")||Convert.ToString(data["format"])!="codex-quota-sidebar-settings-v1"||!data.ContainsKey("membership")||!data.ContainsKey("display"))throw new IOException(Locale.T("Unsupported settings backup."));
        var member=data["membership"] as Dictionary<string,object>;var display=data["display"] as Dictionary<string,object>;Validate(member,false);Validate(display,true);
        Directory.CreateDirectory(root);string m=Path.Combine(root,"membership.json"),d=Path.Combine(root,"display.json");
        foreach(string path in new[]{root,m,d})if((File.Exists(path)||Directory.Exists(path))&&(File.GetAttributes(path)&FileAttributes.ReparsePoint)!=0)throw new IOException(Locale.T("Cannot restore settings through symbolic links."));
        var priorMember=File.Exists(m)?Read(m):null;var priorDisplay=File.Exists(d)?Read(d):null;
        try{MeterPreferences.Save(m,member);MeterPreferences.Save(d,display);}
        catch{if(priorMember!=null)MeterPreferences.Save(m,priorMember);else if(File.Exists(m))File.Delete(m);if(priorDisplay!=null)MeterPreferences.Save(d,priorDisplay);else if(File.Exists(d))File.Delete(d);throw;}
    }
    internal static void Export(string root){using(var dialog=new SaveFileDialog{Title=Locale.T("Backup saved settings (no login information)"),Filter="JSON (*.json)|*.json",FileName="Codex-Quota-Sidebar-settings.json"})if(dialog.ShowDialog()==DialogResult.OK)try{File.WriteAllText(dialog.FileName,Backup(root),new UTF8Encoding(false));MessageBox.Show(Locale.T("Backup saved. It contains your manual subscription dates; keep it private."));}catch(Exception ex){MeterTheme.Error(ex.Message);}}
    internal static bool Import(string root){
        using(var dialog=new OpenFileDialog{Title=Locale.T("Restore settings"),Filter="JSON (*.json)|*.json"})if(dialog.ShowDialog()==DialogResult.OK){
            if(MessageBox.Show(Locale.T("Replace subscription and sidebar settings? Unsaved edits will be lost. Login and connection consent stay unchanged."),Locale.T("Restore settings"),MessageBoxButtons.OKCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)!=DialogResult.OK)return false;
            try{if(new FileInfo(dialog.FileName).Length>65536)throw new IOException(Locale.T("Settings file is too large."));Restore(root,File.ReadAllText(dialog.FileName));return true;}catch(Exception ex){MeterTheme.Error(ex.Message);}
        }return false;
    }
}
