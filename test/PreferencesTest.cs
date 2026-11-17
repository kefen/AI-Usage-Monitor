using System;
using System.IO;
using System.Drawing;
using System.Windows.Forms;
internal static class PreferencesTest {
    static void TierCompatibility(string root){
        Directory.CreateDirectory(root);string path=Path.Combine(root,"membership.json");
        File.WriteAllText(path,"{\"enabled\":true,\"plan\":\"pro\",\"tier\":\"100\",\"purchaseDate\":\"2026-11-13\",\"date\":\"2026-12-13\",\"kind\":\"renewal\"}");
        using(var form=MeterPreferences.Create(root,true)){
            form.Show();Application.DoEvents();
            var plan=(ComboBox)form.Controls.Find("plan",true)[0];var tier=(ComboBox)form.Controls.Find("tier",true)[0];
            if(tier.Items.Count!=4||tier.Text!="Pro 100")throw new Exception("Pro must expose only compatible optional tiers");
            plan.SelectedIndex=4;
            if(tier.Items.Count!=3||tier.SelectedIndex!=0||tier.Items.Contains("Pro 100"))throw new Exception("Business retained an incompatible Pro tier");
            tier.SelectedIndex=2;
            foreach(string language in new[]{"zh-CN","zh-TW","en"}){Locale.Set(language);if(plan.SelectedIndex!=4||tier.SelectedIndex!=2||tier.Items.Count!=3)throw new Exception("Language switch changed the dependent tier selection");}
            foreach(int family in new[]{0,1,2,5,6,7}){plan.SelectedIndex=family;if(tier.Enabled||tier.Items.Count!=1)throw new Exception("Unsupported family exposed paid tiers");}
            plan.SelectedIndex=6;
            if(tier.Enabled||tier.Items.Count!=1||tier.SelectedIndex!=0)throw new Exception("Edu must not offer Pro or Business tiers");
            ((Button)form.Controls.Find("save",true)[0]).PerformClick();
            var saved=MeterPreferences.Read(path);
            if(Convert.ToString(saved["plan"])!="edu"||Convert.ToString(saved["tier"])!="unknown")throw new Exception("Save retained an incompatible tier");
            if(Convert.ToString(saved["purchaseDate"])!="2026-11-13"||Convert.ToString(saved["date"])!="2026-12-13")throw new Exception("Changing plan altered saved dates");
        }
        File.WriteAllText(path,"{\"plan\":\"edu\",\"tier\":\"100\"}");string prior=File.ReadAllText(path);
        using(var form=MeterPreferences.Create(root,true)){
            var tier=(ComboBox)form.Controls.Find("tier",true)[0];
            if(tier.Enabled||tier.SelectedIndex!=0)throw new Exception("Legacy incompatible record leaked into displayed tier");
            if(File.ReadAllText(path)!=prior)throw new Exception("Opening the form silently rewrote a legacy record");
        }
    }
    static void AssertContained(Control control,Control viewport){
        var bounds=control.RectangleToScreen(control.ClientRectangle);
        for(Control parent=control.Parent;parent!=null;parent=parent.Parent){
            if(!parent.RectangleToScreen(parent.ClientRectangle).Contains(bounds))throw new Exception("Preference control clipped: "+control.Name+" bounds="+bounds+" parent="+parent.Name+" "+parent.ClientRectangle);
            if(parent==viewport)return;
        }
        throw new Exception("Preference control is outside the test viewport: "+control.Name);
    }
    static void CompactLayout(string root){
        using(var host=new Form{Name="smallWorkArea",ClientSize=new Size(940,496),StartPosition=FormStartPosition.CenterScreen})
        using(var form=MeterPreferences.Create(Path.Combine(root,"compact"),true)){
            form.TopLevel=false;form.FormBorderStyle=FormBorderStyle.None;form.Dock=DockStyle.Fill;host.Controls.Add(form);host.Show();form.Show();
            float dpi;using(var g=host.CreateGraphics())dpi=g.DpiX/96f;
            foreach(int height in new[]{496,460,420,530,496}){
                host.ClientSize=new Size((int)(940*dpi),(int)(height*dpi));Application.DoEvents();
                foreach(string language in new[]{"en","zh-CN","zh-TW"}){
                    Locale.Set(language);Application.DoEvents();
                    foreach(string name in new[]{"save","detectPlan","plan","tier","dateMode","purchaseDate","nextDate","membershipEnabled","planSource"})AssertContained(form.Controls.Find(name,true)[0],host);
                    var body=(Panel)form.Controls.Find("planContent",true)[0].Parent;
                    var next=form.Controls.Find("nextDate",true)[0];var clear=form.Controls.Find("nextDateClear",true)[0];
                    if(!next.Enabled&&clear.Enabled)throw new Exception("Calculated renewal must not have an active independent clear action");
                    if(body.AutoScroll||body.VerticalScroll.Visible)throw new Exception("Normal small-work-area form must not scroll");
                    using(var bitmap=new Bitmap(host.Width,host.Height)){host.DrawToBitmap(bitmap,new Rectangle(0,0,host.Width,host.Height));bitmap.Save(Path.Combine(root,"compact-"+height+"-"+language+".png"));}
                }
            }
        }
        Locale.Set("en");
    }
    [STAThread] static int Main(string[] args){
        Application.EnableVisualStyles();Locale.Set("en");string root=args[0];Directory.CreateDirectory(root);
        TierCompatibility(Path.Combine(root,"tier-link"));
        CompactLayout(root);
        string empty=Path.Combine(root,"blank");Directory.CreateDirectory(empty);
        string locked=Path.Combine(root,"locked");Directory.CreateDirectory(locked);string lockPath=Path.Combine(locked,"membership.json.lock");File.WriteAllText(lockPath,"held");
        bool blocked=false;try{MeterPreferences.Save(Path.Combine(locked,"membership.json"),new object());}catch(IOException){blocked=true;}
        if(!blocked||!File.Exists(lockPath)||File.Exists(Path.Combine(locked,"membership.json")))throw new Exception("Manual save bypassed another plan writer's lock");File.Delete(lockPath);
        using(var blank=MeterPreferences.Create(empty,true)){
            blank.Show();Application.DoEvents();
            var purchase=(BlankDatePicker)blank.Controls.Find("purchaseDate",true)[0];
            if(purchase.ShowCheckBox||purchase.Checked)throw new Exception("Blank purchase date needs native calendar without fuzzy checkbox");
            ((Button)blank.Controls.Find("save",true)[0]).PerformClick();
            if(File.Exists(Path.Combine(empty,"membership.json"))&&File.ReadAllText(Path.Combine(empty,"membership.json")).Contains(DateTime.Today.ToString("yyyy-MM-dd")))throw new Exception("Empty record invented today's date");
        }
        foreach(string action in new[]{"save","cancel","skip"}){
            string previous=File.Exists(Path.Combine(root,"membership.json"))?File.ReadAllText(Path.Combine(root,"membership.json")):"";
            using(var timer=new Timer{Interval=300}){
                timer.Tick+=(s,e)=>{
                    if(Application.OpenForms.Count==0)return;
                    timer.Stop();var form=Application.OpenForms[0];
                    var selectedPlan=(ComboBox)form.Controls.Find("plan",true)[0];
                    int before=selectedPlan.SelectedIndex;
                    foreach(string language in new[]{"zh-CN","zh-TW","en"}){Locale.Set(language);if(selectedPlan.SelectedIndex!=before||String.IsNullOrEmpty(selectedPlan.Text))throw new Exception("Language switch lost plan selection");}
                    if(action=="save"){
                        ((CheckBox)form.Controls.Find("membershipEnabled",true)[0]).Checked=true;
                        ((BlankDatePicker)form.Controls.Find("purchaseDate",true)[0]).Value=new DateTime(2026,1,31);
                        ((BlankDatePicker)form.Controls.Find("purchaseDate",true)[0]).Checked=true;
                        if(((DateTimePicker)form.Controls.Find("nextDate",true)[0]).Value.Date!=new DateTime(2026,2,28))throw new Exception("Monthly preview mismatch");
                        var purchase=(BlankDatePicker)form.Controls.Find("purchaseDate",true)[0];var clear=(NavigationItem)form.Controls.Find("purchaseDateClear",true)[0];var next=(BlankDatePicker)form.Controls.Find("nextDate",true)[0];
                        if(!clear.Visible||clear.Height!=purchase.Height)throw new Exception("Clear-date icon must match the native date field height");
                        clear.PerformClick();if(purchase.Checked||next.Checked||clear.Visible)throw new Exception("Clearing purchase date did not clear its estimate and hide the clear action");
                        purchase.Value=new DateTime(2026,1,31);purchase.Checked=true;
                    }
                    using(var bitmap=new Bitmap(form.Width,form.Height)){form.DrawToBitmap(bitmap,new Rectangle(0,0,form.Width,form.Height));bitmap.Save(Path.Combine(root,"preferences-"+action+".png"));}
                    ((Button)form.Controls.Find(action,true)[0]).PerformClick();
                };
                timer.Start();MeterPreferences.Edit(root);
            }
            string json=File.ReadAllText(Path.Combine(root,"membership.json"));
            if(action=="save"&&(!json.Contains("2026-01-31")||!json.Contains("\"monthlyEstimate\":true")))throw new Exception("Purchase input not saved");
            if(action=="save"&&(!json.Contains("\"planSource\":\"manual\"")||!json.Contains("\"manualOverride\":true")))throw new Exception("Manual source lock not persisted");
            if(action=="cancel"&&json!=previous)throw new Exception("Cancel changed preferences");
            if(action=="skip"&&!json.Contains("\"enabled\":false"))throw new Exception("Skip did not hide membership");
            if(action=="skip"&&!json.Contains("2026-01-31"))throw new Exception("Hiding membership erased the saved purchase date");
        }
        Console.WriteLine("PASS: native preferences save, cancel, skip; fixture screenshots generated");return 0;
    }
}
