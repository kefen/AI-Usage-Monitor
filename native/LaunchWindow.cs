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
    internal void Feedback(string message){feedback=message;feedbackUntil=DateTime.UtcNow.AddSeconds(10);subtitle.Text=message;footerMessage.Text=message;Present();}
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
    readonly Panel body,overviewPage;
    readonly string root=System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory,".runtime");
    readonly Dictionary<Button,string> navigation=new Dictionary<Button,string>();
    readonly Action reconnectAction;
    readonly Label footerMessage;
    Form editor;
    Panel transient;
    string currentPage;
    internal LaunchWindow(Action openCodex,Action reconnect,Action settings,Action stop){
        reconnectAction=reconnect;
        Text="Codex Quota Sidebar by KEFEN";MeterTheme.Style(this,1000,710);
        body=MeterTheme.Body();Controls.Add(body);var header=MeterTheme.Header("","Windows");Controls.Add(header);
        var rail=new Panel{Dock=DockStyle.Left,Width=184,Padding=new Padding(12,22,12,16),BackColor=Color.FromArgb(245,247,250)};Controls.Add(rail);
        var nav=new FlowLayoutPanel{Dock=DockStyle.Top,Height=340,FlowDirection=FlowDirection.TopDown,WrapContents=false};rail.Controls.Add(nav);
        var version=MeterTheme.Label("v0.12.5",8,MeterTheme.Muted);version.Dock=DockStyle.Bottom;version.Height=26;rail.Controls.Add(version);
        var updates=MeterTheme.Button("checkUpdates","Check for updates",false);updates.Dock=DockStyle.Bottom;updates.Height=34;rail.Controls.Add(updates);updates.BringToFront();
        bool updating=false;Action<string> check=null;
        check=operation=>{
            if(updating)return;updating=true;updates.Enabled=false;updates.Text=Locale.T(operation=="download"?"Downloading update...":"Checking for updates...");
            System.Threading.Tasks.Task.Factory.StartNew(()=>{
                string output="",failure=null;
                try{
                    var info=new System.Diagnostics.ProcessStartInfo(System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"runtime","node.exe"),"\""+System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"src","update.mjs")+"\" "+operation+" \""+AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\')+"\" \""+AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\')+"\" "+System.Diagnostics.Process.GetCurrentProcess().Id){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true};
                    using(var p=System.Diagnostics.Process.Start(info)){var error=p.StandardError.ReadToEndAsync();var text=p.StandardOutput.ReadToEndAsync();if(!p.WaitForExit(180000)){p.Kill();throw new Exception("Update timed out");}output=text.Result;if(p.ExitCode!=0)throw new Exception("Update could not be verified or downloaded.");}
                }catch(Exception e){failure=e.Message;}
                if(IsDisposed)return;BeginInvoke((Action)(()=>{
                    updating=false;updates.Enabled=true;updates.Text=Locale.T("Check for updates");
                    if(failure!=null){if(operation!="auto")MeterTheme.Error(Locale.T("Update check failed. Please try again later."));return;}
                    try{
                        var result=new System.Web.Script.Serialization.JavaScriptSerializer().Deserialize<Dictionary<string,object>>(output);
                        if(operation=="prepare"){stop();return;}
                        if(!result.ContainsKey("available")||!Convert.ToBoolean(result["available"])){if(operation!="auto")MessageBox.Show(Locale.T("You are up to date."),Text);return;}
                        updates.Text=Locale.T("Update available")+" "+result["version"];
                        if(operation=="auto")return;
                        bool ready=result.ContainsKey("ready")&&Convert.ToBoolean(result["ready"]);
                        string prompt=Locale.T(ready?"Restart the companion to install the verified update? Codex stays open.":"Download this update in the background?");
                        if(MessageBox.Show(prompt+"\n\n"+result["version"]+"\n"+result["notes"],Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Information,MessageBoxDefaultButton.Button2)==DialogResult.OK)check(ready?"prepare":"download");
                    }catch{MeterTheme.Error(Locale.T("Update check failed. Please try again later."));}
                }));
            });
        };
        updates.Click+=(s,e)=>check("check");
        var updateTimer=new System.Windows.Forms.Timer{Interval=86400000};updateTimer.Tick+=(s,e)=>check("auto");Disposed+=(s,e)=>updateTimer.Dispose();updateTimer.Start();
        Shown+=(s,e)=>{if(System.IO.File.Exists(System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"installation.json")))check("auto");};
        foreach(string label in new[]{"Usage overview","Sidebar content","Codex subscription record","Data and settings","Diagnostics","About project"}){
            string key=label;var b=MeterTheme.Button(key,key,false);b.Width=160;b.Height=40;b.TextAlign=ContentAlignment.MiddleLeft;b.Margin=new Padding(0,0,0,6);b.BackColor=rail.BackColor;b.FlatAppearance.BorderSize=0;b.Click+=(s,e)=>ShowPage(key);nav.Controls.Add(b);navigation[b]=key;
        }
        overviewPage=new Panel{Dock=DockStyle.Fill};body.Controls.Add(overviewPage);
        var grid=new TableLayoutPanel{Dock=DockStyle.Top,Height=460,ColumnCount=2,RowCount=5};
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));
        foreach(int height in new[]{38,42,270,50,40})grid.RowStyles.Add(new RowStyle(SizeType.Absolute,height));overviewPage.Controls.Add(grid);
        headline=MeterTheme.Label("Connecting",17,MeterTheme.Ink);headline.Name="statusHeadline";grid.Controls.Add(headline,0,0);grid.SetColumnSpan(headline,2);
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
        var exit=MeterTheme.Button("exitSoftware","Exit software",false);exit.Width=135;exit.Click+=(s,e)=>{if(MessageBox.Show(Locale.T("Quit the meter? Codex stays open."),Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)==DialogResult.OK)stop();};footer.Controls.Add(exit);
        footerMessage=MeterTheme.Label("",8,MeterTheme.Muted);footerMessage.Dock=DockStyle.None;footerMessage.Width=200;footerMessage.Height=36;footer.Controls.Add(footerMessage);
        ShowPage("Usage overview");
        FormClosing+=(s,e)=>{if(!exiting&&e.CloseReason==CloseReason.UserClosing){e.Cancel=true;Hide();}};
    }
    internal void ShowPage(string key){
        if(currentPage==key)return;
        if(transient!=null&&transient.Tag is Func<bool>&&!((Func<bool>)transient.Tag)())return;
        if(editor!=null){var guard=editor.Tag as Func<bool>;if(guard!=null&&!guard())return;editor.Dispose();editor=null;}
        if(transient!=null){transient.Dispose();transient=null;}
        currentPage=key;
        overviewPage.Visible=key=="Usage overview";
        foreach(var pair in navigation){pair.Key.BackColor=pair.Value==key?Color.FromArgb(231,238,252):Color.FromArgb(245,247,250);pair.Key.ForeColor=pair.Value==key?MeterTheme.Green:MeterTheme.Muted;}
        if(key=="Usage overview"){overviewPage.BringToFront();return;}
        transient=new Panel{Dock=DockStyle.Fill,AutoScroll=true};body.Controls.Add(transient);transient.BringToFront();
        var title=MeterTheme.Label(key,18,MeterTheme.Ink);title.Dock=DockStyle.Top;title.Height=46;transient.Controls.Add(title);
        var content=new FlowLayoutPanel{Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,AutoScroll=true};transient.Controls.Add(content);content.BringToFront();
        Action<string> text=value=>{var p=MeterTheme.Label(value,10,MeterTheme.Muted);p.Dock=DockStyle.None;int width=Math.Max(400,body.ClientSize.Width-60);p.AutoSize=true;p.MinimumSize=new Size(width,24);p.MaximumSize=new Size(width,0);p.Margin=new Padding(0,0,0,8);content.Controls.Add(p);};
        Action<string,Action> command=(label,action)=>{var b=MeterTheme.Button(label,label,false);b.Width=260;b.Margin=new Padding(0,2,0,20);b.Click+=(s,e)=>action();content.Controls.Add(b);};
        if(key=="Codex subscription record"){
            content.Dispose();editor=MeterPreferences.Create(root,true);editor.TopLevel=false;editor.FormBorderStyle=FormBorderStyle.None;editor.Dock=DockStyle.Fill;
            transient.Controls.Add(editor);editor.BringToFront();editor.Show();
        }else if(key=="Sidebar content"){
            var list=DisplayOptions.List(root);var grouped=DisplayOptions.Grouped(list);grouped.Dock=DockStyle.None;grouped.Width=Math.Max(400,body.ClientSize.Width-60);content.Controls.Add(grouped);
            text("Official controls have priority. Scroll first; collapse only when space is very limited.");
            bool dirty=false;list.ItemCheck+=(s,e)=>dirty=true;
            text("Changes apply automatically while connected. No reconnect is needed.");
            var save=MeterTheme.Button("saveDisplay","Save",true);save.Width=160;save.Margin=new Padding(0,6,0,0);content.Controls.Add(save);
            save.Click+=(s,e)=>{try{DisplayOptions.Save(root,DisplayOptions.Capture(list));dirty=false;MeterTheme.Saved(save);}catch(Exception ex){MeterTheme.Error(ex.Message);}};
            transient.Tag=new Func<bool>(()=>!dirty||MessageBox.Show(Locale.T("Discard unsaved changes?"),Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)==DialogResult.OK);
        }else if(key=="Data and settings"){
            text("Export display choices, language and your manually recorded subscription.");command("Backup settings",()=>SettingsTransfer.Export(root));
            text("Select a backup and confirm before replacing your current settings.");command("Restore settings",()=>SettingsTransfer.Import(root));
            text("Clear local observation times only. Official usage and chats are not deleted.");
            command("Clear observation history",()=>{if(MessageBox.Show(Locale.T("Clear local observation history?"),Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)==DialogResult.OK){System.IO.Directory.CreateDirectory(root);System.IO.File.WriteAllText(System.IO.Path.Combine(root,"clear-history.request"),"clear");Feedback(Locale.T("Clear request sent"));}});
        }else if(key=="Diagnostics"){
            text("1. Check that official Codex can chat. Enlarge the window if the sidebar is hidden, then reconnect.");command("Reconnect",reconnectAction);
            text("2. Export diagnostics: version, system, connection state and error codes. No keys, chats, accounts or installation paths.");command("Export sanitized diagnostics",()=>LocalDiagnostics.Export());
            text("3. Review the file, describe how to reproduce the problem, then attach it to a GitHub issue. Hide personal information in screenshots.");command("Submit feedback on GitHub",()=>System.Diagnostics.Process.Start(Locale.Repository+"/issues/new"));
            text("No automatic uploads. You choose what to submit. A GitHub account is required to post an issue.");
        }else if(key=="About project"){
            text("Codex Quota Sidebar by KEFEN");text("Local, read-only quota and Token indicators in the Codex sidebar. Choose the metrics you need; official controls always have priority.");
            var divider=new Panel{Width=Math.Max(400,body.ClientSize.Width-60),Height=1,BackColor=MeterTheme.Line,Margin=new Padding(0,6,0,14)};content.Controls.Add(divider);
            text("Author: KEFEN / License: MIT");text("Unofficial software. Not affiliated with or endorsed by OpenAI.");text("Uses the local CLI account. Token activity is not an API bill.");command("Visit GitHub project",()=>System.Diagnostics.Process.Start(Locale.Repository));
        }
        Locale.Apply(transient);
    }
    static Label Row(TableLayoutPanel grid,int row,string key){grid.Controls.Add(MeterTheme.Label(key,10,MeterTheme.Muted),0,row);var value=MeterTheme.Label("--",10,MeterTheme.Ink);value.Name="statusRow"+row;grid.Controls.Add(value,1,row);return value;}
    internal void Present(){Show();WindowState=FormWindowState.Normal;Activate();}
    internal void UpdateState(string stage,Dictionary<string,object> data){
        bool mounted=stage.StartsWith("mounted",StringComparison.Ordinal),failed=stage=="failed"||stage=="startup-failed"||stage=="attach-failed"||stage=="restart-cancelled";
        headline.Text=mounted?Locale.T("Connected"):failed?Locale.T("Connection incomplete"):Locale.T("Connecting");
        headline.ForeColor=mounted?MeterTheme.Green:failed?MeterTheme.Amber:MeterTheme.Ink;
        subtitle.Text=mounted?Locale.T("Sidebar attached."):failed?Locale.T("Check Codex, then reconnect."):stage=="sidebar-missing"?Locale.T("Waiting for a supported sidebar."):Locale.T("Waiting for client and data.");
        if(!failed&&data.ContainsKey("sidebarReason")){
            string reason=Convert.ToString(data["sidebarReason"]);
            if(reason=="scroll-space")subtitle.Text=Locale.T("Sidebar scrolls to preserve space for Codex controls.");
            if(reason=="limited-space")subtitle.Text=Locale.T("Sidebar compacted to protect Codex controls. Open the quota icon for details.");
            if(reason=="official-controls-priority")subtitle.Text=Locale.T("Sidebar hidden to protect Codex controls. Usage remains available here.");
            if(reason=="disabled")subtitle.Text=Locale.T("Sidebar display is disabled in settings.");
        }
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
