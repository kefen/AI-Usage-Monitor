using System;
using System.Collections.Generic;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

internal sealed class BlankDatePicker : DateTimePicker {
    bool known;
    internal event EventHandler PresenceChanged;
    internal BlankDatePicker(){ShowCheckBox=false;Format=DateTimePickerFormat.Custom;CustomFormat=" ";}
    public new bool Checked {get{return known;}set{bool changed=known!=value;known=value;CustomFormat=value?"yyyy-MM-dd":" ";if(changed&&PresenceChanged!=null)PresenceChanged(this,EventArgs.Empty);}}
    internal void Clear(){Checked=false;base.OnValueChanged(EventArgs.Empty);}
    protected override void OnValueChanged(EventArgs e){Checked=true;base.OnValueChanged(e);}
    protected override void OnCloseUp(EventArgs e){Checked=true;base.OnValueChanged(EventArgs.Empty);base.OnCloseUp(e);}
    protected override void OnKeyDown(KeyEventArgs e){if(e.KeyCode==Keys.Delete||e.KeyCode==Keys.Back){Clear();e.Handled=true;}else base.OnKeyDown(e);}
}

internal static class MeterPreferences {
    static string[] TiersFor(string family){return family=="pro"?new[]{"unknown","100","200","500"}:family=="business"?new[]{"unknown","standard","premium"}:new[]{"unknown"};}
    static readonly JavaScriptSerializer Json=new JavaScriptSerializer();
    internal static Dictionary<string,object> Read(string path){try{return Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(path,Encoding.UTF8));}catch{return new Dictionary<string,object>();}}
    static string Value(Dictionary<string,object> data,string key,string fallback){return data.ContainsKey(key)?Convert.ToString(data[key]):fallback;}
    internal static void Save(string path,object data){
        FileStream lease=null;string lockPath=path+".lock";
        try{
            if(Path.GetFileName(path)=="membership.json")lease=new FileStream(lockPath,FileMode.CreateNew,FileAccess.Write,FileShare.None);
            Write(path,data);
        }finally{if(lease!=null){lease.Dispose();File.Delete(lockPath);}}
    }
    static void Write(string path,object data){string temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";try{File.WriteAllText(temp,Json.Serialize(data),new UTF8Encoding(false));if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);}finally{if(File.Exists(temp))File.Delete(temp);}}
    internal static bool EnsureReady(string root){
        var prefs=Read(Path.Combine(root,"preferences.json"));
        if(Value(prefs,"cdpConsent","")!="True"){if(!MeterTheme.Consent())return false;prefs["cdpConsent"]=true;Save(Path.Combine(root,"preferences.json"),prefs);}
        if(Value(prefs,"setupComplete","")!="True")Edit(root);return true;
    }
    internal static void Edit(string root){using(var form=Create(root,false))form.ShowDialog();}
    internal static void DetectPlan(Control owner,string appRoot,string operation,Action<Dictionary<string,object>> done){
        System.Threading.Tasks.Task.Factory.StartNew(()=>{
            var result=new Dictionary<string,object>{{"detected",false},{"error","E_DESKTOP_UNAVAILABLE"}};
            try{
                var info=new System.Diagnostics.ProcessStartInfo(Path.Combine(appRoot,"runtime","node.exe"),"\""+Path.Combine(appRoot,"src","plan.mjs")+"\" "+operation+" \""+appRoot.TrimEnd('\\')+"\""){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true,WorkingDirectory=appRoot};
                using(var p=System.Diagnostics.Process.Start(info)){var output=p.StandardOutput.ReadToEndAsync();var error=p.StandardError.ReadToEndAsync();if(!p.WaitForExit(20000)){p.Kill();throw new TimeoutException();}if(p.ExitCode==0)result=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(output.Result);}
            }catch{}
            if(!owner.IsDisposed&&owner.IsHandleCreated)try{owner.BeginInvoke((Action)(()=>{if(!owner.IsDisposed)done(result);}));}catch(InvalidOperationException){}
        });
    }
    internal static string DetectionMessage(Dictionary<string,object> result){
        string code=Value(result,"error","");
        switch(code){
            case "E_BUSY":return Locale.T("Subscription record is busy. Try again.");
            case "E_PLAN_UNKNOWN":return Locale.T("Plan could not be identified. Select it manually.");
            case "E_CONFIG_CHANGED":return Locale.T("Subscription changed during detection. Your edits were preserved.");
            case "E_CONFIG_INVALID":return Locale.T("Subscription record is invalid. Restore a backup or check diagnostics.");
            case "E_MANUAL_LOCK":return Locale.T("Manual record preserved");
            case "E_ALREADY_ATTEMPTED":return Locale.T("Automatic detection already attempted. Use Detect to retry.");
            default:return Locale.T("Desktop detection unavailable. Connect Codex and try again.");
        }
    }
    static BlankDatePicker DateInput(string name,string saved){
        DateTime date;bool known=DateTime.TryParseExact(saved,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out date);
        var input=new BlankDatePicker{Name=name,Dock=DockStyle.Fill,Checked=known};
        if(known)input.Value=date;input.Checked=known;input.ValueChanged+=(s,e)=>input.CustomFormat=input.Checked?"yyyy-MM-dd":" ";return input;
    }
    static void LoadDate(BlankDatePicker input,string saved){DateTime date;bool known=DateTime.TryParseExact(saved,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out date);if(known)input.Value=date;input.Checked=known;}
    static Panel Field(string label,Control control){
        var panel=new Panel{Margin=Padding.Empty};
        var caption=MeterTheme.Label(label,9,MeterTheme.Muted);caption.Dock=control.Dock=DockStyle.None;
        panel.Controls.Add(caption);panel.Controls.Add(control);
        var date=control as BlankDatePicker;
        var clear=date==null?null:new NavigationItem{Name=control.Name+"Clear",Text="",Glyph="\uE711",AccessibleName=Locale.T("Clear selection"),ForeColor=MeterTheme.Muted,BackColor=MeterTheme.Tint(Color.FromArgb(244,247,252))};
        if(clear!=null){panel.Controls.Add(clear);clear.Click+=(s,e)=>date.Clear();var tip=new ToolTip();tip.SetToolTip(clear,clear.AccessibleName);panel.Disposed+=(s,e)=>tip.Dispose();}
        Action arrange=()=>{using(var g=panel.CreateGraphics()){
            Func<int,int> px=n=>(int)Math.Round(n*g.DpiX/96);int width=panel.ClientSize.Width;
            caption.SetBounds(0,0,width,px(21));int cy=px(22+17);
            var combo=control as ComboBox;if(combo!=null)combo.ItemHeight=combo.Font.Height+px(2);
            int height=date!=null?date.PreferredHeight:combo.PreferredHeight;
            int reserved=date!=null&&date.Enabled?height+px(6):0;
            control.SetBounds(0,cy-height/2,Math.Max(1,width-reserved),height);
            if(clear!=null){clear.SetBounds(width-height,control.Top,height,height);clear.Visible=clear.Enabled=date.Enabled&&date.Checked;}
        }};
        panel.SizeChanged+=(s,e)=>arrange();panel.HandleCreated+=(s,e)=>arrange();control.FontChanged+=(s,e)=>arrange();
        if(date!=null){date.EnabledChanged+=(s,e)=>arrange();date.PresenceChanged+=(s,e)=>arrange();}
        return panel;
    }
    internal static Form Create(string root,bool embedded){
        Directory.CreateDirectory(root);string memberPath=Path.Combine(root,"membership.json");var data=Read(memberPath);
        var form=new Form();form.Text="AI Quota Board";MeterTheme.Style(form,960,640);form.MinimizeBox=false;
        if(embedded)form.MinimumSize=Size.Empty;
        var body=MeterTheme.Body();body.AutoScroll=false;body.Padding=embedded?new Padding(0):new Padding(30,24,30,24);form.Controls.Add(body);if(!embedded)form.Controls.Add(MeterTheme.Header("Codex subscription record","Windows"));
        var content=new Panel{Name="planContent",Dock=DockStyle.Top,Height=530};body.Controls.Add(content);body.BringToFront();
        var summary=MeterTheme.Label("",13,MeterTheme.Ink);
        var optional=MeterTheme.Label("Only record your existing Codex subscription. No sign-up or purchase for this tool.",9,MeterTheme.Muted);
        var ids=new[]{"free","go","plus","pro","business","enterprise","edu","other"};
        var plan=new ComboBox{Name="plan",DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};plan.Items.AddRange(new object[]{"Free","Go","Plus","Pro","Business","Enterprise","Edu","Other / unknown"});plan.SelectedIndex=7;
        for(int i=0;i<ids.Length;i++)if(ids[i]==Value(data,"plan",""))plan.SelectedIndex=i;
        var detect=MeterTheme.Button("detectPlan","Detect",false);
        var source=MeterTheme.Label(Value(data,"planSource","")=="desktop"?"Plan family detected from Codex desktop":"Manual record preserved",9,MeterTheme.Muted);source.Name="planSource";
        var dateTitle=MeterTheme.Label("Dates and renewal",11,MeterTheme.Ink);
        var tier=new ComboBox{Name="tier",DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};
        string[] tierIds=new string[0];bool refreshingTier=false;
        Action<string> populateTiers=prior=>{refreshingTier=true;tier.BeginUpdate();try{
            string family=ids[Math.Max(0,plan.SelectedIndex)];
            tierIds=TiersFor(family);
            tier.Items.Clear();foreach(string id in tierIds)tier.Items.Add(id=="unknown"?Locale.T("Unknown / not recorded"):id=="standard"?"Business Standard":id=="premium"?"Business Premium":"Pro "+id);
            tier.SelectedIndex=0;for(int i=0;i<tierIds.Length;i++)if(tierIds[i]==prior)tier.SelectedIndex=i;
            tier.Enabled=tierIds.Length>1;
        }finally{tier.EndUpdate();refreshingTier=false;}};
        Action loadTier=()=>populateTiers(Value(data,"tier","unknown"));loadTier();
        var mode=new ComboBox{Name="dateMode",DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};mode.Items.AddRange(new object[]{Locale.T("Monthly estimate (purchase + one month)"),Locale.T("Manual renewal date"),Locale.T("Manual expiry date"),Locale.T("Business annual estimate")});mode.SelectedIndex=Value(data,"annualEstimate","")=="True"?3:Value(data,"monthlyEstimate","")=="True"||!data.ContainsKey("date")?0:Value(data,"kind","")=="expiry"?2:1;
        var purchase=DateInput("purchaseDate",Value(data,"purchaseDate",""));var next=DateInput("nextDate",Value(data,"date",""));
        // Keep Latin digits and Han text on one UI typeface in both GDI-drawn and native editors.
        var fieldFont=new Font("Microsoft YaHei UI",10f,FontStyle.Regular);
        if(fieldFont.Name!="Microsoft YaHei UI"){fieldFont.Dispose();fieldFont=MeterTheme.Font(10);}
        form.Disposed+=(s,e)=>fieldFont.Dispose();
        foreach(Control input in new Control[]{plan,tier,mode,purchase,next})input.Font=fieldFont;
        foreach(var combo in new[]{plan,tier,mode})MeterTheme.SizeCombo(combo);
        var familyField=Field("Plan badge",plan);var tierField=Field("Specific tier (manual, optional)",tier);
        var purchaseField=Field("Purchase date",purchase);var modeField=Field("Date type",mode);var nextField=Field("Renewal / expiry",next);
        var note=MeterTheme.Label("Dates are optional. Detection never changes dates. Leave blank to hide.",9,MeterTheme.Muted);
        var enabled=new CheckBox{Name="membershipEnabled",Font=fieldFont,Text=Locale.T("Show renewal date in sidebar and overview"),Checked=data.Count>0&&Value(data,"enabled","True")!="False"};
        var buttons=new FlowLayoutPanel{Margin=Padding.Empty,WrapContents=false};
        var save=MeterTheme.Button("save","Save",true);var skip=MeterTheme.Button("skip","Skip / hide",false);var cancel=MeterTheme.Button("cancel","Cancel",false);
        buttons.Controls.Add(save);if(!embedded){buttons.Controls.Add(skip);buttons.Controls.Add(cancel);cancel.DialogResult=DialogResult.Cancel;form.CancelButton=cancel;}
        var lines=new[]{new Panel(),new Panel(),new Panel()};foreach(var line in lines){line.BackColor=MeterTheme.Line;content.Controls.Add(line);}
        foreach(Control c in new Control[]{summary,source,optional,detect,dateTitle,familyField,tierField,purchaseField,modeField,nextField,note,enabled,buttons}){c.Dock=DockStyle.None;content.Controls.Add(c);}
        form.AcceptButton=save;
        Action updateSummary=()=>{summary.Text=plan.Text+(tier.Enabled&&tier.SelectedIndex>0?"   /   "+tier.Text:"");};
        plan.SelectedIndexChanged+=(s,e)=>updateSummary();tier.SelectedIndexChanged+=(s,e)=>updateSummary();updateSummary();
        bool arranging=false;
        Action arrange=()=>{if(arranging)return;arranging=true;try{using(var g=content.CreateGraphics()){
            Func<int,int> px=n=>(int)Math.Round(n*g.DpiX/96);
            int available=body.ClientSize.Height-body.Padding.Vertical;
            int w=Math.Min(px(900),Math.Max(0,body.ClientSize.Width-body.Padding.Horizontal));
            int gap=px(16),col=Math.Max(1,(w-gap)/2),right=col+gap;
            int detectWidth=Math.Max(px(110),TextRenderer.MeasureText(g,detect.Text,detect.Font).Width+px(20));
            detect.SetBounds(w-detectWidth,0,detectWidth,px(34));
            int titleWidth=Math.Min(w/3,TextRenderer.MeasureText(g,summary.Text,summary.Font).Width+px(12));
            summary.SetBounds(0,0,titleWidth,px(34));source.SetBounds(titleWidth,0,Math.Max(0,detect.Left-titleWidth-gap),px(34));
            optional.SetBounds(0,px(35),w,px(29));lines[0].SetBounds(0,px(70),w,1);
            familyField.SetBounds(0,px(76),col,px(60));tierField.SetBounds(right,px(76),w-right,px(60));
            lines[1].SetBounds(0,px(146),w,1);dateTitle.SetBounds(0,px(151),w,px(23));
            purchaseField.SetBounds(0,px(178),col,px(60));modeField.SetBounds(right,px(178),w-right,px(60));
            nextField.SetBounds(0,px(244),col,px(60));enabled.SetBounds(right,px(264),w-right,px(36));
            int nh=Math.Max(px(24),TextRenderer.MeasureText(g,note.Text,note.Font,new Size(Math.Max(1,w),int.MaxValue),TextFormatFlags.WordBreak).Height+2);
            note.SetBounds(0,px(309),w,nh);lines[2].SetBounds(0,note.Bottom+px(8),w,1);
            save.MinimumSize=new Size(MeterTheme.SaveWidth(g,save,true),0);
            foreach(Button b in buttons.Controls){b.Margin=new Padding(0,0,px(8),0);b.Size=new Size(Math.Max(b.MinimumSize.Width,TextRenderer.MeasureText(g,b.Text,b.Font).Width+px(26)),px(34));}
            buttons.SetBounds(0,lines[2].Bottom+px(10),w,px(38));
            int h=buttons.Bottom+px(4);content.Height=h;body.AutoScroll=available<h;
            body.AutoScrollMinSize=body.AutoScroll?new Size(0,h):Size.Empty;
        }}finally{arranging=false;}};
        content.Resize+=(s,e)=>arrange();body.ClientSizeChanged+=(s,e)=>arrange();form.Shown+=(s,e)=>arrange();
        foreach(var c in new Control[]{summary,optional,note,detect,source,skip,cancel})c.TextChanged+=(s,e)=>arrange();arrange();
        bool dirty=false,loading=false,planEdited=false,tierEdited=false;
        Action update=()=>{bool estimate=mode.SelectedIndex==0||mode.SelectedIndex==3;next.Enabled=!estimate;if(estimate){next.Checked=purchase.Checked;if(purchase.Checked)next.Value=mode.SelectedIndex==3?purchase.Value.AddYears(1):purchase.Value.AddMonths(1);next.CustomFormat=next.Checked?"yyyy-MM-dd":" ";}};
        Action change=()=>{if(!loading&&!Locale.IsTranslating){dirty=true;}};
        plan.SelectedIndexChanged+=(s,e)=>{if(Locale.IsTranslating||loading||plan.SelectedIndex<0)return;string prior=tierIds[Math.Max(0,tier.SelectedIndex)];populateTiers(prior);planEdited=tierEdited=true;source.Text=Locale.T("Manual record preserved");source.ForeColor=MeterTheme.Amber;change();};
        tier.SelectedIndexChanged+=(s,e)=>{if(!Locale.IsTranslating&&!loading&&!refreshingTier){planEdited=true;tierEdited=true;change();}};
        mode.SelectedIndexChanged+=(s,e)=>{if(!Locale.IsTranslating){update();change();}};purchase.ValueChanged+=(s,e)=>{update();change();};next.ValueChanged+=(s,e)=>change();enabled.CheckedChanged+=(s,e)=>change();update();dirty=false;
        Func<bool,bool> persist=show=>{
            FileStream lease=null;
            try{
                if(show&&next.Checked&&purchase.Checked&&next.Value.Date<purchase.Value.Date){MeterTheme.Error(Locale.T("Renewal/expiry date cannot precede purchase date."));return false;}
                lease=new FileStream(memberPath+".lock",FileMode.CreateNew,FileAccess.Write,FileShare.None);
                if(File.Exists(memberPath)&&new FileInfo(memberPath).Length>65536)throw new InvalidDataException(Locale.T("Subscription record is invalid. Restore a backup or check diagnostics."));
                var member=File.Exists(memberPath)?Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(memberPath,Encoding.UTF8)):new Dictionary<string,object>();if(member==null)throw new InvalidDataException(Locale.T("Subscription record is invalid. Restore a backup or check diagnostics."));member["enabled"]=show;
                if(planEdited||!member.ContainsKey("plan"))member["plan"]=ids[plan.SelectedIndex];
                var allowed=TiersFor(Value(member,"plan","other"));string selectedTier=tierIds[Math.Max(0,tier.SelectedIndex)];
                if(tierEdited||!member.ContainsKey("tier")||Array.IndexOf(allowed,Value(member,"tier","unknown"))<0)member["tier"]=Array.IndexOf(allowed,selectedTier)>=0?selectedTier:"unknown";
                member["planSource"]="manual";member["manualOverride"]=true;
                if(purchase.Checked)member["purchaseDate"]=purchase.Value.ToString("yyyy-MM-dd");else member.Remove("purchaseDate");
                member["kind"]=mode.SelectedIndex==2?"expiry":"renewal";member["monthlyEstimate"]=mode.SelectedIndex==0;member["annualEstimate"]=mode.SelectedIndex==3;member["estimated"]=mode.SelectedIndex==0||mode.SelectedIndex==3;
                if(next.Checked&&mode.SelectedIndex!=0&&mode.SelectedIndex!=3)member["date"]=next.Value.ToString("yyyy-MM-dd");else member.Remove("date");
                Write(memberPath,member);var prefs=Read(Path.Combine(root,"preferences.json"));prefs["setupComplete"]=true;Save(Path.Combine(root,"preferences.json"),prefs);data=member;dirty=false;planEdited=false;source.Text=Locale.T("Manual record preserved");source.ForeColor=MeterTheme.Amber;return true;
            }catch(IOException){MeterTheme.Error(Locale.T("Subscription record is busy. Try again."));return false;}catch(Exception ex){MeterTheme.Error(ex.Message);return false;}
            finally{if(lease!=null){lease.Dispose();File.Delete(memberPath+".lock");}}
        };
        Action reload=()=>{data=Read(memberPath);loading=true;plan.SelectedIndex=7;for(int i=0;i<ids.Length;i++)if(ids[i]==Value(data,"plan",""))plan.SelectedIndex=i;loadTier();mode.SelectedIndex=Value(data,"annualEstimate","")=="True"?3:Value(data,"monthlyEstimate","")=="True"||!data.ContainsKey("date")?0:Value(data,"kind","")=="expiry"?2:1;LoadDate(purchase,Value(data,"purchaseDate",""));LoadDate(next,Value(data,"date",""));enabled.Checked=data.Count>0&&Value(data,"enabled","True")!="False";update();loading=false;dirty=false;planEdited=tierEdited=false;source.Text=Locale.T(Value(data,"planSource","")=="desktop"?"Plan family detected from Codex desktop":"Manual record preserved");};
        Func<bool> resolve=()=>{if(!dirty)return true;var decision=MessageBox.Show(Locale.T("Save changes before leaving?"),form.Text,MessageBoxButtons.YesNoCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button3);if(decision==DialogResult.Cancel)return false;if(decision==DialogResult.Yes)return persist(enabled.Checked);reload();return true;};form.Tag=resolve;
        save.Click+=(s,e)=>{if(persist(enabled.Checked)){if(embedded)MeterTheme.Saved(save);else{form.DialogResult=DialogResult.OK;form.Close();}}};
        skip.Click+=(s,e)=>{if(persist(false)){form.DialogResult=DialogResult.OK;form.Close();}};
        form.FormClosing+=(s,e)=>{if(form.DialogResult!=DialogResult.OK&&!resolve())e.Cancel=true;};
        detect.Click+=(s,e)=>{
            if(!resolve())return;
            if(MessageBox.Show(Locale.T("Detect the plan family from Codex desktop? Manual tier and dates stay unchanged."),form.Text,MessageBoxButtons.OKCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)!=DialogResult.OK)return;
            detect.Enabled=false;source.Text=Locale.T("Detecting plan...");
            DetectPlan(form,new DirectoryInfo(root).Parent.FullName,"detect",result=>{detect.Enabled=true;bool ok=Value(result,"detected","")=="True";if(ok){data=Read(memberPath);loading=true;for(int i=0;i<ids.Length;i++)if(ids[i]==Value(data,"plan",""))plan.SelectedIndex=i;loadTier();loading=false;dirty=false;planEdited=false;source.Text=Locale.T("Plan family detected from Codex desktop");source.ForeColor=MeterTheme.Tint(Color.FromArgb(25,112,90));}else{source.Text=DetectionMessage(result);source.ForeColor=MeterTheme.Amber;}});
        };
        return form;
    }
}
