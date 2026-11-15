using System;
using System.IO;
using System.Drawing;
using System.Windows.Forms;
internal static class PreferencesTest {
    [STAThread] static int Main(string[] args){
        Application.EnableVisualStyles();string root=args[0];Directory.CreateDirectory(root);
        foreach(string action in new[]{"save","cancel","skip"}){
            string previous=File.Exists(Path.Combine(root,"membership.json"))?File.ReadAllText(Path.Combine(root,"membership.json")):"";
            using(var timer=new Timer{Interval=300}){
                timer.Tick+=(s,e)=>{
                    if(Application.OpenForms.Count==0)return;
                    timer.Stop();var form=Application.OpenForms[0];
                    if(action=="save"){
                        ((CheckBox)form.Controls.Find("membershipEnabled",true)[0]).Checked=true;
                        ((DateTimePicker)form.Controls.Find("purchaseDate",true)[0]).Value=new DateTime(2026,1,31);
                        if(((DateTimePicker)form.Controls.Find("nextDate",true)[0]).Value.Date!=new DateTime(2026,2,28))throw new Exception("Monthly preview mismatch");
                    }
                    using(var bitmap=new Bitmap(form.Width,form.Height)){form.DrawToBitmap(bitmap,new Rectangle(0,0,form.Width,form.Height));bitmap.Save(Path.Combine(root,"preferences-"+action+".png"));}
                    ((Button)form.Controls.Find(action,true)[0]).PerformClick();
                };
                timer.Start();MeterPreferences.Edit(root);
            }
            string json=File.ReadAllText(Path.Combine(root,"membership.json"));
            if(action=="save"&&(!json.Contains("2026-01-31")||!json.Contains("\"monthlyEstimate\":true")))throw new Exception("Purchase input not saved");
            if(action=="cancel"&&json!=previous)throw new Exception("Cancel changed preferences");
            if(action=="skip"&&!json.Contains("\"enabled\":false"))throw new Exception("Skip did not hide membership");
            if(action=="skip"&&!json.Contains("2026-01-31"))throw new Exception("Hiding membership erased the saved purchase date");
        }
        Console.WriteLine("PASS: native preferences save, cancel, skip; fixture screenshots generated");return 0;
    }
}
