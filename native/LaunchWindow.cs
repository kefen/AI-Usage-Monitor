using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

internal sealed class LaunchWindow : Form {
    readonly Label headline,subtitle,connection,quota,usage,lastSync;
    readonly Button retry,open;
    bool exiting;
    DateTime feedbackUntil=DateTime.MinValue;
    string feedback="";
    internal void Feedback(string message){feedback=message;feedbackUntil=DateTime.UtcNow.AddSeconds(10);subtitle.Text=message;Present();}
    internal static string StartupFailure(string code){
        switch(code){
            case "E_CDP_NOT_LISTENING":return "\u672c\u673a\u8c03\u8bd5\u7aef\u53e3\u672a\u542f\u52a8\u3002\u8bf7\u786e\u8ba4 Codex \u80fd\u6b63\u5e38\u6253\u5f00\uff0c\u5e76\u4ee5\u666e\u901a\u6743\u9650\u542f\u52a8\u9762\u677f\u3002\nE_CDP_NOT_LISTENING";
            case "E_CDP_QUERY_FAILED":return "Windows \u65e0\u6cd5\u67e5\u8be2\u672c\u673a\u7aef\u53e3\uff0c\u4e0d\u80fd\u5224\u5b9a Codex \u672a\u542f\u52a8\u3002\u8bf7\u8fd0\u884c Diagnose.cmd\u3002\nE_CDP_QUERY_FAILED";
            case "E_NO_STORE_PACKAGE":return "\u672a\u627e\u5230\u5f53\u524d\u7528\u6237\u7684 Microsoft Store \u7248 Codex\u3002\nE_NO_STORE_PACKAGE";
            default:return "Codex preparation failed ("+code+"). Run Diagnose.cmd.";
        }
    }
    internal LaunchWindow(Action openCodex,Action reconnect,Action settings,Action stop){
        Text="Codex Quota Sidebar";MeterTheme.Style(this,660,480);
        var body=MeterTheme.Body();Controls.Add(body);Controls.Add(MeterTheme.Header("\u8fde\u63a5\u72b6\u6001","Windows 0.9.3-beta.1"));
        var grid=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=2,RowCount=6};grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,140));grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
        grid.RowStyles.Add(new RowStyle(SizeType.Absolute,46));grid.RowStyles.Add(new RowStyle(SizeType.Absolute,60));for(int i=2;i<6;i++)grid.RowStyles.Add(new RowStyle(SizeType.Absolute,38));body.Controls.Add(grid);
        headline=MeterTheme.Label("\u6b63\u5728\u8fde\u63a5",21,MeterTheme.Ink);headline.Name="statusHeadline";grid.Controls.Add(headline,0,0);grid.SetColumnSpan(headline,2);
        subtitle=MeterTheme.Label("\u7b49\u5f85\u5ba2\u6237\u7aef\u8fde\u63a5",10,MeterTheme.Muted);subtitle.Name="statusDetail";grid.Controls.Add(subtitle,0,1);grid.SetColumnSpan(subtitle,2);
        connection=Row(grid,2,"\u5ba2\u6237\u7aef");quota=Row(grid,3,"\u989d\u5ea6\u6570\u636e");usage=Row(grid,4,"Token \u6570\u636e");lastSync=Row(grid,5,"\u6700\u8fd1\u540c\u6b65");
        var footer=MeterTheme.Footer();Controls.Add(footer);body.BringToFront();
        open=MeterTheme.Button("openCodex","\u6253\u5f00 Codex",true);open.Enabled=false;open.Click+=(s,e)=>openCodex();
        retry=MeterTheme.Button("reconnect","\u91cd\u65b0\u8fde\u63a5",false);retry.Enabled=false;retry.Click+=(s,e)=>reconnect();
        var prefs=MeterTheme.Button("settings","\u8bbe\u7f6e",false);prefs.Click+=(s,e)=>settings();
        var end=MeterTheme.Button("stop","\u9000\u51fa\u8f6f\u4ef6",false);end.Click+=(s,e)=>stop();
        footer.Controls.Add(open);footer.Controls.Add(retry);footer.Controls.Add(prefs);footer.Controls.Add(end);
        FormClosing+=(s,e)=>{if(!exiting && e.CloseReason==CloseReason.UserClosing){e.Cancel=true;Hide();}};
    }
    static Label Row(TableLayoutPanel grid,int row,string key){grid.Controls.Add(MeterTheme.Label(key,10,MeterTheme.Muted),0,row);var value=MeterTheme.Label("--",10,MeterTheme.Ink);value.Name="statusRow"+row;grid.Controls.Add(value,1,row);return value;}
    internal void Present(){Show();WindowState=FormWindowState.Normal;Activate();}
    internal void UpdateState(string stage,Dictionary<string,object> data){
        bool mounted=stage.StartsWith("mounted",StringComparison.Ordinal),failed=stage=="failed"||stage=="startup-failed"||stage=="attach-failed"||stage=="restart-cancelled";
        headline.Text=mounted?"\u5df2\u8fde\u63a5":failed?"\u8fde\u63a5\u672a\u5b8c\u6210":"\u6b63\u5728\u8fde\u63a5";
        headline.ForeColor=mounted?MeterTheme.Green:failed?MeterTheme.Amber:MeterTheme.Ink;
        subtitle.Text=mounted?"\u672c\u673a\u4fa7\u680f\u5df2\u6302\u8f7d":failed?"\u8bf7\u68c0\u67e5\u5ba2\u6237\u7aef\u72b6\u6001\uff0c\u7136\u540e\u91cd\u65b0\u8fde\u63a5":stage=="sidebar-missing"?"\u7b49\u5f85\u53ef\u8bc6\u522b\u7684\u4fa7\u680f":"\u7b49\u5f85\u5ba2\u6237\u7aef\u4e0e\u6570\u636e\u540c\u6b65";
        connection.Text=mounted?"\u5df2\u8fde\u63a5":failed?"\u672a\u8fde\u63a5":"\u8fde\u63a5\u4e2d";
        quota.Text=Available(data,"quotaAvailable");usage.Text=Available(data,"usageAvailable");
        DateTime stamp;lastSync.Text=data.ContainsKey("updatedAt")&&DateTime.TryParse(Convert.ToString(data["updatedAt"]),out stamp)?stamp.ToLocalTime().ToString("MM/dd HH:mm:ss"):"--";
        if(failed&&data.ContainsKey("code"))subtitle.Text=Convert.ToString(data["code"]);
        open.Enabled=mounted||failed||stage=="sidebar-missing";retry.Enabled=mounted||failed||stage=="sidebar-missing";
        if(DateTime.UtcNow<feedbackUntil)subtitle.Text=feedback;
    }
    static string Available(Dictionary<string,object> data,string key){return data.ContainsKey(key)?Convert.ToBoolean(data[key])?"\u5df2\u540c\u6b65":"\u6682\u4e0d\u53ef\u7528":"--";}
    internal void Finish(){exiting=true;Close();Dispose();}
}
