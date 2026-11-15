using System;
using System.ComponentModel;
using System.Drawing;
using System.Windows.Forms;

internal sealed class SetupWindow : Form {
    readonly Label title,detail;
    readonly ProgressBar progress;
    readonly Button install,close;
    readonly Action operation,launch;
    bool busy,complete;
    readonly CheckedListBox choices;
    internal System.Collections.Generic.Dictionary<string,bool> SelectedVisibility;
    internal SetupWindow(string destination,Action operation,Action launch){
        this.operation=operation;this.launch=launch;Text="Codex Quota Sidebar";MeterTheme.Style(this,660,650);
        var body=MeterTheme.Body();Controls.Add(body);Controls.Add(MeterTheme.Header("\u5b89\u88c5","Windows 0.9.3-beta.1"));
        title=MeterTheme.Label("\u51c6\u5907\u5b89\u88c5",21,MeterTheme.Ink);title.Dock=DockStyle.Top;title.Height=50;
        detail=MeterTheme.Label("\u8bf7\u5148\u4ece\u6258\u76d8\u505c\u6b62\u65e7\u7248\u9762\u677f\u3002\n\n\u5b89\u88c5\u4f4d\u7f6e\n"+destination+"\n\n\u975e OpenAI \u5b98\u65b9\u5de5\u5177\uff0c\u4e0d\u4fee\u6539 Codex \u5b89\u88c5\u6587\u4ef6\u3002",10,MeterTheme.Muted);detail.Dock=DockStyle.Top;detail.Height=200;
        progress=new ProgressBar{Dock=DockStyle.Top,Height=5,Style=ProgressBarStyle.Marquee,Visible=false};
        body.Controls.Add(progress);body.Controls.Add(detail);body.Controls.Add(title);
        detail.Height=150;choices=DisplayOptions.List(System.IO.Path.Combine(destination,".runtime"));body.Controls.Add(choices);choices.BringToFront();
        var footer=MeterTheme.Footer();Controls.Add(footer);body.BringToFront();
        install=MeterTheme.Button("install","\u5b89\u88c5",true);close=MeterTheme.Button("cancel","\u53d6\u6d88",false);
        footer.Controls.Add(install);footer.Controls.Add(close);close.Click+=(s,e)=>Close();
        install.Click+=(s,e)=>{if(complete){try{launch();Close();}catch(Exception ex){MeterTheme.Error(ex.Message);}return;}BeginInstall();};
        FormClosing+=(s,e)=>{if(busy)e.Cancel=true;};CancelButton=close;AcceptButton=install;
    }
    void BeginInstall(){
        SelectedVisibility=DisplayOptions.Capture(choices);choices.Enabled=false;
        busy=true;install.Enabled=false;close.Enabled=false;progress.Visible=true;title.Text="\u6b63\u5728\u5b89\u88c5";
        var worker=new BackgroundWorker();worker.DoWork+=(s,e)=>operation();
        worker.RunWorkerCompleted+=(s,e)=>{
            Action finish=()=>{
            busy=false;progress.Visible=false;install.Enabled=true;close.Enabled=true;choices.Enabled=e.Error!=null;
            complete=e.Error==null;title.Text=complete?"\u5b89\u88c5\u5b8c\u6210":"\u5b89\u88c5\u672a\u5b8c\u6210";title.ForeColor=complete?MeterTheme.Green:MeterTheme.Amber;
            detail.Text=complete?"Codex Quota Sidebar \u5df2\u5b89\u88c5\u3002\n\n\u9996\u6b21\u542f\u52a8\u65f6\u8bf7\u786e\u8ba4\u672c\u673a\u8fde\u63a5\u6388\u6743\u3002":"\u672a\u5b8c\u6210\u5b89\u88c5\uff0c\u8bf7\u68c0\u67e5\u540e\u91cd\u8bd5\u3002\n\n"+e.Error.Message;
            install.Text=complete?"\u542f\u52a8":"\u91cd\u8bd5";close.Text="\u5173\u95ed";worker.Dispose();
            };
            if(IsDisposed){worker.Dispose();return;}
            if(InvokeRequired)BeginInvoke(finish);else finish();
        };worker.RunWorkerAsync();
    }
}
