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
        Text="Codex Quota Sidebar by KEFEN";MeterTheme.Style(this,1000,710);
        body=MeterTheme.Body();Controls.Add(body);var header=MeterTheme.Header("Setup","Windows 0.12.4");Controls.Add(header);
        rail=new Panel{Dock=DockStyle.Left,Width=190,Padding=new Padding(18,28,14,20),BackColor=Color.FromArgb(246,247,249)};Controls.Add(rail);
        var list=new TableLayoutPanel{Dock=DockStyle.Top,ColumnCount=1,RowCount=4,Height=184};
        string[] names={"Environment","Install location","Display options","Install and connect"};
        for(int i=0;i<4;i++){list.RowStyles.Add(new RowStyle(SizeType.Absolute,46));steps[i]=MeterTheme.Label(names[i],10,MeterTheme.Muted);steps[i].Padding=new Padding(10,0,0,0);list.Controls.Add(steps[i]);}rail.Controls.Add(list);
        var version=MeterTheme.Label("v0.12.4",8,MeterTheme.Muted);version.Dock=DockStyle.Bottom;version.Height=26;rail.Controls.Add(version);
        var github=new LinkLabel{Text="About project",Dock=DockStyle.Bottom,Height=36,LinkColor=MeterTheme.Blue,LinkBehavior=LinkBehavior.HoverUnderline};github.LinkClicked+=(s,e)=>System.Diagnostics.Process.Start(Locale.Repository);rail.Controls.Add(github);github.BringToFront();
        var top=new Panel{Dock=DockStyle.Top,Height=88};title=MeterTheme.Label("",18,MeterTheme.Ink);title.Dock=DockStyle.Top;title.Height=40;
        detail=MeterTheme.Label("",10,MeterTheme.Muted);detail.Dock=DockStyle.Top;detail.Height=40;top.Controls.Add(detail);top.Controls.Add(title);body.Controls.Add(top);
        content=new Panel{Dock=DockStyle.Fill,AutoScroll=true};body.Controls.Add(content);content.BringToFront();
        var footer=MeterTheme.Footer();Controls.Add(footer);body.BringToFront();Controls.SetChildIndex(header,Controls.Count-1);
        install=MeterTheme.Button("install","Continue",true);install.Width=180;back=MeterTheme.Button("back","Back",false);close=MeterTheme.Button("cancel","Cancel",false);
        footer.Controls.Add(install);footer.Controls.Add(back);footer.Controls.Add(close);
        progress=new ProgressBar{Dock=DockStyle.Bottom,Height=4,Style=ProgressBarStyle.Marquee,Visible=false};body.Controls.Add(progress);content.BringToFront();
        install.Click+=(s,e)=>Next();back.Click+=(s,e)=>{error="";if(step==2)SelectedVisibility=DisplayOptions.Capture(choices);step=Math.Max(0,step-1);Render();};
        close.Click+=(s,e)=>Close();FormClosing+=(s,e)=>{if(busy)e.Cancel=true;};CancelButton=close;AcceptButton=install;Shown+=(s,e)=>CheckEnvironment();Render();
    }
    void Note(string text,int height){var label=MeterTheme.Label(text,10,MeterTheme.Muted);label.Dock=DockStyle.Top;label.Height=height;content.Controls.Add(label);label.BringToFront();}
    void Render(){
        while(content.Controls.Count>0){var c=content.Controls[0];content.Controls.Remove(c);c.Dispose();}
        for(int i=0;i<4;i++){steps[i].BackColor=i==step?Color.FromArgb(232,239,252):rail.BackColor;steps[i].ForeColor=i==step?MeterTheme.Green:MeterTheme.Muted;}
        back.Visible=step>0&&step<3;close.Text=complete?"Close":"Cancel";install.Enabled=back.Enabled=close.Enabled=!busy;title.ForeColor=failed?MeterTheme.Amber:MeterTheme.Ink;progress.Visible=busy;
        if(step==0){
            title.Text=environmentReady?"Environment ready":"Checking environment";detail.Text="Official Microsoft Store Codex is required.";
            install.Text=environmentReady?"Continue":"Check again";
            Note(environmentReady?"01 / Codex was found. The meter installs separately.":"Checking the current user's Codex installation.",52);
            Note("02 / Run as a normal user. Administrator privileges are not required.",52);
            Note("03 / No sign-up or purchase for this tool. Records are optional.",52);
        }else if(step==1){
            title.Text="Select install location";detail.Text="Upgrade in the original folder to preserve your settings.";install.Text="Check and continue";
            var actions=new FlowLayoutPanel{Dock=DockStyle.Top,Height=82,Padding=new Padding(0,18,0,18),WrapContents=false};
            var browse=MeterTheme.Button("browse","Browse...",false);var reset=MeterTheme.Button("recommended","Recommended location",false);reset.Width=205;
            browse.Margin=reset.Margin=new Padding(0,0,16,0);browse.Height=reset.Height=38;
            actions.Controls.Add(browse);actions.Controls.Add(reset);content.Controls.Add(actions);
            path=new TextBox{Name="destination",Text=Destination,Dock=DockStyle.Top};content.Controls.Add(path);
            var label=MeterTheme.Label("Install folder",10,MeterTheme.Ink);label.Dock=DockStyle.Top;label.Height=30;content.Controls.Add(label);
            browse.Click+=(s,e)=>{using(var picker=new FolderBrowserDialog{Description=Locale.T("Select install location"),SelectedPath=path.Text})if(picker.ShowDialog(this)==DialogResult.OK)path.Text=picker.SelectedPath;};reset.Click+=(s,e)=>path.Text=original;
            var note=MeterTheme.Label("The same disk as Codex is convenient, not required. Do not use WindowsApps.",10,MeterTheme.Muted);note.Dock=DockStyle.Bottom;note.Height=65;content.Controls.Add(note);
            if(SetupSupport.Owned(Destination)&&SetupSupport.IsRunning(Destination)){
                var row=new FlowLayoutPanel{Dock=DockStyle.Top,Height=120,Padding=new Padding(0,18,0,8),FlowDirection=FlowDirection.TopDown,WrapContents=false};var info=MeterTheme.Label("Exit the old meter, then continue. Codex stays open.",9,MeterTheme.Muted);info.Dock=DockStyle.None;info.Width=650;info.Height=32;info.Margin=new Padding(0,0,0,12);row.Controls.Add(info);
                var stop=MeterTheme.Button("stopOld","Exit old meter",false);stop.Width=170;row.Controls.Add(stop);content.Controls.Add(row);row.BringToFront();
                stop.Click+=(s,e)=>{if(MessageBox.Show(Locale.T("Quit the meter? Codex stays open."),Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)==DialogResult.OK)Run(()=>SetupSupport.StopOwned(Destination),()=>{error="Old meter stopped. Codex stays open.";Render();});};
            }
        }else if(step==2){
            title.Text="Choose sidebar content";detail.Text="You can change these options later in Settings.";install.Text="Install";
            choices=DisplayOptions.List(Path.Combine(Destination,".runtime"));if(SelectedVisibility!=null)for(int i=0;i<DisplayOptions.Keys.Length;i++)choices.SetItemChecked(i,SelectedVisibility[DisplayOptions.Keys[i]]);
            content.Controls.Add(DisplayOptions.Grouped(choices));
        }else{
            title.Text=complete?"Installed. Connect next.":failed?"Installation incomplete":"Installing";
            detail.Text=complete?"Installed files are ready. Codex is not connected yet.":"Verifying files and creating your shortcut.";
            install.Text=complete?"Connect Codex":"Reinstall";
            Note("1. Files installed. Your existing settings are preserved when upgrading.",38);
            Note(Destination,56);
            Note("2. Save your work before connecting. Restarting Codex requires your permission.",58);
            if(complete&&configure!=null){
                Note("3. Subscription records are optional. You can set them later.",42);
                var optionalRow=new Panel{Dock=DockStyle.Top,Height=64,Padding=new Padding(0,12,0,12)};
                var prefs=MeterTheme.Button("membership","Optional: record your Codex subscription",false);prefs.Width=360;prefs.Dock=DockStyle.Left;prefs.Click+=(s,e)=>configure();optionalRow.Controls.Add(prefs);content.Controls.Add(optionalRow);optionalRow.BringToFront();
            }
            if(failed){back.Visible=true;back.Enabled=true;}
        }
        if(!String.IsNullOrEmpty(error)){var notice=new TextBox{Name="setupError",Text=error,ReadOnly=true,Multiline=true,ScrollBars=ScrollBars.Vertical,BorderStyle=BorderStyle.None,ForeColor=MeterTheme.Amber,BackColor=MeterTheme.Surface,Dock=DockStyle.Bottom,Height=76};content.Controls.Add(notice);notice.BringToFront();}
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
