using System;
using System.Collections.Generic;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

internal static class MeterPreferences {
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
    static DateTimePicker DateInput(string name,string saved){
        DateTime date;bool known=DateTime.TryParseExact(saved,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out date);
        var input=new DateTimePicker{Name=name,ShowCheckBox=true,Format=DateTimePickerFormat.Custom,CustomFormat=known?"yyyy-MM-dd":" ",Dock=DockStyle.Fill,Checked=known};
        if(known)input.Value=date;input.Checked=known;input.ValueChanged+=(s,e)=>input.CustomFormat=input.Checked?"yyyy-MM-dd":" ";return input;
    }
    static void LoadDate(DateTimePicker input,string saved){DateTime date;bool known=DateTime.TryParseExact(saved,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out date);if(known)input.Value=date;input.Checked=known;input.CustomFormat=known?"yyyy-MM-dd":" ";}
    static Panel Field(string label,Control control){var panel=new Panel{Dock=DockStyle.Fill,Margin=new Padding(0,0,24,0)};var caption=MeterTheme.Label(label,10,MeterTheme.Ink);caption.Dock=DockStyle.Top;caption.Height=28;var box=new Panel{Dock=DockStyle.Top,Height=40,Padding=new Padding(0,3,0,0)};box.Controls.Add(control);panel.Controls.Add(box);panel.Controls.Add(caption);box.BringToFront();return panel;}
    internal static Form Create(string root,bool embedded){
        Directory.CreateDirectory(root);string memberPath=Path.Combine(root,"membership.json");var data=Read(memberPath);
        var form=new Form();form.Text=Locale.T("Codex Quota Sidebar - Settings");MeterTheme.Style(form,960,640);form.MinimizeBox=false;
        var body=MeterTheme.Body();body.AutoScroll=false;body.Padding=embedded?new Padding(0):new Padding(30,24,30,24);form.Controls.Add(body);if(!embedded)form.Controls.Add(MeterTheme.Header("Codex subscription record","Windows"));
        var content=new Panel{Name="planContent",Dock=DockStyle.Top,Height=530};body.Controls.Add(content);body.BringToFront();
        var optional=MeterTheme.Label("Only record your existing Codex subscription. No sign-up or purchase for this tool.",10,MeterTheme.Muted);optional.Dock=DockStyle.Top;optional.Height=46;content.Controls.Add(optional);
        var planRow=new TableLayoutPanel{Dock=DockStyle.Top,Height=94,ColumnCount=2,RowCount=1,Padding=new Padding(0,16,0,0)};planRow.RowStyles.Add(new RowStyle(SizeType.Percent,100));planRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));planRow.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,88));content.Controls.Add(planRow);planRow.BringToFront();
        var ids=new[]{"free","go","plus","pro","business","enterprise","edu","other"};
        var plan=new ComboBox{Name="plan",DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};plan.Items.AddRange(new object[]{"Free","Go","Plus","Pro","Business","Enterprise","Edu","Other / unknown"});plan.SelectedIndex=7;
        for(int i=0;i<ids.Length;i++)if(ids[i]==Value(data,"plan",""))plan.SelectedIndex=i;
        planRow.Controls.Add(Field("Plan badge",plan),0,0);var detect=MeterTheme.Button("detectPlan","Detect",false);detect.Anchor=AnchorStyles.Left|AnchorStyles.Top;detect.Height=38;detect.Width=84;detect.Margin=new Padding(4,30,0,10);planRow.Controls.Add(detect,1,0);
        var source=MeterTheme.Label(Value(data,"planSource","")=="desktop"?"Plan family detected from Codex desktop":"Manual record preserved",9,Value(data,"planSource","")=="desktop"?Color.FromArgb(25,112,90):MeterTheme.Amber);source.Name="planSource";source.Dock=DockStyle.Top;source.Height=42;content.Controls.Add(source);source.BringToFront();
        var fields=new TableLayoutPanel{Dock=DockStyle.Top,Height=186,ColumnCount=2,RowCount=2,Padding=new Padding(0,16,0,0)};fields.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));fields.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));fields.RowStyles.Add(new RowStyle(SizeType.Absolute,82));fields.RowStyles.Add(new RowStyle(SizeType.Absolute,82));content.Controls.Add(fields);fields.BringToFront();
        var tier=new ComboBox{Name="tier",DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};
        string[] tierIds={"unknown","100","200","500","standard","premium"};
        Action loadTier=()=>{string prior=Value(data,"tier","unknown");tier.Items.Clear();tier.Items.AddRange(new object[]{Locale.T("Unknown / not recorded"),"Pro 100","Pro 200","Pro 500","Business Standard","Business Premium"});tier.SelectedIndex=0;for(int i=0;i<tier.Items.Count;i++)if(tierIds[i]==prior)tier.SelectedIndex=i;};loadTier();
        var mode=new ComboBox{Name="dateMode",DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};mode.Items.AddRange(new object[]{Locale.T("Monthly estimate (purchase + one month)"),Locale.T("Manual renewal date"),Locale.T("Manual expiry date"),Locale.T("Business annual estimate")});mode.SelectedIndex=Value(data,"annualEstimate","")=="True"?3:Value(data,"monthlyEstimate","")=="True"||!data.ContainsKey("date")?0:Value(data,"kind","")=="expiry"?2:1;
        var purchase=DateInput("purchaseDate",Value(data,"purchaseDate",""));var next=DateInput("nextDate",Value(data,"date",""));
        foreach(var combo in new[]{plan,tier,mode})MeterTheme.SizeCombo(combo);
        purchase.MinimumSize=next.MinimumSize=new Size(0,36);
        fields.Controls.Add(Field("Specific tier (manual, optional)",tier),0,0);fields.Controls.Add(Field("Date type",mode),1,0);fields.Controls.Add(Field("Purchase date",purchase),0,1);fields.Controls.Add(Field("Renewal / expiry",next),1,1);
        planRow.Controls[0].Margin=new Padding(0,0,12,0);fields.GetControlFromPosition(1,0).Margin=fields.GetControlFromPosition(1,1).Margin=new Padding(0);
        var note=MeterTheme.Label("Dates are yours to enter. Detection never changes purchase or renewal dates. Leave blank to hide dates.",9,MeterTheme.Muted);note.Dock=DockStyle.Top;note.Height=46;content.Controls.Add(note);note.BringToFront();
        var enabled=new CheckBox{Name="membershipEnabled",Text=Locale.T("Show renewal date in sidebar and overview"),Dock=DockStyle.Top,Height=46,Checked=data.Count>0&&Value(data,"enabled","True")!="False"};content.Controls.Add(enabled);enabled.BringToFront();
        var buttons=new FlowLayoutPanel{Dock=DockStyle.Top,Height=70,Padding=new Padding(0,20,0,0),WrapContents=false};content.Controls.Add(buttons);buttons.BringToFront();
        var save=MeterTheme.Button("save","Save",true);save.Width=80;save.Margin=new Padding(0,0,14,0);var skip=MeterTheme.Button("skip","Skip / hide",false);var cancel=MeterTheme.Button("cancel","Cancel",false);cancel.DialogResult=DialogResult.Cancel;buttons.Controls.Add(save);if(!embedded){buttons.Controls.Add(skip);buttons.Controls.Add(cancel);form.CancelButton=cancel;}
        var hint=MeterTheme.Label("Changes apply after saving. No reconnect needed.",9,MeterTheme.Muted);hint.Dock=DockStyle.None;hint.Width=400;hint.Height=38;buttons.Controls.Add(hint);form.AcceptButton=save;
        bool arranging=false;
        Action arrange=()=>{
            if(arranging)return;arranging=true;
            try{
                float scale;using(var g=content.CreateGraphics())scale=form.Font.Size/10*g.DpiX/96f;
                int available=Math.Max(0,body.ClientSize.Height-body.Padding.Vertical);
                // Keep the approved spacing when it fits; reclaim whitespace before scrolling.
                float room=Math.Max(0,Math.Min(1,(available/scale-420)/110));
                int[] regular={46,94,42,186,46,46,70},compact={32,80,30,152,40,36,50};
                Control[] rows={optional,planRow,source,fields,note,enabled,buttons};
                int width=Math.Min((int)(760*scale),Math.Max(0,body.ClientSize.Width-body.Padding.Horizontal)),y=0;
                for(int i=0;i<rows.Length;i++){
                    int height=(int)Math.Floor((compact[i]+(regular[i]-compact[i])*room)*scale);
                    rows[i].Dock=DockStyle.None;rows[i].SetBounds(0,y,width,height);y+=height;
                }
                planRow.Padding=new Padding(0,(int)((8+8*room)*scale),0,0);
                detect.Margin=new Padding((int)(4*scale),(int)(30*scale),0,(int)(10*room*scale));
                fields.Padding=new Padding(0,(int)((8+8*room)*scale),0,0);
                float fieldHeight=(fields.Height-fields.Padding.Top-(int)(6*room*scale))/2f;
                foreach(RowStyle row in fields.RowStyles){row.SizeType=SizeType.Absolute;row.Height=fieldHeight;}
                buttons.Padding=new Padding(0,(int)((8+12*room)*scale),0,0);
                content.Height=y;
                body.AutoScroll=available<(int)(420*scale);
                body.AutoScrollMinSize=body.AutoScroll?new Size(0,y):Size.Empty;
            }finally{arranging=false;}
        };
        content.Resize+=(s,e)=>arrange();body.ClientSizeChanged+=(s,e)=>arrange();form.Shown+=(s,e)=>arrange();arrange();
        foreach(var p in new[]{planRow,fields})p.Paint+=(s,e)=>{using(var pen=new Pen(MeterTheme.Line))e.Graphics.DrawLine(pen,0,0,p.Width,0);};
        fields.Paint+=(s,e)=>{using(var pen=new Pen(MeterTheme.Line))e.Graphics.DrawLine(pen,0,fields.Height-1,fields.Width,fields.Height-1);};
        bool dirty=false,loading=false,planEdited=false,tierEdited=false;
        Action update=()=>{bool estimate=mode.SelectedIndex==0||mode.SelectedIndex==3;next.Enabled=!estimate;if(estimate){next.Checked=purchase.Checked;if(purchase.Checked)next.Value=mode.SelectedIndex==3?purchase.Value.AddYears(1):purchase.Value.AddMonths(1);next.CustomFormat=next.Checked?"yyyy-MM-dd":" ";}};
        Action change=()=>{if(!loading&&!Locale.IsTranslating)dirty=true;};
        plan.SelectedIndexChanged+=(s,e)=>{if(Locale.IsTranslating||loading||plan.SelectedIndex<0)return;planEdited=true;source.Text=Locale.T("Manual record preserved");source.ForeColor=MeterTheme.Amber;change();};
        tier.SelectedIndexChanged+=(s,e)=>{if(!Locale.IsTranslating&&!loading){planEdited=true;tierEdited=true;change();}};
        mode.SelectedIndexChanged+=(s,e)=>{if(!Locale.IsTranslating){update();change();}};purchase.ValueChanged+=(s,e)=>{update();change();};next.ValueChanged+=(s,e)=>change();enabled.CheckedChanged+=(s,e)=>change();update();dirty=false;
        Func<bool,bool> persist=show=>{
            FileStream lease=null;
            try{
                if(show&&next.Checked&&purchase.Checked&&next.Value.Date<purchase.Value.Date){MeterTheme.Error(Locale.T("Renewal/expiry date cannot precede purchase date."));return false;}
                lease=new FileStream(memberPath+".lock",FileMode.CreateNew,FileAccess.Write,FileShare.None);
                if(File.Exists(memberPath)&&new FileInfo(memberPath).Length>65536)throw new InvalidDataException(Locale.T("Subscription record is invalid. Restore a backup or check diagnostics."));
                var member=File.Exists(memberPath)?Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(memberPath,Encoding.UTF8)):new Dictionary<string,object>();if(member==null)throw new InvalidDataException(Locale.T("Subscription record is invalid. Restore a backup or check diagnostics."));member["enabled"]=show;
                if(planEdited||!member.ContainsKey("plan"))member["plan"]=ids[plan.SelectedIndex];
                if(tierEdited||!member.ContainsKey("tier"))member["tier"]=tierIds[Math.Max(0,tier.SelectedIndex)];
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
            DetectPlan(form,new DirectoryInfo(root).Parent.FullName,"detect",result=>{detect.Enabled=true;bool ok=Value(result,"detected","")=="True";if(ok){data=Read(memberPath);loading=true;for(int i=0;i<ids.Length;i++)if(ids[i]==Value(data,"plan",""))plan.SelectedIndex=i;loadTier();loading=false;dirty=false;planEdited=false;source.Text=Locale.T("Plan family detected from Codex desktop");source.ForeColor=Color.FromArgb(25,112,90);}else{source.Text=DetectionMessage(result);source.ForeColor=MeterTheme.Amber;}});
        };
        return form;
    }
}
