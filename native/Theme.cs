using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

internal static class MeterTheme {
    internal static void Saved(Button button){
        button.Text=Locale.T("Saved successfully");button.BackColor=Surface;button.ForeColor=Blue;button.FlatAppearance.BorderColor=Blue;button.Enabled=false;
        var timer=new Timer{Interval=1400};
        timer.Tick+=(s,e)=>{timer.Stop();timer.Dispose();if(button.IsDisposed)return;button.Text=Locale.T("Save");button.BackColor=Blue;button.ForeColor=Color.White;button.Enabled=true;};
        button.Disposed+=(s,e)=>{timer.Stop();timer.Dispose();};timer.Start();
    }
    internal static readonly Color Ink=SystemInformation.HighContrast?SystemColors.WindowText:Color.FromArgb(33,40,50);
    internal static readonly Color Muted=SystemInformation.HighContrast?SystemColors.WindowText:Color.FromArgb(99,109,122);
    internal static readonly Color Surface=SystemInformation.HighContrast?SystemColors.Window:Color.White;
    internal static readonly Color Line=SystemInformation.HighContrast?SystemColors.WindowText:Color.FromArgb(224,229,236);
    internal static readonly Color Green=SystemInformation.HighContrast?SystemColors.Highlight:Color.FromArgb(40,100,215);
    internal static readonly Color Blue=SystemInformation.HighContrast?SystemColors.Highlight:Color.FromArgb(44,103,168);
    internal static readonly Color Amber=SystemInformation.HighContrast?SystemColors.WindowText:Color.FromArgb(141,86,16);
    internal static Font Font(float size){return new Font("Segoe UI",size,FontStyle.Regular);}
    internal static string Asset(string name){string root=Path.GetDirectoryName(typeof(MeterTheme).Assembly.Location);string p=Path.Combine(root,"assets",name);return File.Exists(p)?p:Path.Combine(root,"..","assets",name);}
    internal static Icon AppIcon(){try{return new Icon(Asset("cqs.ico"));}catch{return Icon.ExtractAssociatedIcon(Application.ExecutablePath)??(Icon)SystemIcons.Application.Clone();}}
    internal static Icon TrayIcon(){
        bool light=false;
        try{using(var key=Microsoft.Win32.Registry.CurrentUser.OpenSubKey("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize")){light=key!=null&&Convert.ToInt32(key.GetValue("SystemUsesLightTheme",0))==1;}}catch{}
        try{return new Icon(Asset(light?"tray-light.ico":"tray-dark.ico"));}catch{return AppIcon();}
    }
    internal static void Style(Form form,int width,int height){
        form.Font=Font(10);form.ForeColor=Ink;form.BackColor=Surface;form.Icon=AppIcon();
        form.AutoScaleDimensions=new SizeF(96,96);form.AutoScaleMode=AutoScaleMode.Dpi;form.ClientSize=new Size(width,height);
        form.FormBorderStyle=FormBorderStyle.FixedDialog;form.MaximizeBox=false;form.StartPosition=FormStartPosition.CenterScreen;
        form.Shown+=(s,e)=>Locale.Apply(form);
    }
    internal static Label Label(string text,float size,Color color){return new Label{Text=text,Font=Font(size),ForeColor=color,AutoSize=false,TextAlign=ContentAlignment.MiddleLeft,Dock=DockStyle.Fill,UseMnemonic=false};}
    internal static Panel Header(string section,string version){
        var panel=new Panel{Dock=DockStyle.Top,Height=78,Padding=new Padding(24,15,24,12),BackColor=Surface};
        var icon=new PictureBox{Dock=DockStyle.Left,Width=40,SizeMode=PictureBoxSizeMode.Zoom};
        try{using(var source=Image.FromFile(Asset("cqs-128.png")))icon.Image=new Bitmap(source);}catch{using(var stream=System.Reflection.Assembly.GetExecutingAssembly().GetManifestResourceStream("brand.png")){if(stream!=null)using(var source=Image.FromStream(stream))icon.Image=new Bitmap(source);}}
        var words=new Panel{Dock=DockStyle.Fill,Padding=new Padding(16,0,0,0)};
        var title=Label("Codex Quota Sidebar",14,Ink);title.Dock=DockStyle.Top;title.Height=27;
        var caption=Label(String.IsNullOrEmpty(section)?"by KEFEN":"by KEFEN  /  "+section,9,Muted);caption.Name="brandCaption";caption.Dock=DockStyle.Top;caption.Height=22;
        words.Controls.Add(caption);words.Controls.Add(title);panel.Controls.Add(words);panel.Controls.Add(icon);
        var language=Locale.Picker();language.Dock=DockStyle.Right;panel.Controls.Add(language);words.BringToFront();
        panel.Paint+=(s,e)=>{using(var pen=new Pen(Line))e.Graphics.DrawLine(pen,24,panel.Height-1,panel.Width-24,panel.Height-1);};
        panel.Disposed+=(s,e)=>{if(icon.Image!=null)icon.Image.Dispose();};return panel;
    }
    internal static Button Button(string name,string label,bool primary){
        var b=new Button{Name=name,Text=label,Width=110,Height=36,FlatStyle=FlatStyle.Flat,Font=Font(10),Margin=new Padding(8,0,0,0),Cursor=Cursors.Hand,UseVisualStyleBackColor=false,BackColor=primary?Green:Surface,ForeColor=primary?Color.White:Ink};
        b.FlatAppearance.BorderColor=primary?Green:Line;b.FlatAppearance.BorderSize=1;
        b.FlatAppearance.MouseOverBackColor=primary?Color.FromArgb(30,85,192):Color.FromArgb(240,245,252);return b;
    }
    internal static FlowLayoutPanel Footer(){return new FlowLayoutPanel{Dock=DockStyle.Bottom,Height=70,Padding=new Padding(16,16,24,18),FlowDirection=FlowDirection.RightToLeft,WrapContents=false,BackColor=Surface};}
    internal static Panel Body(){return new Panel{Dock=DockStyle.Fill,Padding=new Padding(24,18,24,16),AutoScroll=true,BackColor=Surface};}
    internal static bool Consent(){
        using(var form=new Form()){
            form.Text="Codex Quota Sidebar";Style(form,620,470);form.MinimizeBox=false;
            var body=Body();form.Controls.Add(body);form.Controls.Add(Header(Locale.T("Local connection permission"),"Windows"));
            var title=Label(Locale.T("Allow local debugging"),17,Ink);title.Dock=DockStyle.Top;title.Height=44;
            var notice=Label(Locale.T("Debugging grants more than quota access. Other local programs may access the port. Stopping the meter does not close it: fully quit Codex and reopen from its official entry. This is unofficial software. Verify that the CLI and desktop accounts match."),10,Muted);notice.Dock=DockStyle.Top;notice.Height=190;
            var accept=new CheckBox{Name="consentAccepted",Text=Locale.T("I understand the risks and trust this computer"),Dock=DockStyle.Top,Height=42,AutoSize=false};
            body.Controls.Add(accept);body.Controls.Add(notice);body.Controls.Add(title);
            var footer=Footer();var yes=Button("confirm",Locale.T("Agree and continue"),true);yes.Enabled=false;yes.DialogResult=DialogResult.OK;
            var no=Button("cancel",Locale.T("Cancel"),false);no.DialogResult=DialogResult.Cancel;footer.Controls.Add(yes);footer.Controls.Add(no);form.Controls.Add(footer);body.BringToFront();
            accept.CheckedChanged+=(s,e)=>yes.Enabled=accept.Checked;form.CancelButton=no;form.AcceptButton=no;
            return form.ShowDialog()==DialogResult.OK&&accept.Checked;
        }
    }
    internal static void Error(string text){
        using(var form=new Form()){
            form.Text="Codex Quota Sidebar";Style(form,620,330);
            var body=Body();form.Controls.Add(body);form.Controls.Add(Header(Locale.T("Action needed"),"Windows"));
            body.Controls.Add(new TextBox{Text=text,ReadOnly=true,Multiline=true,Dock=DockStyle.Fill,BorderStyle=BorderStyle.None,BackColor=Surface,ForeColor=Ink,ScrollBars=ScrollBars.Vertical});
            var footer=Footer();var close=Button("close",Locale.T("Close"),true);close.DialogResult=DialogResult.OK;footer.Controls.Add(close);form.Controls.Add(footer);body.BringToFront();form.CancelButton=close;form.ShowDialog();
        }
    }
}

public static class MeterRestartDialog {
    public static bool Confirm(string question){
        Application.EnableVisualStyles();
        Locale.Load(Path.Combine(Path.GetDirectoryName(typeof(MeterRestartDialog).Assembly.Location),".runtime"));
        using(var form=new Form()){
            form.Text="Codex Quota Sidebar";MeterTheme.Style(form,660,460);
            var body=MeterTheme.Body();form.Controls.Add(body);form.Controls.Add(MeterTheme.Header(Locale.T("Restart confirmation"),"Windows"));
            var steps=new FlowLayoutPanel{Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,AutoScroll=true};body.Controls.Add(steps);
            foreach(string key in new[]{"1. Codex is running without the required local connection.","2. Save all work and stop active tasks before continuing.","3. With your permission, verified Codex processes will restart to attach the sidebar.","4. Unsaved work may be lost. Cancel to leave Codex unchanged."}){
                var item=MeterTheme.Label(Locale.T(key),10,MeterTheme.Ink);item.Dock=DockStyle.None;item.Width=580;item.Height=52;item.Margin=new Padding(0,0,0,12);steps.Controls.Add(item);
            }
            var footer=MeterTheme.Footer();var yes=MeterTheme.Button("restartConfirm",Locale.T("Saved my work, restart"),true);yes.Width=270;yes.DialogResult=DialogResult.OK;
            var no=MeterTheme.Button("cancel",Locale.T("Cancel"),false);no.DialogResult=DialogResult.Cancel;
            footer.Controls.Add(yes);footer.Controls.Add(no);form.Controls.Add(footer);body.BringToFront();form.AcceptButton=no;form.CancelButton=no;
            return form.ShowDialog()==DialogResult.OK;
        }
    }
}
