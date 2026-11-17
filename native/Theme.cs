using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

internal static class MeterTheme {
    [System.Runtime.InteropServices.DllImport("user32.dll")]static extern bool SystemParametersInfo(uint action,uint parameter,out bool value,uint flags);
    internal static bool AnimationEnabled {get{bool enabled;return !SystemInformation.HighContrast&&SystemParametersInfo(0x1042,0,out enabled,0)&&enabled;}}
    internal static void Saved(Button button){
        button.Text=Locale.T("Saved successfully");button.BackColor=Surface;button.ForeColor=Blue;button.FlatAppearance.BorderColor=Blue;button.Enabled=false;
        var timer=new Timer{Interval=1400};
        timer.Tick+=(s,e)=>{timer.Stop();timer.Dispose();if(button.IsDisposed)return;button.Text=Locale.T("Save");button.BackColor=Blue;button.ForeColor=Color.White;button.Enabled=true;};
        button.Disposed+=(s,e)=>{timer.Stop();timer.Dispose();};timer.Start();
    }
    internal static readonly Color Ink=SystemInformation.HighContrast?SystemColors.WindowText:Color.FromArgb(37,40,44);
    internal static readonly Color Muted=SystemInformation.HighContrast?SystemColors.WindowText:Color.FromArgb(99,109,122);
    internal static readonly Color Surface=SystemInformation.HighContrast?SystemColors.Window:Color.White;
    internal static readonly Color Line=SystemInformation.HighContrast?SystemColors.WindowText:Color.FromArgb(224,227,231);
    internal static readonly Color Green=SystemInformation.HighContrast?SystemColors.Highlight:Color.FromArgb(36,91,216);
    internal static readonly Color Blue=Green;
    internal static readonly Color Amber=SystemInformation.HighContrast?SystemColors.WindowText:Color.FromArgb(141,86,16);
    internal static Font Font(float size){return new Font("Segoe UI",size,FontStyle.Regular);}
    internal static void SizeCombo(ComboBox box){box.DrawMode=DrawMode.OwnerDrawFixed;box.ItemHeight=28;box.DrawItem+=(s,e)=>{e.DrawBackground();if(e.Index>=0)TextRenderer.DrawText(e.Graphics,Convert.ToString(box.Items[e.Index]),box.Font,new Rectangle(e.Bounds.X+9,e.Bounds.Y,e.Bounds.Width-9,e.Bounds.Height),box.ForeColor,TextFormatFlags.VerticalCenter|TextFormatFlags.Left);e.DrawFocusRectangle();};}
    internal static string Version {
        get {try{string path=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"versions.json");if(!File.Exists(path))path=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"..","versions.json");var data=new System.Web.Script.Serialization.JavaScriptSerializer().Deserialize<System.Collections.Generic.Dictionary<string,object>>(File.ReadAllText(path));return Convert.ToString(data["windows"]);}catch{var v=typeof(MeterTheme).Assembly.GetName().Version;return v.Major==0&&v.Minor==0?"":v.ToString(3);}}
    }
    internal static void Glyph(Button button,string glyph){
        var vector=button as V3Button;if(vector!=null)vector.Glyph=glyph;
        button.Padding=new Padding(8,0,8,0);button.Invalidate();
    }
    internal static string Asset(string name){string root=Path.GetDirectoryName(typeof(MeterTheme).Assembly.Location);string p=Path.Combine(root,"assets",name);return File.Exists(p)?p:Path.Combine(root,"..","assets",name);}
    internal static Icon AppIcon(){try{return new Icon(Asset("cqs.ico"));}catch{return Icon.ExtractAssociatedIcon(Application.ExecutablePath)??(Icon)SystemIcons.Application.Clone();}}
    internal static Icon TrayIcon(){
        bool light=false;
        try{using(var key=Microsoft.Win32.Registry.CurrentUser.OpenSubKey("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize")){light=key!=null&&Convert.ToInt32(key.GetValue("SystemUsesLightTheme",0))==1;}}catch{}
        try{return new Icon(Asset(light?"tray-light.ico":"tray-dark.ico"));}catch{return AppIcon();}
    }
    internal static void Style(Form form,int width,int height){
        // Defer autoscaling until the control tree exists, not the empty form.
        form.SuspendLayout();form.Load+=(s,e)=>form.ResumeLayout(true);
        form.Font=Font(10);form.ForeColor=Ink;form.BackColor=Surface;form.Icon=AppIcon();
        form.AutoScaleMode=AutoScaleMode.Dpi;form.AutoScaleDimensions=new SizeF(96,96);form.ClientSize=new Size(width,height);
        form.FormBorderStyle=FormBorderStyle.Sizable;form.MaximizeBox=true;form.MinimumSize=new Size(Math.Min(width,1040),Math.Min(height,640));form.StartPosition=FormStartPosition.CenterScreen;
        form.Shown+=(s,e)=>Locale.Apply(form);
    }
    internal static Label Label(string text,float size,Color color){return new Label{Text=text,Font=Font(size),ForeColor=color,AutoSize=false,TextAlign=ContentAlignment.MiddleLeft,Dock=DockStyle.Fill,UseMnemonic=false};}
    internal static Panel Header(string section,string version){
        var panel=new Panel{Dock=DockStyle.Top,Height=82,Padding=new Padding(26,22,26,20),BackColor=Surface};
        var icon=new PictureBox{Dock=DockStyle.Left,Width=40,SizeMode=PictureBoxSizeMode.Zoom};
        try{using(var source=Image.FromFile(Asset("cqs-128.png")))icon.Image=new Bitmap(source);}catch{using(var stream=System.Reflection.Assembly.GetExecutingAssembly().GetManifestResourceStream("brand.png")){if(stream!=null)using(var source=Image.FromStream(stream))icon.Image=new Bitmap(source);}}
        var words=new Panel{Dock=DockStyle.Fill,Padding=new Padding(16,0,0,0)};
        var title=Label("Codex Quota Sidebar",12.75f,Ink);title.Dock=DockStyle.Top;title.Height=24;
        var caption=Label("by KEFEN",8.5f,Muted);caption.Name="brandCaption";caption.Dock=DockStyle.Top;caption.Height=18;
        words.Controls.Add(caption);words.Controls.Add(title);panel.Controls.Add(words);panel.Controls.Add(icon);
        var languages=new Panel{Name="languageControl",Dock=DockStyle.Right,Width=148,Padding=new Padding(27,5,6,0)};
        var language=Locale.Picker();language.Dock=DockStyle.Fill;language.Font=Font(9.75f);languages.Controls.Add(language);
        languages.Paint+=(s,e)=>{using(var pen=new Pen(Color.FromArgb(203,208,215)))e.Graphics.DrawRectangle(pen,0,0,languages.Width-1,35);using(var f=new Font("Segoe MDL2 Assets",11))using(var brush=new SolidBrush(Muted))e.Graphics.DrawString("\uE8C1",f,brush,7,10);};
        panel.Controls.Add(languages);words.BringToFront();
        panel.Paint+=(s,e)=>{using(var pen=new Pen(Line))e.Graphics.DrawLine(pen,0,panel.Height-1,panel.Width,panel.Height-1);};
        panel.Disposed+=(s,e)=>{if(icon.Image!=null)icon.Image.Dispose();};return panel;
    }
    internal static Button Button(string name,string label,bool primary){
        var b=new V3Button{Name=name,Text=label,Width=110,Height=38,FlatStyle=FlatStyle.Flat,Font=Font(9.75f),Margin=new Padding(10,0,0,0),Cursor=Cursors.Hand,UseVisualStyleBackColor=false,BackColor=primary?Green:Surface,ForeColor=primary?Color.White:Ink};
        b.FlatAppearance.BorderColor=primary?Green:Color.FromArgb(203,208,215);b.FlatAppearance.BorderSize=1;
        b.FlatAppearance.MouseOverBackColor=primary?Color.FromArgb(30,85,192):Color.FromArgb(240,245,252);
        if(name=="save"||name=="saveDisplay")using(var g=Graphics.FromHwnd(IntPtr.Zero)){
            int width=110;var flags=TextFormatFlags.NoPadding|TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine;
            foreach(string text in Locale.Translations("Saved successfully"))width=Math.Max(width,(int)Math.Ceiling(TextRenderer.MeasureText(g,text,b.Font,new Size(Int32.MaxValue,Int32.MaxValue),flags).Width*96/g.DpiX)+24);
            b.Width=width;b.MinimumSize=new Size(width,0);
        }
        return b;
    }
    internal static FlowLayoutPanel Footer(){var footer=new FlowLayoutPanel{Dock=DockStyle.Bottom,Height=64,Padding=new Padding(16,13,24,12),FlowDirection=FlowDirection.RightToLeft,WrapContents=false,BackColor=Surface};footer.Paint+=(s,e)=>{using(var p=new Pen(Line))e.Graphics.DrawLine(p,0,0,footer.Width,0);};return footer;}
    internal static Panel Body(){return new Panel{Dock=DockStyle.Fill,Padding=new Padding(30,24,30,24),AutoScroll=false,BackColor=Surface};}
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

internal sealed class V3Button : Button {
    internal string Glyph;
    protected override void OnHandleCreated(EventArgs e){
        base.OnHandleCreated(e);
        if(Name!="save"&&Name!="saveDisplay")return;
        using(var g=CreateGraphics()){
            int width=Width;var flags=TextFormatFlags.NoPadding|TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine;
            foreach(string text in Locale.Translations("Saved successfully"))width=Math.Max(width,TextRenderer.MeasureText(g,text,Font,new Size(Int32.MaxValue,Int32.MaxValue),flags).Width+(int)Math.Ceiling(24*g.DpiX/96));
            MinimumSize=new Size(width,0);Width=width;
        }
    }
    bool hover;
    protected override void OnMouseEnter(EventArgs e){hover=true;Invalidate();base.OnMouseEnter(e);}
    protected override void OnMouseLeave(EventArgs e){hover=false;Invalidate();base.OnMouseLeave(e);}
    protected override void OnPaint(PaintEventArgs e){
        var g=e.Graphics;g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        Color background=hover&&Enabled?FlatAppearance.MouseOverBackColor:BackColor;
        using(var clear=new SolidBrush(Parent==null?MeterTheme.Surface:Parent.BackColor))g.FillRectangle(clear,ClientRectangle);
        float r=5*Font.Size/9.75f;var rect=new RectangleF(.5f,.5f,Width-1,Height-1);
        using(var path=new System.Drawing.Drawing2D.GraphicsPath()){
            path.AddArc(rect.Left,rect.Top,r*2,r*2,180,90);path.AddArc(rect.Right-r*2,rect.Top,r*2,r*2,270,90);path.AddArc(rect.Right-r*2,rect.Bottom-r*2,r*2,r*2,0,90);path.AddArc(rect.Left,rect.Bottom-r*2,r*2,r*2,90,90);path.CloseFigure();
            using(var brush=new SolidBrush(background))g.FillPath(brush,path);if(FlatAppearance.BorderSize>0)using(var pen=new Pen(FlatAppearance.BorderColor))g.DrawPath(pen,path);
        }
        float dpi=g.DpiX/96f;int image=String.IsNullOrEmpty(Glyph)?0:(int)Math.Ceiling(20*dpi),gap=image==0||String.IsNullOrEmpty(Text)?0:(int)(8*dpi);var flags=TextFormatFlags.NoPadding|TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine;
        var size=TextRenderer.MeasureText(g,Text,Font,new Size(Int32.MaxValue,Height),flags);int x=TextAlign==ContentAlignment.MiddleLeft?Padding.Left:Math.Max((int)(6*dpi),(Width-size.Width-image-gap)/2);
        Color ink=Enabled?ForeColor:SystemColors.GrayText;
        if(image>0)using(var font=new Font("Segoe MDL2 Assets",11,FontStyle.Regular))TextRenderer.DrawText(g,Glyph,font,new Rectangle(x,0,image,Height),ink,flags|TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);
        TextRenderer.DrawText(g,Text,Font,new Rectangle(x+image+gap,0,Math.Max(0,Width-x-image-gap-(int)(4*dpi)),Height),ink,flags|TextFormatFlags.Left|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);
        if(Focused&&ShowFocusCues)ControlPaint.DrawFocusRectangle(g,new Rectangle(4,4,Width-8,Height-8));
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
