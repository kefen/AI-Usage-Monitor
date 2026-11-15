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
            case "E_RUNNING_WITHOUT_CDP":return Locale.T("Codex is running without debugging. Save your work, retry and confirm the restart.\nE_RUNNING_WITHOUT_CDP");
            case "E_RESTART_DIALOG":return Locale.T("Restart dialog could not load. Codex was not closed. Run Diagnose.cmd.\nE_RESTART_DIALOG");
            case "E_CDP_NOT_LISTENING":return Locale.T("Debug port is not listening. Check Codex and launch the meter as a normal user.\nE_CDP_NOT_LISTENING");
            case "E_CDP_QUERY_FAILED":return Locale.T("Windows could not query local ports. Run Diagnose.cmd.\nE_CDP_QUERY_FAILED");
            case "E_NO_STORE_PACKAGE":return Locale.T("No Microsoft Store Codex package for this user.\nE_NO_STORE_PACKAGE");
            default:return "Codex preparation failed ("+code+"). Run Diagnose.cmd.";
        }
    }
    readonly UsageOverview overview;
    internal LaunchWindow(Action openCodex,Action reconnect,Action settings,Action stop){
        Text="Codex Quota Sidebar by KEFEN";MeterTheme.Style(this,1000,710);
        var body=MeterTheme.Body();Controls.Add(body);var header=MeterTheme.Header("Usage overview","Windows 0.11.0-beta.1");Controls.Add(header);
        var nav=new FlowLayoutPanel{Dock=DockStyle.Left,Width=190,FlowDirection=FlowDirection.TopDown,WrapContents=false,Padding=new Padding(14,26,14,18),BackColor=Color.FromArgb(246,247,249)};Controls.Add(nav);
        Action<string,Action> item=(label,action)=>{var b=MeterTheme.Button(label,label,false);b.Width=160;b.Height=44;b.TextAlign=ContentAlignment.MiddleLeft;b.Margin=new Padding(0,0,0,8);b.BackColor=nav.BackColor;b.FlatAppearance.BorderSize=0;b.Click+=(s,e)=>action();nav.Controls.Add(b);};
        item("Usage overview",()=>Present());
        item("Sidebar content",()=>DisplayOptions.Edit(System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory,".runtime")));
        item("Codex subscription record",settings);
        item("Diagnostics",()=>LocalDiagnostics.Export());
        item("GitHub",()=>System.Diagnostics.Process.Start(Locale.Repository));
        item("Exit software",()=>{if(MessageBox.Show(Locale.T("Quit the meter? Codex stays open."),Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)==DialogResult.OK)stop();});
        var grid=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=2,RowCount=5};
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));
        foreach(int height in new[]{48,62,310,44,32})grid.RowStyles.Add(new RowStyle(SizeType.Absolute,height));body.Controls.Add(grid);
        headline=MeterTheme.Label("Connecting",20,MeterTheme.Ink);headline.Name="statusHeadline";grid.Controls.Add(headline,0,0);grid.SetColumnSpan(headline,2);
        subtitle=MeterTheme.Label("Waiting for client and data.",10,MeterTheme.Muted);subtitle.Name="statusDetail";grid.Controls.Add(subtitle,0,1);grid.SetColumnSpan(subtitle,2);
        overview=new UsageOverview();grid.Controls.Add(overview,0,2);grid.SetColumnSpan(overview,2);
        var account=MeterTheme.Label("Local CLI account; may differ from the desktop account.",9,MeterTheme.Muted);grid.Controls.Add(account,0,3);grid.SetColumnSpan(account,2);
        connection=new Label();quota=new Label();usage=new Label();
        lastSync=MeterTheme.Label("--",9,MeterTheme.Muted);grid.Controls.Add(lastSync,0,4);
        var hint=MeterTheme.Label("Closing this window keeps the meter in the tray.",9,MeterTheme.Muted);grid.Controls.Add(hint,1,4);
        var footer=MeterTheme.Footer();Controls.Add(footer);body.BringToFront();Controls.SetChildIndex(header,Controls.Count-1);
        open=MeterTheme.Button("openCodex","Open Codex",true);open.Width=156;open.Enabled=false;open.Click+=(s,e)=>openCodex();
        retry=MeterTheme.Button("reconnect","Reconnect",false);retry.Width=150;retry.Enabled=false;retry.Click+=(s,e)=>reconnect();
        footer.Controls.Add(open);footer.Controls.Add(retry);
        FormClosing+=(s,e)=>{if(!exiting&&e.CloseReason==CloseReason.UserClosing){e.Cancel=true;Hide();}};
    }
    static Label Row(TableLayoutPanel grid,int row,string key){grid.Controls.Add(MeterTheme.Label(key,10,MeterTheme.Muted),0,row);var value=MeterTheme.Label("--",10,MeterTheme.Ink);value.Name="statusRow"+row;grid.Controls.Add(value,1,row);return value;}
    internal void Present(){Show();WindowState=FormWindowState.Normal;Activate();}
    internal void UpdateState(string stage,Dictionary<string,object> data){
        bool mounted=stage.StartsWith("mounted",StringComparison.Ordinal),failed=stage=="failed"||stage=="startup-failed"||stage=="attach-failed"||stage=="restart-cancelled";
        headline.Text=mounted?Locale.T("Connected"):failed?Locale.T("Connection incomplete"):Locale.T("Connecting");
        headline.ForeColor=mounted?MeterTheme.Green:failed?MeterTheme.Amber:MeterTheme.Ink;
        subtitle.Text=mounted?Locale.T("Sidebar attached."):failed?Locale.T("Check Codex, then reconnect."):stage=="sidebar-missing"?Locale.T("Waiting for a supported sidebar."):Locale.T("Waiting for client and data.");
        connection.Text=mounted?Locale.T("Connected"):failed?Locale.T("Not connected"):Locale.T("Connection in progress");
        quota.Text=Available(data,"quotaAvailable");usage.Text=Available(data,"usageAvailable");
        DateTime stamp;lastSync.Text=data.ContainsKey("updatedAt")&&DateTime.TryParse(Convert.ToString(data["updatedAt"]),out stamp)?stamp.ToLocalTime().ToString("MM/dd HH:mm:ss"):"--";
        if(failed&&data.ContainsKey("code"))subtitle.Text=Convert.ToString(data["code"]);
        open.Enabled=mounted||failed||stage=="sidebar-missing";retry.Enabled=mounted||failed||stage=="sidebar-missing";
        retry.BackColor=failed?MeterTheme.Green:MeterTheme.Surface;retry.ForeColor=failed?Color.White:MeterTheme.Ink;
        open.BackColor=failed?MeterTheme.Surface:MeterTheme.Green;open.ForeColor=failed?MeterTheme.Ink:Color.White;
        AcceptButton=failed?retry:open;
        overview.ReadSnapshot(mounted);
        if(DateTime.UtcNow<feedbackUntil)subtitle.Text=feedback;
        Locale.Apply(this);
    }
    static string Available(Dictionary<string,object> data,string key){return data.ContainsKey(key)?Convert.ToBoolean(data[key])?Locale.T("Synced"):Locale.T("Unavailable"):"--";}
    internal void Finish(){exiting=true;Close();Dispose();}
}
