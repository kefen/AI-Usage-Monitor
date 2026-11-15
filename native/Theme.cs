using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

internal static class MeterTheme {
    internal static readonly Color Ink=SystemInformation.HighContrast?SystemColors.WindowText:Color.FromArgb(30,38,34);
    internal static readonly Color Muted=SystemInformation.HighContrast?SystemColors.WindowText:Color.FromArgb(91,103,96);
    internal static readonly Color Surface=SystemInformation.HighContrast?SystemColors.Window:Color.White;
    internal static readonly Color Line=SystemInformation.HighContrast?SystemColors.WindowText:Color.FromArgb(221,228,223);
    internal static readonly Color Green=SystemInformation.HighContrast?SystemColors.Highlight:Color.FromArgb(40,100,215);
    internal static readonly Color Blue=SystemInformation.HighContrast?SystemColors.Highlight:Color.FromArgb(44,103,168);
    internal static readonly Color Amber=SystemInformation.HighContrast?SystemColors.WindowText:Color.FromArgb(141,86,16);
    internal static Font Font(float size){return new Font("Microsoft YaHei UI",size,FontStyle.Regular);}
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
    }
    internal static Label Label(string text,float size,Color color){return new Label{Text=text,Font=Font(size),ForeColor=color,AutoSize=false,TextAlign=ContentAlignment.MiddleLeft,Dock=DockStyle.Fill,UseMnemonic=false};}
    internal static Panel Header(string section,string version){
        var panel=new Panel{Dock=DockStyle.Top,Height=92,Padding=new Padding(24,20,24,16),BackColor=Surface};
        var icon=new PictureBox{Dock=DockStyle.Left,Width=48,SizeMode=PictureBoxSizeMode.Zoom};
        try{using(var source=Image.FromFile(Asset("cqs-128.png")))icon.Image=new Bitmap(source);}catch{using(var stream=System.Reflection.Assembly.GetExecutingAssembly().GetManifestResourceStream("brand.png")){if(stream!=null)using(var source=Image.FromStream(stream))icon.Image=new Bitmap(source);}}
        var words=new Panel{Dock=DockStyle.Fill,Padding=new Padding(16,0,0,0)};
        var title=Label("Codex Quota Sidebar",16,Ink);title.Dock=DockStyle.Top;title.Height=31;
        var caption=Label(section+"  /  "+version+"  /  CHUNG",9,Muted);caption.Dock=DockStyle.Top;caption.Height=24;
        words.Controls.Add(caption);words.Controls.Add(title);panel.Controls.Add(words);panel.Controls.Add(icon);
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
            var body=Body();form.Controls.Add(body);form.Controls.Add(Header("\u672c\u673a\u8fde\u63a5\u6388\u6743","Windows"));
            var title=Label("\u5141\u8bb8\u672c\u673a\u8c03\u8bd5\u8fde\u63a5",17,Ink);title.Dock=DockStyle.Top;title.Height=44;
            var notice=Label("\u8c03\u8bd5\u6743\u9650\u4e0d\u53ea\u9650\u4e8e\u8bfb\u53d6\u989d\u5ea6\u3002\u540c\u673a\u5176\u4ed6\u7a0b\u5e8f\u53ef\u80fd\u8bbf\u95ee\u8be5\u7aef\u53e3\u3002\n\n\u505c\u6b62\u9762\u677f\u4e0d\u4f1a\u5173\u95ed\u7aef\u53e3\uff1b\u9700\u5b8c\u6574\u9000\u51fa Codex\uff0c\u518d\u4ece\u5b98\u65b9\u5165\u53e3\u91cd\u542f\u3002\n\n\u672c\u5de5\u5177\u975e OpenAI \u5b98\u65b9\u4ea7\u54c1\u3002\u6570\u636e\u6765\u81ea CLI \u767b\u5f55\u8d26\u53f7\uff0c\u8bf7\u4e0e\u684c\u9762\u8d26\u53f7\u6838\u5bf9\u3002",10,Muted);notice.Dock=DockStyle.Top;notice.Height=190;
            var accept=new CheckBox{Name="consentAccepted",Text="\u6211\u4e86\u89e3\u4e0a\u8ff0\u98ce\u9669\uff0c\u5e76\u4fe1\u4efb\u8fd9\u53f0\u7535\u8111",Dock=DockStyle.Top,Height=42,AutoSize=false};
            body.Controls.Add(accept);body.Controls.Add(notice);body.Controls.Add(title);
            var footer=Footer();var yes=Button("confirm","\u540c\u610f\u5e76\u7ee7\u7eed",true);yes.Enabled=false;yes.DialogResult=DialogResult.OK;
            var no=Button("cancel","\u53d6\u6d88",false);no.DialogResult=DialogResult.Cancel;footer.Controls.Add(yes);footer.Controls.Add(no);form.Controls.Add(footer);body.BringToFront();
            accept.CheckedChanged+=(s,e)=>yes.Enabled=accept.Checked;form.CancelButton=no;form.AcceptButton=no;
            return form.ShowDialog()==DialogResult.OK&&accept.Checked;
        }
    }
    internal static void Error(string text){
        using(var form=new Form()){
            form.Text="Codex Quota Sidebar";Style(form,620,330);
            var body=Body();form.Controls.Add(body);form.Controls.Add(Header("\u9700\u8981\u5904\u7406","Windows"));
            body.Controls.Add(new TextBox{Text=text,ReadOnly=true,Multiline=true,Dock=DockStyle.Fill,BorderStyle=BorderStyle.None,BackColor=Surface,ForeColor=Ink,ScrollBars=ScrollBars.Vertical});
            var footer=Footer();var close=Button("close","\u5173\u95ed",true);close.DialogResult=DialogResult.OK;footer.Controls.Add(close);form.Controls.Add(footer);body.BringToFront();form.CancelButton=close;form.ShowDialog();
        }
    }
}

public static class MeterRestartDialog {
    public static bool Confirm(string question){
        Application.EnableVisualStyles();
        using(var form=new Form()){
            form.Text="Codex Quota Sidebar";MeterTheme.Style(form,660,460);
            var body=MeterTheme.Body();form.Controls.Add(body);form.Controls.Add(MeterTheme.Header("\u91cd\u542f\u786e\u8ba4","Windows"));
            body.Controls.Add(new TextBox{Text=question,ReadOnly=true,Multiline=true,Dock=DockStyle.Fill,BorderStyle=BorderStyle.None,BackColor=MeterTheme.Surface,ForeColor=MeterTheme.Ink,ScrollBars=ScrollBars.Vertical});
            var footer=MeterTheme.Footer();var yes=MeterTheme.Button("restartConfirm","\u5df2\u4fdd\u5b58\uff0c\u91cd\u542f",true);yes.Width=150;yes.DialogResult=DialogResult.OK;
            var no=MeterTheme.Button("cancel","\u53d6\u6d88",false);no.DialogResult=DialogResult.Cancel;
            footer.Controls.Add(yes);footer.Controls.Add(no);form.Controls.Add(footer);body.BringToFront();form.AcceptButton=no;form.CancelButton=no;
            return form.ShowDialog()==DialogResult.OK;
        }
    }
}
