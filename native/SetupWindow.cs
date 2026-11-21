using System;
using System.ComponentModel;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
internal sealed class SetupWindow : Form {
    readonly Panel body,content,rail;
    readonly Label title,detail;
    readonly ProgressBar progress;
    readonly Button install,back,close;
    readonly Label[] steps=new Label[4];
    readonly Action operation,launch,configure;
    readonly Func<string> detect;
    readonly string original;
    bool busy,environmentReady,complete,failed;
    int step;
    string codexLocation="",error="";
    TextBox path;
    CheckedListBox choices;
    internal string Destination {get;private set;}
    internal System.Collections.Generic.Dictionary<string,bool> SelectedVisibility;
    internal SetupWindow(string destination,Action operation,Action launch,Func<string> detect=null,Action configure=null){
        original=Destination=destination;this.operation=operation;this.launch=launch;this.configure=configure;this.detect=detect??SetupSupport.FindCodex;
        Text="AI Quota Board";MeterTheme.Style(this,1016,536);
        MinimumSize=new Size(720,460);
        var header=MeterTheme.Header("Setup","Windows "+MeterTheme.Version);header.Height=68;header.Padding=new Padding(20,12,20,12);
        var logo=header.Controls.Find("brandLogo",true)[0];logo.Cursor=Cursors.Hand;logo.TabStop=true;logo.AccessibleName=Locale.T("Visit GitHub project");logo.Click+=(s,e)=>MeterTheme.OpenProject();
        var footer=new Panel{Dock=DockStyle.Bottom,Height=53,Padding=new Padding(16,8,16,8),BackColor=MeterTheme.Tint(Color.FromArgb(248,250,253))};
        var split=new Panel{Dock=DockStyle.Fill};Controls.Add(split);Controls.Add(footer);Controls.Add(header);
        body=MeterTheme.Body();body.Padding=new Padding(24,14,24,10);split.Controls.Add(body);
        rail=new Panel{Dock=DockStyle.Left,Width=178,Padding=new Padding(10,20,10,12),BackColor=MeterTheme.Tint(Color.FromArgb(243,246,251))};split.Controls.Add(rail);
        var list=new TableLayoutPanel{Dock=DockStyle.Top,ColumnCount=1,RowCount=4,Height=172};
        string[] names={"Environment","Install location","Display options","Install and connect"};
        for(int i=0;i<4;i++){list.RowStyles.Add(new RowStyle(SizeType.Percent,25));steps[i]=new SetupStep(i+1){Text=names[i],Font=MeterTheme.Font(9.5f),Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleLeft,Padding=new Padding(36,0,0,0),Margin=new Padding(0,0,0,5)};list.Controls.Add(steps[i]);}rail.Controls.Add(list);
        var about=new NavigationItem{Name="setupAbout",Text="About project",Glyph="\uE946",Dock=DockStyle.Bottom,Height=36,Font=MeterTheme.Font(9.25f),ForeColor=MeterTheme.Muted,BackColor=rail.BackColor};
        about.Click+=(s,e)=>MeterTheme.OpenProject();rail.Controls.Add(about);
        var top=new Panel{Dock=DockStyle.Top,Height=76};title=MeterTheme.Label("",16.5f,MeterTheme.Ink);title.Dock=DockStyle.Top;title.Height=36;
        detail=MeterTheme.Label("",9.5f,MeterTheme.Muted);detail.Dock=DockStyle.Fill;top.Controls.Add(detail);top.Controls.Add(title);
        content=new Panel{Dock=DockStyle.Fill,AutoScroll=true};body.Controls.Add(content);body.Controls.Add(top);
        install=MeterTheme.Button("install","Continue",true);install.Width=166;back=MeterTheme.Button("back","Back",false);close=MeterTheme.Button("cancel","Cancel",false);
        install.EnabledChanged+=(s,e)=>{install.BackColor=install.Enabled?MeterTheme.ActionFill:SystemColors.Control;install.FlatAppearance.BorderColor=install.Enabled?MeterTheme.ActionFill:MeterTheme.Line;};
        var actions=new FlowLayoutPanel{Dock=DockStyle.Right,AutoSize=true,WrapContents=false,AutoSizeMode=AutoSizeMode.GrowAndShrink};
        foreach(var b in new[]{close,back,install}){b.Height=34;b.Margin=new Padding(8,0,0,0);actions.Controls.Add(b);}
        var build=MeterTheme.Label("Windows "+MeterTheme.Version,8.5f,MeterTheme.Muted);footer.Controls.Add(build);footer.Controls.Add(actions);
        Load+=(s,e)=>{var work=Screen.FromControl(this).WorkingArea;MinimumSize=new Size(Math.Min(MinimumSize.Width,work.Width),Math.Min(MinimumSize.Height,work.Height));Size=new Size(Math.Min(Width,work.Width),Math.Min(Height,work.Height));CenterToScreen();};
        progress=new ProgressBar{Dock=DockStyle.Bottom,Height=4,Style=ProgressBarStyle.Marquee,Visible=false};body.Controls.Add(progress);content.BringToFront();
        install.Click+=(s,e)=>Next();back.Click+=(s,e)=>{error="";if(step==2)SelectedVisibility=DisplayOptions.Capture(choices);step=Math.Max(0,step-1);Render();};
        close.Click+=(s,e)=>Close();FormClosing+=(s,e)=>{if(busy)e.Cancel=true;};CancelButton=close;AcceptButton=install;Shown+=(s,e)=>{Render();CheckEnvironment();};
    }
    int Px(int value){using(var g=CreateGraphics())return (int)Math.Round(value*g.DpiX/96);}
    void Append(Control c){c.Dock=DockStyle.Top;content.Controls.Add(c);c.BringToFront();}
    void Note(string text,int height){var label=MeterTheme.Label(text,9.5f,MeterTheme.Muted);label.Height=Px(height);Append(label);}
    void Fact(string key,string value,bool emphasized=false){
        var row=new Panel{Height=Px(43)};
        var caption=MeterTheme.Label(key,9.5f,MeterTheme.Muted);caption.Dock=DockStyle.Left;caption.Width=Px(128);
        var result=MeterTheme.Label(value,10,emphasized?MeterTheme.Blue:MeterTheme.Ink);
        row.Controls.Add(result);row.Controls.Add(caption);row.Paint+=(s,e)=>{using(var pen=new Pen(MeterTheme.Line))e.Graphics.DrawLine(pen,0,row.Height-1,row.Width,row.Height-1);};Append(row);
    }
    void Render(){
        while(content.Controls.Count>0){var c=content.Controls[0];content.Controls.Remove(c);c.Dispose();}
        for(int i=0;i<4;i++){((SetupStep)steps[i]).Done=i<step||complete;steps[i].BackColor=i==step?MeterTheme.Tint(Color.FromArgb(228,237,253)):rail.BackColor;steps[i].ForeColor=i==step?MeterTheme.Blue:MeterTheme.Muted;steps[i].Invalidate();}
        back.Visible=step>0&&step<3;close.Text=complete?"Close":"Cancel";install.Enabled=back.Enabled=close.Enabled=!busy;title.ForeColor=failed?MeterTheme.Amber:MeterTheme.Ink;progress.Visible=busy;
        if(step==0){
            title.Text=environmentReady?"Ready to set up":String.IsNullOrEmpty(error)?"Checking environment":"Environment check failed";detail.Text=environmentReady?"Codex was found. The meter installs separately.":"Official Microsoft Store Codex is required.";
            install.Text=environmentReady?"Continue":"Check again";
            Fact("Codex",environmentReady?"Official Codex client found":String.IsNullOrEmpty(error)?"Checking environment":"Not found",true);
            Fact("Permissions","Administrator privileges are not required");
            Fact("Upgrade","Existing settings will be preserved");
            Fact("Account","No account or purchase is required for this tool");
        }else if(step==1){
            title.Text="Select install location";detail.Text="Upgrade in the original folder to preserve your settings.";install.Text="Check and continue";
            Note("Install folder",32);
            path=new TextBox{Name="destination",Text=Destination,AccessibleName=Locale.T("Install folder")};Append(path);
            var actions=new FlowLayoutPanel{Height=Px(56),Padding=new Padding(0,Px(10),0,0),WrapContents=false};
            var browse=MeterTheme.Button("browse","Browse...",false);var reset=MeterTheme.Button("recommended","Recommended location",false);
            foreach(var b in new[]{browse,reset}){b.Size=new Size(Px(b==browse?104:180),Px(33));b.Margin=new Padding(0,0,Px(8),0);actions.Controls.Add(b);}Append(actions);
            browse.Click+=(s,e)=>{using(var picker=new FolderBrowserDialog{Description=Locale.T("Select install location"),SelectedPath=path.Text})if(picker.ShowDialog(this)==DialogResult.OK)path.Text=picker.SelectedPath;};reset.Click+=(s,e)=>path.Text=original;
            Note("The same disk as Codex is convenient, not required. Do not use WindowsApps.",48);
            if(SetupSupport.Owned(Destination)&&SetupSupport.IsRunning(Destination)){
                Note("Exit the old meter, then continue. Codex stays open.",40);
                var row=new FlowLayoutPanel{Height=Px(42),WrapContents=false};var stop=MeterTheme.Button("stopOld","Exit old meter",false);stop.Size=new Size(Px(170),Px(34));stop.Margin=Padding.Empty;row.Controls.Add(stop);Append(row);
                stop.Click+=(s,e)=>{if(MessageBox.Show(Locale.T("Quit the meter? Codex stays open."),Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)==DialogResult.OK)Run(()=>SetupSupport.StopOwned(Destination),()=>{error="Old meter stopped. Codex stays open.";Render();});};
            }
        }else if(step==2){
            title.Text="Choose sidebar content";detail.Text="You can change these options later in Settings.";install.Text="Install";
            choices=DisplayOptions.List(Path.Combine(Destination,".runtime"));if(SelectedVisibility!=null)for(int i=0;i<DisplayOptions.Keys.Length;i++)choices.SetItemChecked(i,SelectedVisibility[DisplayOptions.Keys[i]]);
            Append(DisplayOptions.Grouped(choices));
        }else{
            title.Text=complete?"Installed. Connect next.":failed?"Installation incomplete":"Installing";
            detail.Text=complete?"Installed files are ready. Codex is not connected yet.":failed?"Check the installation details before retrying.":"Verifying files and creating your shortcut.";
            install.Text=complete?"Connect Codex":failed?"Reinstall":"Installing";
            Note("Install folder",32);
            var folder=new TextBox{Name="installSummaryPath",ReadOnly=true,Multiline=true,WordWrap=true,BorderStyle=BorderStyle.None,Text=Destination,AccessibleName=Locale.T("Install folder"),BackColor=MeterTheme.Surface};Append(folder);
            Action fitPath=()=>{int h=TextRenderer.MeasureText(folder.Text,folder.Font,new Size(Math.Max(1,folder.ClientSize.Width),Int32.MaxValue),TextFormatFlags.TextBoxControl|TextFormatFlags.WordBreak|TextFormatFlags.NoPrefix).Height;
                int target=Math.Min(Px(82),Math.Max(folder.Font.Height*2,h+Px(6)));if(folder.Height!=target)folder.Height=target;folder.ScrollBars=h>target?ScrollBars.Vertical:ScrollBars.None;};
            folder.SizeChanged+=(s,e)=>fitPath();fitPath();
            if(complete){
                Note("Save your work before connecting. Restarting Codex requires your permission.",56);
                if(configure!=null){
                    var prefs=MeterTheme.Button("membership","Optional: record your Codex subscription",false);prefs.Height=Px(34);prefs.Margin=Padding.Empty;prefs.Click+=(s,e)=>configure();
                    Action fitPrefs=()=>prefs.Width=TextRenderer.MeasureText(prefs.Text,prefs.Font).Width+Px(24);prefs.TextChanged+=(s,e)=>fitPrefs();fitPrefs();
                    var row=new FlowLayoutPanel{Height=Px(44),WrapContents=false};row.Controls.Add(prefs);Append(row);
                }
            }
            if(failed){back.Visible=true;back.Enabled=true;}
        }
        if(!String.IsNullOrEmpty(error)){var notice=new TextBox{Name="setupError",Text=error,ReadOnly=true,Multiline=true,ScrollBars=ScrollBars.Vertical,BorderStyle=BorderStyle.None,ForeColor=MeterTheme.Amber,BackColor=MeterTheme.Tint(Color.FromArgb(255,249,238)),Height=Px(48)};Append(notice);}
        Locale.Apply(this);
    }
    void Next(){
        if(busy)return;
        if(complete){try{launch();Close();}catch(Exception ex){error=ex.Message;Render();}return;}
        if(step==0){if(environmentReady){step=1;error="";Render();}else CheckEnvironment();return;}
        if(step==1){try{string next=SetupSupport.ValidateDestination(path.Text);if(next!=Destination)SelectedVisibility=null;Destination=next;if(SetupSupport.IsRunning(Destination)){error="Exit the old meter, then continue. Codex stays open.";Render();return;}step=2;error="";Render();}catch(Exception ex){error=SetupSupport.FriendlyError(ex.Message);Destination=path.Text;Render();}return;}
        if(step==2)SelectedVisibility=DisplayOptions.Capture(choices);
        step=3;failed=false;error="";Render();Run(()=>{SetupSupport.ValidateDestination(Destination);if(SetupSupport.IsRunning(Destination))throw new IOException("Stop the existing meter before upgrading");operation();},()=>{complete=true;Render();});
    }
    void CheckEnvironment(){error="";Run(()=>{codexLocation=detect();if(String.IsNullOrWhiteSpace(codexLocation))throw new IOException("Official Microsoft Store Codex is required.");},()=>{environmentReady=true;Render();});}
    void Run(Action work,Action done){
        busy=true;install.Enabled=back.Enabled=close.Enabled=false;content.Enabled=false;progress.Visible=true;
        var worker=new BackgroundWorker();worker.DoWork+=(s,e)=>work();worker.RunWorkerCompleted+=(s,e)=>{Action finish=()=>{busy=false;content.Enabled=true;progress.Visible=false;if(e.Error!=null){failed=step==3;error=SetupSupport.FriendlyError(e.Error.Message);Render();}else done();worker.Dispose();};if(IsDisposed){worker.Dispose();return;}if(InvokeRequired)BeginInvoke(finish);else finish();};worker.RunWorkerAsync();
    }
}

internal sealed class SetupStep : Label {
    readonly int number;
    internal bool Done;
    internal SetupStep(int number){this.number=number;}
    protected override void OnPaint(PaintEventArgs e){
        base.OnPaint(e);float scale=e.Graphics.DpiX/96f;int d=(int)(20*scale),x=(int)(8*scale),y=(Height-d)/2;
        e.Graphics.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        using(var pen=new Pen(ForeColor))e.Graphics.DrawEllipse(pen,x,y,d,d);
        using(var font=MeterTheme.Font(8.5f))TextRenderer.DrawText(e.Graphics,Done?"\u2713":number.ToString(),font,new Rectangle(x,y,d,d),ForeColor,TextFormatFlags.NoPadding|TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);
    }
}
