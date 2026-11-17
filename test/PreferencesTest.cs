using System;
using System.IO;
using System.Drawing;
using System.Windows.Forms;
internal static class PreferencesTest {
    [STAThread] static int Main(string[] args){
        Application.EnableVisualStyles();Locale.Set("en");string root=args[0];Directory.CreateDirectory(root);
        string empty=Path.Combine(root,"blank");Directory.CreateDirectory(empty);
        string locked=Path.Combine(root,"locked");Directory.CreateDirectory(locked);string lockPath=Path.Combine(locked,"membership.json.lock");File.WriteAllText(lockPath,"held");
        bool blocked=false;try{MeterPreferences.Save(Path.Combine(locked,"membership.json"),new object());}catch(IOException){blocked=true;}
        if(!blocked||!File.Exists(lockPath)||File.Exists(Path.Combine(locked,"membership.json")))throw new Exception("Manual save bypassed another plan writer's lock");File.Delete(lockPath);
        using(var blank=MeterPreferences.Create(empty,true)){
            blank.Show();Application.DoEvents();
            var purchase=(DateTimePicker)blank.Controls.Find("purchaseDate",true)[0];
            if(!purchase.ShowCheckBox||purchase.Checked)throw new Exception("Blank purchase date must stay optional, not silently become today");
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
                        ((DateTimePicker)form.Controls.Find("purchaseDate",true)[0]).Value=new DateTime(2026,1,31);
                        ((DateTimePicker)form.Controls.Find("purchaseDate",true)[0]).Checked=true;
                        if(((DateTimePicker)form.Controls.Find("nextDate",true)[0]).Value.Date!=new DateTime(2026,2,28))throw new Exception("Monthly preview mismatch");
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
