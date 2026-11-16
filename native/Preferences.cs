using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;

internal static class MeterPreferences {
    static readonly JavaScriptSerializer Json=new JavaScriptSerializer();
    static Dictionary<string,object> Read(string path){try{return Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(path,Encoding.UTF8));}catch{return new Dictionary<string,object>();}}
    static string Value(Dictionary<string,object> data,string key,string fallback){return data.ContainsKey(key)?Convert.ToString(data[key]):fallback;}
    internal static void Save(string path,object data){
        string temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";
        try{File.WriteAllText(temp,Json.Serialize(data),new UTF8Encoding(false));if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);}
        finally{if(File.Exists(temp))File.Delete(temp);}
    }
    internal static bool EnsureReady(string root){
        var prefs=Read(Path.Combine(root,"preferences.json"));
        if(Value(prefs,"cdpConsent","")!="True"){
            if(!MeterTheme.Consent())return false;
            prefs["cdpConsent"]=true;Save(Path.Combine(root,"preferences.json"),prefs);
        }
        if(Value(prefs,"setupComplete","")!="True")Edit(root);
        return true;
    }
    internal static void Edit(string root){using(var form=Create(root,false))form.ShowDialog();}
    internal static Form Create(string root,bool embedded){
        Directory.CreateDirectory(root);
        var data=Read(Path.Combine(root,"membership.json"));
        {
            var form=new Form();
            form.Text=Locale.T("Codex Quota Sidebar - Settings");MeterTheme.Style(form,900,640);form.MinimizeBox=false;
            var body=MeterTheme.Body();form.Controls.Add(body);if(!embedded)form.Controls.Add(MeterTheme.Header(Locale.T("Codex subscription record"),"Windows"));else body.Padding=new Padding(0);
            var grid=new TableLayoutPanel{Dock=DockStyle.Top,Height=270,Padding=new Padding(0),ColumnCount=2,RowCount=5};
            grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,145));grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            for(int i=0;i<5;i++)grid.RowStyles.Add(new RowStyle(SizeType.Absolute,48));body.Controls.Add(grid);
            var optional=MeterTheme.Label(Locale.T("No sign-up or purchase for this tool. Records are optional."),10,MeterTheme.Muted);optional.Dock=DockStyle.Top;optional.Height=46;body.Controls.Add(optional);grid.BringToFront();
            var enabled=new CheckBox{Name="membershipEnabled",Text=Locale.T("Show Codex renewal date"),AutoSize=true,Checked=data.Count>0&&Value(data,"enabled","True")!="False"};
            grid.Controls.Add(enabled,0,0);grid.SetColumnSpan(enabled,2);
            var ids=new[]{"plus","pro","pro","pro","pro","business","business","business","enterprise","edu","free","go","other"};
            var tiers=new[]{"","unknown","100","200","500","unknown","standard","premium","","","","",""};
            var plan=new ComboBox{Name="plan",DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};plan.Items.AddRange(new object[]{"Plus","Pro / unknown tier","Pro 100","Pro 200","Pro 500","Business / unknown seat","Business Standard","Business Premium","Enterprise","Edu","Free","Go","Other / unknown"});plan.SelectedIndex=12;
            for(int i=0;i<ids.Length;i++)if(ids[i]==Value(data,"plan","")&&(tiers[i]==Value(data,"tier","unknown")||tiers[i]=="")){plan.SelectedIndex=i;break;}
            grid.Controls.Add(new Label{Text=Locale.T("Plan"),AutoSize=true},0,1);grid.Controls.Add(plan,1,1);
            var purchase=new DateTimePicker{Name="purchaseDate",Format=DateTimePickerFormat.Custom,CustomFormat="yyyy-MM-dd",Dock=DockStyle.Fill};
            DateTime date;if(DateTime.TryParse(Value(data,"purchaseDate",""),out date))purchase.Value=date;
            grid.Controls.Add(new Label{Text=Locale.T("Purchase date"),AutoSize=true},0,2);grid.Controls.Add(purchase,1,2);
            var mode=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Dock=DockStyle.Fill};mode.Items.AddRange(new object[]{Locale.T("Monthly estimate (purchase + one month)"),Locale.T("Manual renewal date"),Locale.T("Manual expiry date")});
            mode.SelectedIndex=Value(data,"kind","")=="expiry"?2:data.ContainsKey("date")?1:0;
            mode.Items.Add("Business annual estimate");if(Value(data,"annualEstimate","")=="True")mode.SelectedIndex=3;
            grid.Controls.Add(new Label{Text=Locale.T("Date type"),AutoSize=true},0,3);grid.Controls.Add(mode,1,3);
            var next=new DateTimePicker{Name="nextDate",Format=DateTimePickerFormat.Custom,CustomFormat="yyyy-MM-dd",Dock=DockStyle.Fill,Value=DateTime.Today.AddMonths(1)};
            if(DateTime.TryParse(Value(data,"date",""),out date))next.Value=date;
            grid.Controls.Add(new Label{Text=Locale.T("Renewal / expiry"),AutoSize=true},0,4);grid.Controls.Add(next,1,4);
            Action update=()=>{bool free=ids[plan.SelectedIndex]=="free";enabled.Enabled=!free;if(free)enabled.Checked=false;if(mode.SelectedIndex==3&&ids[plan.SelectedIndex]!="business")mode.SelectedIndex=1;purchase.Enabled=mode.Enabled=enabled.Checked;next.Enabled=enabled.Checked&&mode.SelectedIndex!=0&&mode.SelectedIndex!=3;if(mode.SelectedIndex==0)next.Value=purchase.Value.AddMonths(1);if(mode.SelectedIndex==3)next.Value=purchase.Value.AddYears(1);};
            plan.SelectedIndexChanged+=(s,e)=>{if(Locale.IsTranslating||plan.SelectedIndex<0)return;if(new[]{"business","enterprise","edu","free"}.Contains(ids[plan.SelectedIndex])){enabled.Checked=false;mode.SelectedIndex=1;}};
            Action guardMode=()=>{if(new[]{"enterprise","edu"}.Contains(ids[plan.SelectedIndex])&&mode.SelectedIndex==0)mode.SelectedIndex=1;};
            enabled.CheckedChanged+=(s,e)=>{guardMode();update();};mode.SelectedIndexChanged+=(s,e)=>{guardMode();update();};purchase.ValueChanged+=(s,e)=>update();guardMode();update();
            foreach(Control control in grid.Controls){if(control is Label)control.ForeColor=MeterTheme.Muted;if(control is ComboBox || control is DateTimePicker)control.Margin=new Padding(0,4,0,6);}
            var buttons=MeterTheme.Footer();form.Controls.Add(buttons);body.BringToFront();
            var save=MeterTheme.Button("save",Locale.T("Save"),true);var skip=MeterTheme.Button("skip",Locale.T("Skip / hide"),false);var cancel=MeterTheme.Button("cancel",Locale.T("Cancel"),false);cancel.DialogResult=DialogResult.Cancel;buttons.Controls.Add(save);buttons.Controls.Add(skip);buttons.Controls.Add(cancel);form.CancelButton=cancel;form.AcceptButton=save;
            Action<bool> persist=show=>{
                try{
                    if(show&&mode.SelectedIndex!=0&&mode.SelectedIndex!=3&&next.Value.Date<purchase.Value.Date){MeterTheme.Error("Renewal/expiry date cannot precede purchase date.");return;}
                    var member=new Dictionary<string,object>(data);member["enabled"]=show;
                    if(show)member.Remove("date");
                    member["plan"]=ids[plan.SelectedIndex];member["tier"]=tiers[plan.SelectedIndex];
                    if(show){member["purchaseDate"]=purchase.Value.ToString("yyyy-MM-dd");member["kind"]=mode.SelectedIndex==2?"expiry":"renewal";member["monthlyEstimate"]=mode.SelectedIndex==0;member["annualEstimate"]=mode.SelectedIndex==3;member["estimated"]=mode.SelectedIndex==0||mode.SelectedIndex==3;if(mode.SelectedIndex!=0&&mode.SelectedIndex!=3)member["date"]=next.Value.ToString("yyyy-MM-dd");}
                    Save(Path.Combine(root,"membership.json"),member);
                    var prefs=Read(Path.Combine(root,"preferences.json"));prefs["setupComplete"]=true;Save(Path.Combine(root,"preferences.json"),prefs);form.DialogResult=DialogResult.OK;form.Close();
                }catch(Exception ex){MeterTheme.Error(ex.Message);}
            };
            bool dirty=false;
            foreach(Control c in new Control[]{enabled,plan,purchase,mode,next}){
                var cb=c as CheckBox;if(cb!=null)cb.CheckedChanged+=(s,e)=>{if(!Locale.IsTranslating)dirty=true;};
                var combo=c as ComboBox;if(combo!=null)combo.SelectedIndexChanged+=(s,e)=>{if(!Locale.IsTranslating)dirty=true;};
                var datePicker=c as DateTimePicker;if(datePicker!=null)datePicker.ValueChanged+=(s,e)=>{if(!Locale.IsTranslating)dirty=true;};
            }
            form.Tag=new Func<bool>(()=>!dirty||MessageBox.Show(Locale.T("Discard unsaved changes?"),"Codex Quota Sidebar",MessageBoxButtons.OKCancel,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)==DialogResult.OK);
            save.Click+=(s,e)=>persist(enabled.Checked);skip.Click+=(s,e)=>persist(false);
            form.FormClosing+=(s,e)=>{if(form.DialogResult!=DialogResult.OK&&dirty&&!((Func<bool>)form.Tag)())e.Cancel=true;};
            return form;
        }
    }
}
