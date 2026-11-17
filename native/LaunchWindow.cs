using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

internal sealed class LaunchWindow : Form {
    readonly Label headline,subtitle,connection,quota,usage,lastSync;
    readonly Button retry,open;
    bool exiting;
    bool autoPlanAttempted;
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
        Text="Codex Quota Sidebar";MeterTheme.Style(this,1184,792);
        body=MeterTheme.Body();Controls.Add(body);var header=MeterTheme.Header("","Windows");Controls.Add(header);
        var rail=new Panel{Dock=DockStyle.Left,Width=184,Padding=new Padding(12,22,12,16),BackColor=Color.FromArgb(245,247,250)};Controls.Add(rail);
        var nav=new FlowLayoutPanel{Dock=DockStyle.Top,Height=340,FlowDirection=FlowDirection.TopDown,WrapContents=false};rail.Controls.Add(nav);
        var updates=MeterTheme.Button("checkUpdates","Check for updates",false);updates.Dock=DockStyle.Fill;updates.Height=36;var updateSlot=new Panel{Dock=DockStyle.Right,Width=148,Padding=new Padding(0,0,12,4)};updateSlot.Controls.Add(updates);header.Controls.Add(updateSlot);header.Controls.SetChildIndex(updateSlot,1);header.Controls.Find("brandCaption",true)[0].Parent.BringToFront();
        bool updating=false;Action<string> check=null;
        check=operation=>{
            if(updating)return;
            if(operation=="prepare"&&!ResolveEdits())return;
            if(operation=="prepare"){body.Enabled=false;rail.Enabled=false;}
            updating=true;updates.Enabled=false;updates.Text=Locale.T(operation=="download"?"Downloading update...":"Checking for updates...");
            System.Threading.Tasks.Task.Factory.StartNew(()=>{
                string output="",failure=null;
                try{
                    var info=new System.Diagnostics.ProcessStartInfo(System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"runtime","node.exe"),"\""+System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"src","update.mjs")+"\" "+operation+" \""+AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\')+"\" \""+AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\')+"\" "+System.Diagnostics.Process.GetCurrentProcess().Id){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true};
                    using(var p=System.Diagnostics.Process.Start(info)){var error=p.StandardError.ReadToEndAsync();var text=p.StandardOutput.ReadToEndAsync();if(!p.WaitForExit(180000)){p.Kill();throw new Exception("Update timed out");}output=text.Result;if(p.ExitCode!=0)throw new Exception("Update could not be verified or downloaded.");}
                }catch(Exception e){failure=e.Message;}
                if(IsDisposed)return;BeginInvoke((Action)(()=>{
                    updating=false;updates.Enabled=true;body.Enabled=true;rail.Enabled=true;updates.Text=Locale.T("Check for updates");
                    if(failure!=null){if(operation!="auto")MeterTheme.Error(Locale.T("Update check failed. Please try again later."));return;}
                    try{
                        var result=new System.Web.Script.Serialization.JavaScriptSerializer().Deserialize<Dictionary<string,object>>(output);
                        if(operation=="prepare"){if(Prepared(result)){stop();return;}MeterTheme.Error(Locale.T("Update preparation failed. The meter is still running."));return;}
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
        string[] glyphs={"\uE80F","\uE8A0","\uE77B","\uE713","\uE897","\uE946"};int navIndex=0;
        foreach(string label in new[]{"Usage overview","Sidebar content","Codex subscription record","Data and settings","Diagnostics","About project"}){
            string key=label;var b=MeterTheme.Button(key,key=="Codex subscription record"?"Plan and dates":key=="Sidebar content"?"Display content":key,false);b.Font=MeterTheme.Font(9.75f);b.Width=160;b.Height=40;b.TextAlign=ContentAlignment.MiddleLeft;b.Margin=new Padding(0,0,0,5);b.BackColor=rail.BackColor;b.FlatAppearance.BorderSize=0;MeterTheme.Glyph(b,glyphs[navIndex++]);b.Click+=(s,e)=>ShowPage(key);if(key=="About project"){b.Dock=DockStyle.Bottom;rail.Controls.Add(b);}else nav.Controls.Add(b);navigation[b]=key;
        }
        overviewPage=new Panel{Dock=DockStyle.Fill};body.Controls.Add(overviewPage);
        var grid=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=2,RowCount=2,Margin=new Padding(0)};
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));
        grid.RowStyles.Add(new RowStyle(SizeType.Absolute,58));grid.RowStyles.Add(new RowStyle(SizeType.Percent,100));overviewPage.Controls.Add(grid);
        headline=MeterTheme.Label("Usage overview",16.5f,MeterTheme.Ink);headline.Name="statusHeadline";headline.TextAlign=ContentAlignment.TopLeft;grid.Controls.Add(headline,0,0);
        subtitle=MeterTheme.Label("Connecting",9,MeterTheme.Muted);subtitle.Name="statusDetail";subtitle.TextAlign=ContentAlignment.TopRight;grid.Controls.Add(subtitle,1,0);
        overview=new UsageOverview();overview.Margin=new Padding(0);grid.Controls.Add(overview,0,1);grid.SetColumnSpan(overview,2);
        connection=new Label();quota=new Label();usage=new Label();
        lastSync=MeterTheme.Label("--",9,MeterTheme.Muted);
        var footer=MeterTheme.Footer();Controls.Add(footer);body.BringToFront();Controls.SetChildIndex(header,Controls.Count-1);
        open=MeterTheme.Button("openCodex","Open Codex",true);open.Width=130;open.Enabled=false;MeterTheme.Glyph(open,"\uE8A7");open.Click+=(s,e)=>openCodex();
        retry=MeterTheme.Button("reconnect","Reconnect",false);retry.Width=132;retry.Enabled=false;MeterTheme.Glyph(retry,"\uE72C");retry.Click+=(s,e)=>reconnect();
        footer.Controls.Add(open);footer.Controls.Add(retry);
        var exit=MeterTheme.Button("exitSoftware","Exit software",false);exit.Width=140;exit.FlatAppearance.BorderSize=0;MeterTheme.Glyph(exit,"\uE7E8");exit.Click+=(s,e)=>{if(!ResolveEdits())return;if(MessageBox.Show(Locale.T("Quit the meter? Codex stays open."),Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)==DialogResult.OK)stop();};footer.Controls.Add(exit);
        footerMessage=MeterTheme.Label("Windows "+MeterTheme.Version+" / "+Locale.T("Local connection"),8,MeterTheme.Muted);footerMessage.Dock=DockStyle.None;footerMessage.Width=500;footerMessage.Height=38;footer.Controls.Add(footerMessage);
        Action footerLayout=()=>footerMessage.Width=Math.Max(180,footer.ClientSize.Width-open.Width-retry.Width-exit.Width-88);
        footer.Layout+=(s,e)=>{int target=Math.Max(180,footer.ClientSize.Width-open.Width-retry.Width-exit.Width-88);if(footerMessage.Width!=target)footerMessage.Width=target;};footerLayout();
        ShowPage("Usage overview");
        ReadUpdateOutcome();
        FormClosing+=(s,e)=>{if(!exiting&&e.CloseReason==CloseReason.UserClosing){e.Cancel=true;Hide();}};
    }
    internal static bool Prepared(Dictionary<string,object> result){object v;return result!=null&&result.TryGetValue("prepared",out v)&&v is bool&&(bool)v;}
    internal bool ResolveEdits(){
        if(editor!=null&&editor.Tag is Func<bool>&&!((Func<bool>)editor.Tag)())return false;
        return transient==null||!(transient.Tag is Func<bool>)||((Func<bool>)transient.Tag)();
    }
    internal string UpdateOutcome {get;private set;}
    internal static string UpdateError(string code){
        string message=code=="E_UPDATE_WORKER_NOT_READY"?"The update worker was not ready. Try again.":code=="E_UPDATE_CHECKSUM"?"Update verification failed. Download again.":code=="E_UPDATE_APP_STILL_RUNNING"?"The old meter is still running. Close it and retry.":code=="E_UPDATE_INSTALL_LOCATION"?"The installation folder could not be verified.":code=="E_UPDATE_BUNDLE_VERSION"?"The update version could not be verified.":code=="E_UPDATE_LAUNCH_UNVERIFIED"?"The updated app launch could not be verified.":"Review the update error in diagnostics.";
        return Locale.T(message)+(String.IsNullOrEmpty(code)?"":" ("+code+")");
    }
    void ReadUpdateOutcome(){
        try{
            var d=MeterPreferences.Read(System.IO.Path.Combine(root,"updates","transaction.json"));
            string stage=d.ContainsKey("stage")?Convert.ToString(d["stage"]):"";
            string label=stage=="failed"?"Update failed":stage=="rolled-back"?"Update rolled back":stage=="needs-attention"?"Update needs attention":null;
            if(label==null)return;
            string code=d.ContainsKey("code")?Convert.ToString(d["code"]):"";
            if(!System.Text.RegularExpressions.Regex.IsMatch(code??"",@"^E_[A-Z0-9_]{1,64}$"))code="";
            UpdateOutcome=Locale.T(label)+" / "+UpdateError(code);footerMessage.Text=UpdateOutcome;footerMessage.ForeColor=MeterTheme.Amber;
        }catch{}
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
        transient=new Panel{Dock=DockStyle.Fill,AutoScroll=false};body.Controls.Add(transient);transient.BringToFront();
        var title=MeterTheme.Label(key=="Codex subscription record"?"Plan and dates":key=="Sidebar content"?"Display content":key,16.5f,MeterTheme.Ink);title.Dock=DockStyle.Top;title.Height=50;transient.Controls.Add(title);
        var content=new FlowLayoutPanel{Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,AutoScroll=false};transient.Controls.Add(content);content.BringToFront();
        Action<string> text=value=>{var p=MeterTheme.Label(value,10,MeterTheme.Muted);p.Dock=DockStyle.None;int width=Math.Max(400,body.ClientSize.Width-60);p.AutoSize=true;p.MinimumSize=new Size(width,24);p.MaximumSize=new Size(width,0);p.Margin=new Padding(0,0,0,8);content.Controls.Add(p);};
        Action<string,Action> command=(label,action)=>{var b=MeterTheme.Button(label,label,false);b.Width=260;b.Margin=new Padding(0,2,0,20);b.Click+=(s,e)=>action();content.Controls.Add(b);};
        Action<string,string,Action> settingRow=(label,description,action)=>{
            int width=Math.Max(400,body.ClientSize.Width-60);var row=new Panel{Width=width,Height=110,Margin=new Padding(0)};
            var heading=MeterTheme.Label(label,11,MeterTheme.Ink);heading.Dock=DockStyle.None;heading.SetBounds(0,16,width-220,28);row.Controls.Add(heading);
            var caption=MeterTheme.Label(description,9.75f,MeterTheme.Muted);caption.Dock=DockStyle.None;caption.SetBounds(0,48,width-220,46);row.Controls.Add(caption);
            var button=MeterTheme.Button(label,label,false);button.SetBounds(width-200,30,200,38);button.Click+=(s,e)=>action();row.Controls.Add(button);
            row.Paint+=(s,e)=>{using(var pen=new Pen(MeterTheme.Line))e.Graphics.DrawLine(pen,0,row.Height-1,row.Width,row.Height-1);};content.Controls.Add(row);
        };
        if(key=="Codex subscription record"){
            content.Dispose();editor=MeterPreferences.Create(root,true);editor.TopLevel=false;editor.FormBorderStyle=FormBorderStyle.None;editor.Dock=DockStyle.Fill;
            transient.Controls.Add(editor);editor.BringToFront();editor.Show();
        }else if(key=="Sidebar content"){
            var list=DisplayOptions.List(root);var grouped=DisplayOptions.Grouped(list);grouped.Dock=DockStyle.None;grouped.Width=Math.Max(400,body.ClientSize.Width-60);content.Controls.Add(grouped);
            text("One selection applies to the Codex sidebar, overview and browser panel.");
            text("Official controls have priority. Scroll first; collapse only when space is very limited.");
            bool dirty=false;list.ItemCheck+=(s,e)=>dirty=true;
            text("Changes apply automatically while connected. No reconnect is needed.");
            var save=MeterTheme.Button("saveDisplay","Save",true);save.Width=80;save.Margin=new Padding(0,18,0,0);content.Controls.Add(save);
            save.Click+=(s,e)=>{try{DisplayOptions.Save(root,DisplayOptions.Capture(list));dirty=false;MeterTheme.Saved(save);}catch(Exception ex){MeterTheme.Error(ex.Message);}};
            transient.Tag=new Func<bool>(()=>{if(!dirty)return true;var answer=MessageBox.Show(Locale.T("Save changes before leaving?"),Text,MessageBoxButtons.YesNoCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button3);if(answer==DialogResult.Cancel)return false;if(answer==DialogResult.Yes){try{DisplayOptions.Save(root,DisplayOptions.Capture(list));}catch(Exception ex){MeterTheme.Error(ex.Message);return false;}}dirty=false;return true;});
        }else if(key=="Data and settings"){
            settingRow("Backup settings","Export display choices and your manually recorded subscription.",()=>SettingsTransfer.Export(root));
            settingRow("Restore settings","Select a backup and confirm before replacing your current settings.",()=>SettingsTransfer.Import(root));
            settingRow("Clear observation history","Clear local observation times only. Official usage and chats are not deleted.",()=>{if(MessageBox.Show(Locale.T("Clear local observation history?"),Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)==DialogResult.OK){System.IO.Directory.CreateDirectory(root);System.IO.File.WriteAllText(System.IO.Path.Combine(root,"clear-history.request"),"clear");Feedback(Locale.T("Clear request sent"));}});
        }else if(key=="Diagnostics"){
            if(!String.IsNullOrEmpty(UpdateOutcome))text(UpdateOutcome);
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
        headline.Text=Locale.T("Usage overview");
        headline.ForeColor=MeterTheme.Ink;
        subtitle.Text=mounted?Locale.T("Connected"):failed?Locale.T("Check Codex, then reconnect."):stage=="sidebar-missing"?Locale.T("Waiting for a supported sidebar."):Locale.T("Connecting");
        subtitle.ForeColor=mounted?Color.FromArgb(25,112,90):failed?MeterTheme.Amber:MeterTheme.Muted;
        if(!failed&&data.ContainsKey("sidebarReason")){
            string reason=Convert.ToString(data["sidebarReason"]);
            if(reason=="scroll-space")subtitle.Text=Locale.T("Sidebar scrolls to preserve space for Codex controls.");
            if(reason=="limited-space")subtitle.Text=Locale.T("Sidebar compacted to protect Codex controls. Open the quota icon for details.");
            if(reason=="official-controls-priority")subtitle.Text=Locale.T("Sidebar hidden to protect Codex controls. Usage remains available here.");
            if(reason=="disabled")subtitle.Text=Locale.T("Sidebar display is disabled in settings.");
        }
        connection.Text=mounted?Locale.T("Connected"):failed?Locale.T("Not connected"):Locale.T("Connection in progress");
        quota.Text=Available(data,"quotaAvailable");usage.Text=Available(data,"usageAvailable");
        DateTime stamp;lastSync.Text=Locale.T("Last checked")+": "+(data.ContainsKey("updatedAt")&&DateTime.TryParse(Convert.ToString(data["updatedAt"]),out stamp)?stamp.ToLocalTime().ToString("MM/dd HH:mm"):"--");
        if(failed&&data.ContainsKey("code"))subtitle.Text=Convert.ToString(data["code"]);
        open.Enabled=mounted||failed||stage=="sidebar-missing";retry.Enabled=mounted||failed||stage=="sidebar-missing";
        retry.BackColor=MeterTheme.Surface;retry.ForeColor=MeterTheme.Ink;
        open.BackColor=MeterTheme.Green;open.ForeColor=Color.White;
        AcceptButton=failed?retry:open;
        overview.ReadSnapshot(mounted);
        if(mounted&&!autoPlanAttempted){autoPlanAttempted=true;string appRoot=AppDomain.CurrentDomain.BaseDirectory;if(System.IO.File.Exists(System.IO.Path.Combine(appRoot,"src","plan.mjs")))MeterPreferences.DetectPlan(this,appRoot,"auto",result=>{overview.ReadSnapshot(true);});}
        if(DateTime.UtcNow<feedbackUntil)subtitle.Text=feedback;
        Locale.Apply(this);
    }
    static string Available(Dictionary<string,object> data,string key){return data.ContainsKey(key)?Convert.ToBoolean(data[key])?Locale.T("Synced"):Locale.T("Unavailable"):"--";}
    internal void Finish(){exiting=true;Close();Dispose();}
}
