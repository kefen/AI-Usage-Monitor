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
        timer.Tick+=(s,e)=>{timer.Stop();timer.Dispose();if(button.IsDisposed)return;button.Text=Locale.T("Save");button.BackColor=SoftFill;button.ForeColor=SoftInk;button.Enabled=true;};
        button.Disposed+=(s,e)=>{timer.Stop();timer.Dispose();};timer.Start();
    }
    internal static int Mode=ReadMode();
    static int ReadMode(){try{int m=Convert.ToInt32(Microsoft.Win32.Registry.GetValue(@"HKEY_CURRENT_USER\Software\KEFEN\AI Quota Board","Appearance",0));return m>=0&&m<=2?m:0;}catch{return 0;}}
    static bool IsDark(){if(SystemInformation.HighContrast)return false;if(Mode!=0)return Mode==2;try{return Convert.ToInt32(Microsoft.Win32.Registry.GetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize","AppsUseLightTheme",1) ?? 1)==0;}catch{return false;}}
    static bool dark=IsDark();
    static readonly Color[,] palette={{Color.FromArgb(141,86,16),Color.FromArgb(246,190,115)},
        {Color.FromArgb(165,188,227),Color.FromArgb(104,126,164)},
        {Color.FromArgb(203,208,215),Color.FromArgb(91,104,122)},
        {Color.FromArgb(209,224,246),Color.FromArgb(68,84,110)},
        {Color.FromArgb(219,232,255),Color.FromArgb(64,84,120)},
        {Color.FromArgb(220,230,246),Color.FromArgb(62,74,91)},
        {Color.FromArgb(224,227,231),Color.FromArgb(67,77,93)},
        {Color.FromArgb(228,237,253),Color.FromArgb(44,64,99)},
        {Color.FromArgb(232,241,255),Color.FromArgb(48,67,97)},
        {Color.FromArgb(234,241,255),Color.FromArgb(44,59,86)},
        {Color.FromArgb(237,241,247),Color.FromArgb(51,60,72)},
        {Color.FromArgb(237,244,255),Color.FromArgb(43,60,84)},
        {Color.FromArgb(240,245,252),Color.FromArgb(60,70,85)},
        {Color.FromArgb(243,246,251),Color.FromArgb(35,41,51)},
        {Color.FromArgb(243,247,254),Color.FromArgb(36,44,57)},
        {Color.FromArgb(244,247,252),Color.FromArgb(48,57,70)},
        {Color.FromArgb(248,250,253),Color.FromArgb(32,38,46)},
        {Color.FromArgb(249,251,254),Color.FromArgb(34,40,50)},
        {Color.FromArgb(25,112,90),Color.FromArgb(97,200,166)},
        {Color.FromArgb(251,253,255),Color.FromArgb(29,35,44)},
        {Color.FromArgb(255,249,238),Color.FromArgb(67,52,35)},
        {Color.FromArgb(27,76,174),Color.FromArgb(153,188,249)},
        {Color.FromArgb(30,85,192),Color.FromArgb(59,106,207)},
        {Color.FromArgb(33,77,182),Color.FromArgb(134,161,244)},
        {Color.FromArgb(36,91,216),Color.FromArgb(92,146,248)},
        {Color.FromArgb(37,40,44),Color.FromArgb(234,238,244)},
        {Color.FromArgb(99,109,122),Color.FromArgb(173,184,199)},
        {Color.FromArgb(255,255,255),Color.FromArgb(26,31,38)},
        {Color.FromArgb(38,88,201),Color.FromArgb(45,94,187)},
        {Color.FromArgb(230,234,240),Color.FromArgb(56,66,80)}};
    internal static Color Tint(Color c){if(!dark)return c;return Translate(c,true);}
    static Color Translate(Color c,bool toDark){for(int i=0;i<palette.GetLength(0);i++)if(c.ToArgb()==palette[i,toDark?0:1].ToArgb())return palette[i,toDark?1:0];return c;}
    internal static Color ActionFill{get{return SystemInformation.HighContrast?SystemColors.Highlight:Tint(Color.FromArgb(38,88,201));}}
    internal static Color SoftFill{get{return SystemInformation.HighContrast?SystemColors.Highlight:Tint(Color.FromArgb(228,237,253));}}
    internal static Color SoftInk{get{return SystemInformation.HighContrast?SystemColors.HighlightText:Tint(Color.FromArgb(27,76,174));}}
    internal static Color Secondary{get{return Tint(Color.FromArgb(230,234,240));}}
    [System.Runtime.InteropServices.DllImport("dwmapi.dll")]static extern int DwmSetWindowAttribute(IntPtr hwnd,int attribute,ref int value,int size);
    static void Frame(Form f){if(f.IsHandleCreated){int v=dark?1:0;DwmSetWindowAttribute(f.Handle,20,ref v,4);}}
    internal static void SetMode(int mode,bool persist=true){try{if(persist)Microsoft.Win32.Registry.SetValue(@"HKEY_CURRENT_USER\Software\KEFEN\AI Quota Board","Appearance",mode);}catch(Exception ex){Error(ex.Message);return;}Mode=mode;RefreshMode();}
    static void RefreshMode(){bool next=IsDark();if(next==dark)return;dark=next;foreach(Form f in Application.OpenForms){ApplyColors(f);Frame(f);f.Invalidate(true);}}
    static void ApplyColors(Control c){var bg=Translate(c.BackColor,dark);if(bg.ToArgb()!=c.BackColor.ToArgb())c.BackColor=bg;
        if(c.ForeColor.ToArgb()!=Color.White.ToArgb()){var fg=c.ForeColor.ToArgb()==Color.Black.ToArgb()?Ink:Translate(c.ForeColor,dark);if(fg.ToArgb()!=c.ForeColor.ToArgb())c.ForeColor=fg;}
        var b=c as Button;if(b!=null){b.FlatAppearance.BorderColor=Translate(b.FlatAppearance.BorderColor,dark);b.FlatAppearance.MouseOverBackColor=Translate(b.FlatAppearance.MouseOverBackColor,dark);}
        foreach(Control child in c.Controls)ApplyColors(child);
    }
    static void WatchInputs(Control c){if(c is ComboBox||c is TextBoxBase||c is ListBox){c.BackColor=Surface;c.ForeColor=Ink;}c.ControlAdded+=(s,e)=>WatchInputs(e.Control);foreach(Control child in c.Controls)WatchInputs(child);}
    internal static Color Ink{get{return SystemInformation.HighContrast?SystemColors.WindowText:MeterTheme.Tint(Color.FromArgb(37,40,44));}}
    internal static Color Muted{get{return SystemInformation.HighContrast?SystemColors.WindowText:MeterTheme.Tint(Color.FromArgb(99,109,122));}}
    internal static Color Surface{get{return SystemInformation.HighContrast?SystemColors.Window:Tint(Color.White);}}
    internal static Color Line{get{return SystemInformation.HighContrast?SystemColors.WindowText:MeterTheme.Tint(Color.FromArgb(224,227,231));}}
    internal static Color Green{get{return SystemInformation.HighContrast?SystemColors.Highlight:MeterTheme.Tint(Color.FromArgb(36,91,216));}}
    internal static Color Blue{get{return Green;}}
    internal static Color Amber{get{return SystemInformation.HighContrast?SystemColors.WindowText:MeterTheme.Tint(Color.FromArgb(141,86,16));}}
    internal static Font Font(float size){return new Font("Segoe UI",size,FontStyle.Regular);}
    internal static void SizeCombo(ComboBox box){box.DrawMode=DrawMode.OwnerDrawFixed;box.ItemHeight=28;box.DrawItem+=(s,e)=>{bool highlighted=(e.State&DrawItemState.Selected)!=0&&(e.State&DrawItemState.ComboBoxEdit)==0;using(var brush=new SolidBrush(highlighted?SystemColors.Highlight:Surface))e.Graphics.FillRectangle(brush,e.Bounds);if(e.Index>=0)TextRenderer.DrawText(e.Graphics,Convert.ToString(box.Items[e.Index]),box.Font,new Rectangle(e.Bounds.X+9,e.Bounds.Y,e.Bounds.Width-9,e.Bounds.Height),highlighted?SystemColors.HighlightText:Ink,TextFormatFlags.VerticalCenter|TextFormatFlags.Left);e.DrawFocusRectangle();};}
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
        WatchInputs(form);form.HandleCreated+=(s,e)=>Frame(form);
        Microsoft.Win32.UserPreferenceChangedEventHandler changed=(s,e)=>{if(Mode==0&&form.IsHandleCreated&&!form.IsDisposed)try{form.BeginInvoke((Action)RefreshMode);}catch(InvalidOperationException){}};
        Microsoft.Win32.SystemEvents.UserPreferenceChanged+=changed;form.Disposed+=(s,e)=>Microsoft.Win32.SystemEvents.UserPreferenceChanged-=changed;
        form.Font=Font(10);form.ForeColor=Ink;form.BackColor=Surface;form.Icon=AppIcon();
        form.AutoScaleMode=AutoScaleMode.Dpi;form.AutoScaleDimensions=new SizeF(96,96);form.ClientSize=new Size(width,height);
        form.FormBorderStyle=FormBorderStyle.Sizable;form.MaximizeBox=true;form.MinimumSize=new Size(Math.Min(width,1040),Math.Min(height,640));form.StartPosition=FormStartPosition.CenterScreen;
        form.Shown+=(s,e)=>Locale.Apply(form);
    }
    internal static Label Label(string text,float size,Color color){return new Label{Text=text,Font=Font(size),ForeColor=color,AutoSize=false,TextAlign=ContentAlignment.MiddleLeft,Dock=DockStyle.Fill,UseMnemonic=false};}
    internal static Label PageTitle(string text){return new PageTitleLabel{Text=text,Font=Font(16.5f),ForeColor=Ink,AutoSize=false,TextAlign=ContentAlignment.TopLeft,Dock=DockStyle.Fill,UseMnemonic=false};}
    internal static Panel Header(string section,string version){
        var panel=new Panel{Dock=DockStyle.Top,Height=82,Padding=new Padding(26,22,26,20),BackColor=Surface};
        var icon=new Button{Name="brandLogo",Dock=DockStyle.Left,Width=40,FlatStyle=FlatStyle.Flat,TabStop=false,BackgroundImageLayout=ImageLayout.Zoom,UseVisualStyleBackColor=false};
        icon.FlatAppearance.BorderSize=0;
        try{using(var source=Image.FromFile(Asset("cqs-128.png")))icon.BackgroundImage=new Bitmap(source);}catch{using(var stream=System.Reflection.Assembly.GetExecutingAssembly().GetManifestResourceStream("brand.png")){if(stream!=null)using(var source=Image.FromStream(stream))icon.BackgroundImage=new Bitmap(source);}}
        var words=new Panel{Dock=DockStyle.Fill,Padding=new Padding(16,0,0,0)};
        var title=Label("AI Quota Board",12.75f,Ink);title.Name="brandTitle";title.Dock=DockStyle.Top;title.Height=24;
        var caption=Label("by KEFEN",8.5f,Muted);caption.Name="brandCaption";caption.Dock=DockStyle.Top;caption.Height=18;
        words.Controls.Add(caption);words.Controls.Add(title);panel.Controls.Add(words);panel.Controls.Add(icon);
        var languages=new Panel{Name="languageControl",Dock=DockStyle.Right,Width=105};
        var language=Locale.Picker();language.Font=Font(9.75f);language.AccessibleName=Locale.T("Language");languages.Controls.Add(language);
        languages.Layout+=(s,e)=>language.SetBounds(0,Math.Max(0,(languages.ClientSize.Height-language.Height)/2),languages.ClientSize.Width,language.Height);
        Action fitLanguage=()=>{if(!language.IsHandleCreated)return;using(var g=language.CreateGraphics()){
            var flags=TextFormatFlags.NoPadding|TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine;int extra=SystemInformation.VerticalScrollBarWidth+(int)(12*g.DpiX/96f);
            int text=TextRenderer.MeasureText(g,language.Text,language.Font,new Size(Int32.MaxValue,Int32.MaxValue),flags).Width;
            language.AccessibleName=Locale.T("Language");
            languages.Width=text+extra;
            int widest=0;foreach(object item in language.Items)widest=Math.Max(widest,TextRenderer.MeasureText(g,Convert.ToString(item),language.Font,new Size(Int32.MaxValue,Int32.MaxValue),flags).Width);language.DropDownWidth=widest+extra;
        }};
        language.SelectedIndexChanged+=(s,e)=>fitLanguage();language.FontChanged+=(s,e)=>fitLanguage();
        panel.HandleCreated+=(s,e)=>panel.BeginInvoke((Action)(()=>{if(!panel.IsDisposed)fitLanguage();}));
        panel.Controls.Add(languages);words.BringToFront();
        panel.Paint+=(s,e)=>{using(var pen=new Pen(Line))e.Graphics.DrawLine(pen,0,panel.Height-1,panel.Width,panel.Height-1);};
        panel.Disposed+=(s,e)=>{if(icon.BackgroundImage!=null)icon.BackgroundImage.Dispose();};return panel;
    }
    internal static Button Button(string name,string label,bool primary){
        bool soft=name=="selectAll"||name=="detectPlan"||name=="save"||name=="reconnect"||name=="Reconnect";if(soft)primary=false;
        var b=new V3Button{Name=name,Text=label,Width=110,Height=38,FlatStyle=FlatStyle.Flat,Font=Font(9.75f),Margin=new Padding(10,0,0,0),Cursor=Cursors.Hand,UseVisualStyleBackColor=false,BackColor=primary?ActionFill:soft?SoftFill:Secondary,ForeColor=primary?Color.White:soft?SoftInk:Ink};
        b.FlatAppearance.BorderColor=primary?ActionFill:soft?Tint(Color.FromArgb(209,224,246)):MeterTheme.Tint(Color.FromArgb(203,208,215));b.FlatAppearance.BorderSize=1;
        b.FlatAppearance.MouseOverBackColor=primary?MeterTheme.Tint(Color.FromArgb(30,85,192)):soft?Tint(Color.FromArgb(219,232,255)):MeterTheme.Tint(Color.FromArgb(240,245,252));
        if(name=="save"||name=="saveDisplay")using(var g=Graphics.FromHwnd(IntPtr.Zero)){
            int width=110;var flags=TextFormatFlags.NoPadding|TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine;
            foreach(string text in Locale.Translations("Saved successfully"))width=Math.Max(width,(int)Math.Ceiling(TextRenderer.MeasureText(g,text,b.Font,new Size(Int32.MaxValue,Int32.MaxValue),flags).Width*96/g.DpiX)+24);
            b.Width=width;b.MinimumSize=new Size(width,0);
        }
        return b;
    }
    internal static void OpenProject(){try{System.Diagnostics.Process.Start(Locale.Repository);}catch(System.ComponentModel.Win32Exception){Error(Locale.Repository);}}
    internal static int SaveWidth(Graphics g,Button b,bool showFeedback){
        var flags=TextFormatFlags.NoPadding|TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine;
        int width=TextRenderer.MeasureText(g,Locale.T(showFeedback?"Saved successfully":"Save"),b.Font,Size.Empty,flags).Width;
        return Math.Max((int)(56*g.DpiX/96),width+(int)(22*g.DpiX/96));
    }
    internal static FlowLayoutPanel Footer(){var footer=new FlowLayoutPanel{Dock=DockStyle.Bottom,Height=64,Padding=new Padding(16,13,24,12),FlowDirection=FlowDirection.RightToLeft,WrapContents=false,BackColor=Surface};footer.Paint+=(s,e)=>{using(var p=new Pen(Line))e.Graphics.DrawLine(p,0,0,footer.Width,0);};return footer;}
    internal static Panel Body(){return new Panel{Dock=DockStyle.Fill,Padding=new Padding(30,24,30,24),AutoScroll=false,BackColor=Surface};}
    internal static bool Consent(){
        using(var form=new Form()){
            form.Text="AI Quota Board";Style(form,620,470);form.MinimizeBox=false;
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
            form.Text="AI Quota Board";Style(form,620,330);
            var body=Body();form.Controls.Add(body);form.Controls.Add(Header(Locale.T("Action needed"),"Windows"));
            body.Controls.Add(new TextBox{Text=text,ReadOnly=true,Multiline=true,Dock=DockStyle.Fill,BorderStyle=BorderStyle.None,BackColor=Surface,ForeColor=Ink,ScrollBars=ScrollBars.Vertical});
            var footer=Footer();var close=Button("close",Locale.T("Close"),true);close.DialogResult=DialogResult.OK;footer.Controls.Add(close);form.Controls.Add(footer);body.BringToFront();form.CancelButton=close;form.ShowDialog();
        }
    }
}

internal sealed class PageTitleLabel : Label {
    protected override void OnPaint(PaintEventArgs e){
        int inset;using(var reference=MeterTheme.Font(10))inset=(int)Math.Ceiling(reference.GetHeight(e.Graphics)/6f);
        TextRenderer.DrawText(e.Graphics,Text,Font,new Rectangle(inset,0,Math.Max(0,Width-inset),Height),ForeColor,TextFormatFlags.NoPadding|TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine|TextFormatFlags.Top);
    }
}

internal sealed class NavigationItem : Control {
    internal string Glyph="";bool hover;
    internal bool CenterContent=false;
    internal NavigationItem(){SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.ResizeRedraw|ControlStyles.Selectable,true);TabStop=true;Cursor=Cursors.Hand;AccessibleRole=AccessibleRole.PushButton;}
    internal void PerformClick(){if(Enabled)OnClick(EventArgs.Empty);}
    protected override void OnTextChanged(EventArgs e){base.OnTextChanged(e);Invalidate();}
    protected override bool IsInputKey(Keys keyData){var key=keyData&Keys.KeyCode;return key==Keys.Enter||key==Keys.Space||base.IsInputKey(keyData);}
    protected override AccessibleObject CreateAccessibilityInstance(){return new ActionAccessibility(this);}
    sealed class ActionAccessibility : ControlAccessibleObject {
        readonly NavigationItem action;
        internal ActionAccessibility(NavigationItem owner):base(owner){action=owner;}
        public override void DoDefaultAction(){action.PerformClick();}
    }
    protected override void OnMouseDown(MouseEventArgs e){if(e.Button==MouseButtons.Left)Focus();base.OnMouseDown(e);}
    protected override void OnMouseEnter(EventArgs e){hover=true;Invalidate();base.OnMouseEnter(e);}
    protected override void OnMouseLeave(EventArgs e){hover=false;Invalidate();base.OnMouseLeave(e);}
    protected override void OnGotFocus(EventArgs e){base.OnGotFocus(e);Invalidate();}
    protected override void OnLostFocus(EventArgs e){base.OnLostFocus(e);Invalidate();}
    protected override void OnKeyDown(KeyEventArgs e){if(e.KeyCode==Keys.Space||e.KeyCode==Keys.Enter){PerformClick();e.Handled=true;e.SuppressKeyPress=true;}base.OnKeyDown(e);}
    protected override void OnPaint(PaintEventArgs e){
        var g=e.Graphics;g.Clear(Parent==null?BackColor:Parent.BackColor);g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        Color background=hover&&ForeColor!=MeterTheme.Green?MeterTheme.Tint(Color.FromArgb(237,241,247)):BackColor;
        float r=4*g.DpiX/96f;var rect=new RectangleF(0,0,Width-1,Height-1);
        using(var path=new System.Drawing.Drawing2D.GraphicsPath()){
            path.AddArc(rect.Left,rect.Top,r*2,r*2,180,90);path.AddArc(rect.Right-r*2,rect.Top,r*2,r*2,270,90);path.AddArc(rect.Right-r*2,rect.Bottom-r*2,r*2,r*2,0,90);path.AddArc(rect.Left,rect.Bottom-r*2,r*2,r*2,90,90);path.CloseFigure();
            using(var brush=new SolidBrush(background))g.FillPath(brush,path);
        }
        float s=g.DpiX/96f;var flags=TextFormatFlags.NoPadding|TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine|TextFormatFlags.VerticalCenter;
        int icon=(int)(20*s),left=String.IsNullOrEmpty(Text)?Math.Max(0,(Width-icon)/2):(int)(8*s);
        if(CenterContent&&!String.IsNullOrEmpty(Text)){int text=TextRenderer.MeasureText(g,Text,Font,new Size(Int32.MaxValue,Height),flags).Width;left=Math.Max(0,(Width-icon-(int)(8*s)-text)/2);}
        using(var font=new Font("Segoe MDL2 Assets",11))TextRenderer.DrawText(g,Glyph,font,new Rectangle(left,0,icon,Height),ForeColor,flags|TextFormatFlags.HorizontalCenter);
        int textLeft=CenterContent?left+icon+(int)(8*s):(int)(36*s);
        TextRenderer.DrawText(g,Text,Font,new Rectangle(textLeft,0,Math.Max(0,Width-textLeft-(int)(4*s)),Height),ForeColor,flags);
        if(Focused&&ShowFocusCues)ControlPaint.DrawFocusRectangle(g,new Rectangle(4,4,Width-8,Height-8));
    }
}

internal sealed class ConnectionIndicator : Control {
    readonly Timer timer=new Timer{Interval=80};
    bool active;DateTime started;int frame;
    internal bool Active {get{return active;}set{if(active!=value){active=value;started=DateTime.UtcNow;frame=14;}Visible=value;RefreshAnimation();}}
    internal ConnectionIndicator(){
        SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer,true);
        timer.Tick+=(s,e)=>{if(!Visible||DateTime.UtcNow-started>TimeSpan.FromSeconds(60)){timer.Stop();return;}frame=(frame+1)%40;Invalidate();};
    }
    void RefreshAnimation(){if(active&&Visible&&MeterTheme.AnimationEnabled&&DateTime.UtcNow-started<TimeSpan.FromSeconds(60))timer.Start();else timer.Stop();Invalidate();}
    protected override void OnVisibleChanged(EventArgs e){base.OnVisibleChanged(e);RefreshAnimation();}
    protected override void OnPaint(PaintEventArgs e){
        e.Graphics.Clear(MeterTheme.Line);int segment=Math.Max(1,Width/3);
        int x=MeterTheme.AnimationEnabled?(int)((Width+segment)*(frame/40f))-segment:(Width-segment)/2;
        using(var brush=new SolidBrush(MeterTheme.Blue))e.Graphics.FillRectangle(brush,x,0,segment,Height);
    }
    protected override void Dispose(bool disposing){if(disposing)timer.Dispose();base.Dispose(disposing);}
}

internal sealed class V3Button : Button {
    internal V3Button(){
        SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.ResizeRedraw,true);
        FlatStyle=FlatStyle.Flat;
    }
    protected override void OnPaintBackground(PaintEventArgs e){e.Graphics.Clear(Parent==null?MeterTheme.Surface:Parent.BackColor);}
    protected override void OnGotFocus(EventArgs e){base.OnGotFocus(e);Invalidate();}
    protected override void OnLostFocus(EventArgs e){base.OnLostFocus(e);Invalidate();if(Parent!=null)Parent.Invalidate(Bounds);}
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
            form.Text="AI Quota Board";MeterTheme.Style(form,660,460);
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
