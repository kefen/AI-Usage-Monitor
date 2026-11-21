using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

internal sealed class LaunchWindow : Form {
    readonly Label headline,subtitle,connection,quota,usage,lastSync;
    readonly Button retry,open;
    readonly ConnectionIndicator connecting;
    Action<string> checkUpdate;
    Button aboutUpdate;
    bool updateAvailable;
    bool exiting;
    bool autoPlanAttempted;
    bool snapshotConnected;
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
    readonly Dictionary<NavigationItem,string> navigation=new Dictionary<NavigationItem,string>();
    readonly Action reconnectAction;
    readonly Label footerMessage;
    Form editor;
    Panel transient;
    string currentPage;
    internal LaunchWindow(Action openCodex,Action reconnect,Action settings,Action stop){
        reconnectAction=reconnect;
        Text="AI Usage Monitor";MeterTheme.Style(this,1184,792);
        Load+=(s,e)=>{
            float scale;using(var g=CreateGraphics())scale=g.DpiX/96f;
            var work=Screen.FromControl(this).WorkingArea;
            MinimumSize=new Size(Math.Min(work.Width,(int)(680*scale)),Math.Min(work.Height,(int)(500*scale)));
            Size=new Size(Math.Min(work.Width,Width),Math.Min(work.Height,(int)(594*scale)));
            Location=new Point(work.Left+(work.Width-Width)/2,work.Top+(work.Height-Height)/2);
        };
        var main=new Panel{Dock=DockStyle.Fill,BackColor=MeterTheme.Surface};Controls.Add(main);
        body=MeterTheme.Body();main.Controls.Add(body);var header=MeterTheme.Header("","Windows");main.Controls.Add(header);
        header.Height=68;
        var logo=header.Controls.Find("brandLogo",true)[0];
        logo.AccessibleName=Locale.T("Visit GitHub project");logo.TabStop=true;logo.Cursor=Cursors.Hand;logo.Click+=(s,e)=>MeterTheme.OpenProject();
        body.Name="pageBody";body.Padding=new Padding(25,19,25,16);
        Action alignHeader=()=>{var inset=new Padding(body.Padding.Left,0,body.Padding.Right,0);if(header.Padding!=inset)header.Padding=inset;};
        header.Layout+=(s,e)=>alignHeader();body.PaddingChanged+=(s,e)=>alignHeader();Shown+=(s,e)=>alignHeader();alignHeader();
        var rail=new Panel{Dock=DockStyle.Left,Width=176,Padding=new Padding(10,0,10,12),BackColor=MeterTheme.Tint(Color.FromArgb(243,246,251))};Controls.Add(rail);
        rail.Paint+=(s,e)=>{using(var pen=new Pen(MeterTheme.Line))e.Graphics.DrawLine(pen,rail.Width-1,0,rail.Width-1,rail.Height);};
        var nav=new FlowLayoutPanel{Dock=DockStyle.Top,Height=218,FlowDirection=FlowDirection.TopDown,WrapContents=false};rail.Controls.Add(nav);
        var brand=new Panel{Dock=DockStyle.Top,Height=80};rail.Controls.Add(brand);
        header.Controls.Find("brandCaption",true)[0].Parent.Dispose();
        var brandTitle=MeterTheme.Label("AI Usage Monitor",9.75f,MeterTheme.Ink);brandTitle.Name="brandTitle";brandTitle.Dock=DockStyle.None;
        var brandCaption=MeterTheme.Label("by KEFEN",8.25f,MeterTheme.Muted);brandCaption.Name="brandCaption";brandCaption.Dock=DockStyle.None;
        logo.Dock=DockStyle.None;brand.Controls.Add(logo);brand.Controls.Add(brandTitle);brand.Controls.Add(brandCaption);
        Action brandLayout=()=>{using(var g=brand.CreateGraphics()){
            float s=g.DpiX/96f;int left=(int)(43*s),width=Math.Max(0,brand.Width-left),mid=brand.Height/2;
            logo.SetBounds((int)(5*s),mid-(int)(16*s),(int)(30*s),(int)(30*s));
            brandTitle.SetBounds(left,mid-(int)(21*s),width,(int)(21*s));brandCaption.SetBounds(left,mid,width,(int)(18*s));
        }};brand.SizeChanged+=(s,e)=>brandLayout();Shown+=(s,e)=>brandLayout();brandLayout();
        var updates=MeterTheme.Button("installUpdate",Locale.T("Update available"),false);
        updates.AccessibleName=updates.Text;MeterTheme.Glyph(updates,"\uE896");updates.Visible=false;
        updates.BackColor=MeterTheme.Tint(Color.FromArgb(234,241,255));updates.ForeColor=MeterTheme.Tint(Color.FromArgb(27,76,174));
        updates.FlatAppearance.BorderSize=0;updates.FlatAppearance.MouseOverBackColor=MeterTheme.Tint(Color.FromArgb(219,232,255));
        header.Controls.Find("languageControl",true)[0].Dispose();
        var updateSlot=new Panel{Dock=DockStyle.Right,Width=148,Visible=false};
        updateSlot.Controls.Add(updates);header.Controls.Add(updateSlot);header.Controls.SetChildIndex(updateSlot,0);
        Action alignUpdate=()=>{
            int height=Math.Min(updateSlot.ClientSize.Height,updates.Font.Height+16);
            updates.SetBounds(0,Math.Max(0,(updateSlot.ClientSize.Height-height)/2),updateSlot.ClientSize.Width,height);
        };
        updateSlot.Layout+=(s,e)=>alignUpdate();alignUpdate();
        var updateTip=new ToolTip();Disposed+=(s,e)=>updateTip.Dispose();
        Action localizeUpdate=()=>{
            updates.Text=updates.AccessibleName=Locale.T("Update available");updateTip.SetToolTip(updates,updates.Text);
            if(!header.IsHandleCreated)return;
            using(var g=header.CreateGraphics()){
                var flags=TextFormatFlags.NoPadding|TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine;
                int textWidth=TextRenderer.MeasureText(g,updates.Text,updates.Font,new Size(Int32.MaxValue,Int32.MaxValue),flags).Width;
                updateSlot.Width=textWidth+(int)Math.Ceiling(48*g.DpiX/96)+8;
            }
        };
        localizeUpdate();Locale.Changed+=localizeUpdate;Disposed+=(s,e)=>Locale.Changed-=localizeUpdate;
        updates.FontChanged+=(s,e)=>localizeUpdate();
        Shown+=(s,e)=>localizeUpdate();
        bool updating=false;Action<string> check=null;
        check=operation=>{
            if(updating)return;
            if(operation=="prepare"&&!ResolveEdits())return;
            if(operation=="prepare"){body.Enabled=false;rail.Enabled=false;}
            updating=true;updates.Enabled=false;if(aboutUpdate!=null&&!aboutUpdate.IsDisposed){aboutUpdate.Enabled=false;aboutUpdate.Text=Locale.T(operation=="download"?"Downloading update...":"Checking for updates...");}
            System.Threading.Tasks.Task.Factory.StartNew(()=>{
                var response=UpdateRunner.Run(AppDomain.CurrentDomain.BaseDirectory,operation);
                if(IsDisposed)return;BeginInvoke((Action)(()=>{
                    updating=false;updates.Enabled=true;body.Enabled=true;rail.Enabled=true;if(aboutUpdate!=null&&!aboutUpdate.IsDisposed){aboutUpdate.Enabled=true;aboutUpdate.Text=Locale.T("Check for updates");}
                    if(!response.Success){
                        bool behind=response.Code=="E_UPDATE_FEED_BEHIND";
                        if(behind)updateAvailable=updateSlot.Visible=updates.Visible=false;
                        UpdateOutcome=Locale.T(behind?"The signed update list is behind this installation. Check GitHub Releases for the latest version.":"Update check failed. Please try again later.")+" ("+response.Code+")";
                        footerMessage.Text=UpdateOutcome;if(operation!="auto")MeterTheme.Error(UpdateOutcome);return;
                    }
                    if(footerMessage.Text==UpdateOutcome)footerMessage.Text="";UpdateOutcome=null;
                    try{
                        var result=response.Data;
                        if(operation=="prepare"){if(Prepared(result)){stop();return;}MeterTheme.Error(Locale.T("Update preparation failed. The meter is still running."));return;}
                        updateAvailable=(bool)result["available"];updateSlot.Visible=updates.Visible=updateAvailable;
                        if(!updateAvailable){if(operation!="auto")MessageBox.Show(Locale.T("You are up to date."),Text);return;}
                        if(operation=="auto")return;
                        bool ready=result.ContainsKey("ready")&&Convert.ToBoolean(result["ready"]);
                        string prompt=Locale.T(ready?"Restart the companion to install the verified update? Codex stays open.":"Download this update in the background?");
                        if(MessageBox.Show(prompt+"\n\n"+result["version"]+"\n"+(result.ContainsKey("notes")?result["notes"]:""),Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Information,MessageBoxDefaultButton.Button2)==DialogResult.OK)check(ready?"prepare":"download");
                    }catch{if(operation!="auto")MeterTheme.Error(Locale.T("Update check failed. Please try again later.")+" (E_UPDATE_PRESENTATION)");}
                }));
            });
        };
        checkUpdate=check;updates.Click+=(s,e)=>check("download");
        var updateTimer=new System.Windows.Forms.Timer{Interval=21600000};updateTimer.Tick+=(s,e)=>check("auto");Disposed+=(s,e)=>updateTimer.Dispose();updateTimer.Start();
        Shown+=(s,e)=>{if(System.IO.File.Exists(System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"installation.json")))check("auto");};
        string[] glyphs={"\uE80F","\uE8A0","\uE77B","\uE713","\uE897","\uE946"};int navIndex=0;
        foreach(string label in new[]{"Usage overview","Sidebar content","Codex subscription record","Data and settings","Diagnostics","About project"}){
            string key=label;var b=new NavigationItem{Name=key,Text=PageName(key),Glyph=glyphs[navIndex++],Font=MeterTheme.Font(9.25f),Width=156,Height=36,Margin=new Padding(0,0,0,4),BackColor=rail.BackColor,ForeColor=MeterTheme.Muted};
            b.Click+=(s,e)=>ShowPage(key);if(key=="About project"){b.Dock=DockStyle.Bottom;rail.Controls.Add(b);}else nav.Controls.Add(b);navigation[b]=key;
        }
        overviewPage=new Panel{Dock=DockStyle.Fill};body.Controls.Add(overviewPage);
        var statusPanel=new Panel{Dock=DockStyle.Fill};header.Controls.Add(statusPanel);statusPanel.BringToFront();
        statusPanel.Paint+=(s,e)=>{using(var pen=new Pen(MeterTheme.Line))e.Graphics.DrawLine(pen,0,statusPanel.Height-1,statusPanel.Width,statusPanel.Height-1);};
        headline=MeterTheme.Label("Usage overview",16.5f,MeterTheme.Ink);headline.Name="statusHeadline";headline.Dock=DockStyle.None;statusPanel.Controls.Add(headline);
        subtitle=MeterTheme.Label("Connecting",9,MeterTheme.Muted);subtitle.Name="statusDetail";subtitle.AutoEllipsis=true;statusPanel.Controls.Add(subtitle);
        subtitle.Dock=DockStyle.None;subtitle.AccessibleName=subtitle.Text;
        connecting=new ConnectionIndicator{Name="connectionProgress"};statusPanel.Controls.Add(connecting);
        Action arrangeStatus=()=>{using(var g=statusPanel.CreateGraphics()){
            float scale=g.DpiX/96f;int gap=(int)(12*scale),width=statusPanel.Width;
            int titleWidth=TextRenderer.MeasureText(g,headline.Text,headline.Font,Size.Empty,TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine).Width;
            bool inline=width-titleWidth-gap>=(int)(78*scale);
            int mid=statusPanel.Height/2,top=inline?mid-(int)(17*scale):mid-(int)(25*scale);
            headline.SetBounds(0,top,Math.Min(width,titleWidth),(int)(33*scale));
            int left=inline?titleWidth+gap:0,subTop=inline?mid-(int)(10*scale):top+(int)(31*scale);
            subtitle.SetBounds(left,subTop,Math.Max(0,width-left-gap),(int)(18*scale));
            connecting.SetBounds(left,subTop+(int)(19*scale),Math.Min(subtitle.Width,(int)(136*scale)),Math.Max(2,(int)(2*scale)));
        }};
        statusPanel.SizeChanged+=(s,e)=>arrangeStatus();headline.TextChanged+=(s,e)=>arrangeStatus();subtitle.TextChanged+=(s,e)=>{subtitle.AccessibleName=subtitle.Text;arrangeStatus();};arrangeStatus();
        overview=new UsageOverview();overview.Margin=new Padding(0);overviewPage.Controls.Add(overview);
        Locale.Changed+=overview.RefreshLanguage;Disposed+=(s,e)=>Locale.Changed-=overview.RefreshLanguage;
        connection=new Label();quota=new Label();usage=new Label();
        lastSync=MeterTheme.Label("--",9,MeterTheme.Muted);
        var footer=new Panel{Name="mainFooter",Dock=DockStyle.Bottom,Height=53,Padding=new Padding(10,8,17,8),BackColor=MeterTheme.Tint(Color.FromArgb(249,251,254))};
        footer.Paint+=(s,e)=>{using(var pen=new Pen(MeterTheme.Line))e.Graphics.DrawLine(pen,0,0,footer.Width,0);};Controls.Add(footer);main.BringToFront();body.BringToFront();
        open=MeterTheme.Button("openCodex","Open Codex",true);open.Width=150;open.Enabled=true;MeterTheme.Glyph(open,"\uE8A7");open.Click+=(s,e)=>openCodex();
        retry=MeterTheme.Button("reconnect","Reconnect",false);retry.Width=132;retry.Enabled=false;MeterTheme.Glyph(retry,"\uE72C");retry.Click+=(s,e)=>reconnect();
        footer.Controls.Add(open);footer.Controls.Add(retry);
        var exit=new NavigationItem{Name="exitSoftware",Text="Exit software",Glyph="\uE7E8",CenterContent=true,Font=MeterTheme.Font(9.75f),Width=140,Height=38,BackColor=footer.BackColor,ForeColor=MeterTheme.Muted};exit.Click+=(s,e)=>{if(!ResolveEdits())return;if(MessageBox.Show(Locale.T("Quit the meter? Codex stays open."),Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)==DialogResult.OK)stop();};footer.Controls.Add(exit);
        var identity=new Panel{Name="footerIdentity",Width=500,Height=38,Margin=new Padding(0)};
        var version=MeterTheme.Label("Windows "+MeterTheme.Version,8.5f,MeterTheme.Muted);version.Name="footerVersion";version.Dock=DockStyle.None;
        footerMessage=MeterTheme.Label("",8,MeterTheme.Muted);footerMessage.Name="footerFeedback";footerMessage.Dock=DockStyle.None;footerMessage.AutoEllipsis=true;
        identity.Controls.Add(footerMessage);identity.Controls.Add(version);footer.Controls.Add(identity);
        bool footerSizing=false;Action footerLayout=()=>{if(footerSizing)return;footerSizing=true;try{
            float scale;using(var g=footer.CreateGraphics())scale=g.DpiX/96f;
            int width=(int)(124*scale),gap=(int)(6*scale),height=(int)(35*scale),left=footer.ClientSize.Width-footer.Padding.Right-width*3-gap*2,top=Math.Max(0,(footer.ClientSize.Height-height)/2);
            exit.SetBounds(left,top,width,height);retry.SetBounds(left+width+gap,top,width,height);open.SetBounds(left+(width+gap)*2,top,width,height);
            identity.SetBounds(footer.Padding.Left,top,Math.Max(0,left-footer.Padding.Left-(int)(16*scale)),height);
            int line=(int)(18*scale);bool hasFeedback=!String.IsNullOrEmpty(footerMessage.Text);footerMessage.Visible=hasFeedback;version.SetBounds(0,hasFeedback?0:(height-line)/2,identity.Width,line);footerMessage.SetBounds(0,height-line,identity.Width,line);
        }finally{footerSizing=false;}};
        footer.Layout+=(s,e)=>footerLayout();footerMessage.TextChanged+=(s,e)=>footerLayout();footerLayout();
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
    static string PageName(string key){return key=="Codex subscription record"?"Plan and dates":key=="Sidebar content"?"Display content":key;}
    internal void ShowPage(string key){
        if(currentPage==key)return;
        if(transient!=null&&transient.Tag is Func<bool>&&!((Func<bool>)transient.Tag)())return;
        if(editor!=null){var guard=editor.Tag as Func<bool>;if(guard!=null&&!guard())return;editor.Dispose();editor=null;}
        if(transient!=null){transient.Dispose();transient=null;}
        currentPage=key;
        headline.Text=Locale.T(PageName(key));subtitle.Visible=key=="Usage overview";
        connecting.Visible=subtitle.Visible&&connecting.Active;
        overviewPage.Visible=key=="Usage overview";
        foreach(var pair in navigation){pair.Key.BackColor=pair.Value==key?MeterTheme.Tint(Color.FromArgb(228,237,253)):MeterTheme.Tint(Color.FromArgb(243,246,251));pair.Key.ForeColor=pair.Value==key?MeterTheme.Green:MeterTheme.Muted;}
        if(key=="Usage overview"){overview.ReadSnapshot(snapshotConnected);overview.AutoScrollPosition=Point.Empty;overviewPage.BringToFront();return;}
        transient=new Panel{Dock=DockStyle.Fill,AutoScroll=false};body.Controls.Add(transient);transient.BringToFront();
        var content=new FlowLayoutPanel{Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,AutoScroll=true};transient.Controls.Add(content);content.BringToFront();
        Action<string> text=value=>{var p=MeterTheme.Label(value,10,MeterTheme.Muted);p.Dock=DockStyle.None;int width=Math.Max(400,body.ClientSize.Width-60);p.AutoSize=true;p.MinimumSize=new Size(width,24);p.MaximumSize=new Size(width,0);p.Margin=new Padding(0,0,0,8);content.Controls.Add(p);};
        Action<string,string,string,Action> actionRow=(title,description,label,action)=>{
            int width=Math.Max(300,body.ClientSize.Width-60);var row=new Panel{Width=width,Height=110,Margin=new Padding(0)};
            var heading=MeterTheme.Label(title,10,MeterTheme.Ink);heading.Dock=DockStyle.None;row.Controls.Add(heading);
            var caption=MeterTheme.Label(description,9,MeterTheme.Muted);caption.Dock=DockStyle.None;row.Controls.Add(caption);
            var button=MeterTheme.Button(label,label,false);button.Click+=(s,e)=>action();row.Controls.Add(button);
            bool layoutRunning=false;Action layout=()=>{if(layoutRunning)return;layoutRunning=true;try{using(var g=row.CreateGraphics()){
                float scale=g.DpiX/96f;int pad=(int)(12*scale),height=(int)(34*scale);
                int buttonWidth=Math.Min(row.Width,Math.Max((int)(170*scale),TextRenderer.MeasureText(g,Locale.T(label),button.Font).Width+pad*2));
                bool stack=row.Width<(int)(495*scale);int textWidth=Math.Max(1,stack?row.Width:row.Width-buttonWidth-pad);
                int titleHeight=(int)(25*scale);
                int captionHeight=TextRenderer.MeasureText(g,caption.Text,caption.Font,new Size(textWidth,Int32.MaxValue),TextFormatFlags.NoPrefix|TextFormatFlags.WordBreak).Height+4;
                heading.SetBounds(0,pad,textWidth,titleHeight);caption.SetBounds(0,heading.Bottom,textWidth,captionHeight);
                button.SetBounds(stack?0:row.Width-buttonWidth,stack?caption.Bottom+pad:pad,buttonWidth,height);
                row.Height=Math.Max(caption.Bottom,button.Bottom)+pad;
            }}finally{layoutRunning=false;}};
            row.SizeChanged+=(s,e)=>layout();caption.TextChanged+=(s,e)=>layout();layout();
            row.Paint+=(s,e)=>{using(var pen=new Pen(MeterTheme.Line))e.Graphics.DrawLine(pen,0,row.Height-1,row.Width,row.Height-1);};content.Controls.Add(row);
        };
        Action<string,string,Action> settingRow=(label,description,action)=>actionRow(label,description,label,action);
        if(key=="Codex subscription record"){
            content.Dispose();editor=MeterPreferences.Create(root,true);editor.TopLevel=false;editor.FormBorderStyle=FormBorderStyle.None;editor.Dock=DockStyle.Fill;
            transient.Controls.Add(editor);editor.BringToFront();editor.Show();
        }else if(key=="Sidebar content"){
            var list=DisplayOptions.List(root);var grouped=DisplayOptions.Grouped(list);grouped.Dock=DockStyle.None;grouped.Width=Math.Max(400,body.ClientSize.Width-60);content.Controls.Add(grouped);
            text("Changes are saved automatically and applied to the overview and sidebar.");
            bool pending=false,dirty=false;
            Func<bool> flush=()=>{if(!dirty)return true;try{DisplayOptions.Save(root,DisplayOptions.Capture(list));dirty=false;return true;}catch(Exception ex){MeterTheme.Error(ex.Message);return false;}};
            list.ItemCheck+=(s,e)=>{dirty=true;if(pending)return;pending=true;BeginInvoke((Action)(()=>{pending=false;if(!list.IsDisposed)flush();}));};
            transient.Tag=flush;
        }else if(key=="Data and settings"){
            settingRow("Backup settings","Export display choices and your manually recorded subscription.",()=>SettingsTransfer.Export(root));
            settingRow("Restore settings","Select a backup and confirm before replacing your current settings.",()=>SettingsTransfer.Import(root));
            settingRow("Clear observation history","Clear local observation times only. Official usage and chats are not deleted.",()=>{if(MessageBox.Show(Locale.T("Clear local observation history?"),Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)==DialogResult.OK){System.IO.Directory.CreateDirectory(root);System.IO.File.WriteAllText(System.IO.Path.Combine(root,"clear-history.request"),"clear");Feedback(Locale.T("Clear request sent"));}});
            Action<string,ComboBox> preference=(label,picker)=>{
                var row=new Panel{Width=Math.Max(300,body.ClientSize.Width-60),Height=54,Margin=Padding.Empty};
                var caption=MeterTheme.Label(label,10,MeterTheme.Ink);caption.Dock=DockStyle.Left;caption.Width=120;row.Controls.Add(caption);
                picker.FlatStyle=FlatStyle.Flat;MeterTheme.SizeCombo(picker);picker.Anchor=AnchorStyles.Top|AnchorStyles.Right;row.Controls.Add(picker);
                using(var g=row.CreateGraphics()){float scale=g.DpiX/96f;picker.Width=(int)(170*scale);row.Height=(int)(49*scale);picker.Location=new Point(row.Width-picker.Width,(row.Height-picker.Height)/2);}
                content.Controls.Add(row);
            };
            preference("Language",Locale.Picker());
            var appearance=new ComboBox{Name="appearance",AccessibleName=Locale.T("Appearance"),DropDownStyle=ComboBoxStyle.DropDownList,Width=190};appearance.Items.AddRange(new object[]{Locale.T("System"),Locale.T("Light"),Locale.T("Dark")});appearance.SelectedIndex=MeterTheme.Mode;appearance.SelectedIndexChanged+=(s,e)=>{if(!Locale.IsTranslating&&appearance.SelectedIndex>=0)MeterTheme.SetMode(appearance.SelectedIndex);};preference("Appearance",appearance);
        }else if(key=="Diagnostics"){
            if(!String.IsNullOrEmpty(UpdateOutcome))text(UpdateOutcome);
            actionRow("Connection status","Check that Codex can chat. If the sidebar is hidden, enlarge the window before reconnecting.","Reconnect",reconnectAction);
            actionRow("Diagnostic report","Includes version, system, connection state and error codes; excludes keys, chats, accounts and paths.","Export sanitized diagnostics",()=>LocalDiagnostics.Export());
            actionRow("Issue feedback","Review the report and hide personal details in screenshots before attaching them to an issue.","Submit feedback on GitHub",()=>System.Diagnostics.Process.Start(Locale.Repository+"/issues/new"));
            text("No automatic uploads. You choose what to submit. A GitHub account is required to post an issue.");
        }else if(key=="About project"){
            text("AI Usage Monitor");text("by KEFEN");text("Local, read-only quota and Token indicators in the Codex sidebar. Choose the metrics you need; official controls always have priority.");
            var divider=new Panel{Width=Math.Max(400,body.ClientSize.Width-60),Height=1,BackColor=MeterTheme.Line,Margin=new Padding(0,6,0,14)};content.Controls.Add(divider);
            text("Author: KEFEN / License: MIT");text("Unofficial software. Not affiliated with or endorsed by OpenAI.");text("Uses the local CLI account. Token activity is not an API bill.");
            float scale;using(var g=body.CreateGraphics())scale=g.DpiX/96f;
            foreach(Control item in content.Controls)if(item is Label)item.Margin=new Padding(0,0,0,(int)(12*scale));
            var actions=new FlowLayoutPanel{Name="aboutActions",AutoSize=true,AutoSizeMode=AutoSizeMode.GrowAndShrink,WrapContents=true,Margin=new Padding(0,(int)(10*scale),0,0)};
            aboutUpdate=MeterTheme.Button("checkUpdates","Check for updates",false);aboutUpdate.SetBounds(0,0,(int)(172*scale),(int)(35*scale));aboutUpdate.Margin=new Padding(0,0,(int)(10*scale),(int)(7*scale));aboutUpdate.Click+=(s,e)=>checkUpdate("check");actions.Controls.Add(aboutUpdate);
            var github=MeterTheme.Button("projectLink","Visit GitHub project",false);github.Size=aboutUpdate.Size;github.Margin=Padding.Empty;github.Click+=(s,e)=>MeterTheme.OpenProject();actions.Controls.Add(github);content.Controls.Add(actions);
        }
        bool sizing=false;Action fit=()=>{if(sizing||content.IsDisposed)return;sizing=true;try{int width=Math.Max(0,content.ClientSize.Width-SystemInformation.VerticalScrollBarWidth-4);if(key=="Sidebar content")using(var g=content.CreateGraphics())width=Math.Min(width,(int)(900*g.DpiX/96));if(key=="About project")using(var g=content.CreateGraphics())width=Math.Min(width,(int)(720*g.DpiX/96));foreach(Control child in content.Controls){var label=child as Label;if(label!=null){label.MinimumSize=new Size(width,24);label.MaximumSize=new Size(width,0);}else if(child is FlowLayoutPanel)child.MinimumSize=new Size(width,0);else if(child is Panel)child.Width=width;}}finally{sizing=false;}};
        content.SizeChanged+=(s,e)=>fit();fit();content.PerformLayout();Locale.Apply(transient);
    }
    static Label Row(TableLayoutPanel grid,int row,string key){grid.Controls.Add(MeterTheme.Label(key,10,MeterTheme.Muted),0,row);var value=MeterTheme.Label("--",10,MeterTheme.Ink);value.Name="statusRow"+row;grid.Controls.Add(value,1,row);return value;}
    internal void Present(){Show();WindowState=FormWindowState.Normal;Activate();}
    internal void UpdateState(string stage,Dictionary<string,object> data){
        bool mounted=stage.StartsWith("mounted",StringComparison.Ordinal),failed=stage=="failed"||stage=="startup-failed"||stage=="attach-failed"||stage=="restart-cancelled";
        snapshotConnected=mounted;
        headline.Text=Locale.T(PageName(currentPage??"Usage overview"));
        headline.ForeColor=MeterTheme.Ink;
        subtitle.Text=mounted?Locale.T("Connected"):failed?Locale.T("Check Codex, then reconnect."):stage=="sidebar-missing"?Locale.T("Waiting for a supported sidebar."):Locale.T("Connecting");
        subtitle.ForeColor=mounted?MeterTheme.Tint(Color.FromArgb(25,112,90)):failed?MeterTheme.Amber:MeterTheme.Muted;
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
        connecting.Active=!mounted&&!failed;connecting.Visible=currentPage=="Usage overview"&&connecting.Active;open.Enabled=true;retry.Enabled=mounted||failed||stage=="sidebar-missing";
        retry.BackColor=MeterTheme.SoftFill;retry.ForeColor=MeterTheme.SoftInk;
        open.BackColor=MeterTheme.ActionFill;open.ForeColor=Color.White;
        AcceptButton=failed?retry:open;
        overview.ReadSnapshot(mounted);
        if(mounted&&!autoPlanAttempted){autoPlanAttempted=true;string appRoot=AppDomain.CurrentDomain.BaseDirectory;var member=MeterPreferences.Read(System.IO.Path.Combine(root,"membership.json"));bool manual=member.Count>0&&(!member.ContainsKey("planSource")||Convert.ToString(member["planSource"])!="desktop"||member.ContainsKey("manualOverride")&&Convert.ToString(member["manualOverride"])=="True");if(!manual&&System.IO.File.Exists(System.IO.Path.Combine(appRoot,"src","plan.mjs")))MeterPreferences.DetectPlan(this,appRoot,"auto",result=>{overview.ReadSnapshot(snapshotConnected);});}
        if(mounted||failed){feedbackUntil=DateTime.MinValue;if(footerMessage.Text==feedback)footerMessage.Text="";}
        else if(DateTime.UtcNow<feedbackUntil)subtitle.Text=feedback;
        Locale.Apply(this);
    }
    static string Available(Dictionary<string,object> data,string key){return data.ContainsKey(key)?Convert.ToBoolean(data[key])?Locale.T("Synced"):Locale.T("Unavailable"):"--";}
    internal void Finish(){exiting=true;Close();Dispose();}
}
