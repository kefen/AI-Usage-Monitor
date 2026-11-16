using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

internal static class NativeVisualTest {
    static string root;
    static void Assert(bool value,string message){if(!value)throw new Exception(message);}
    static void Capture(Form form,string name){
        Application.DoEvents();
        foreach(Control c in form.Controls)foreach(Control other in form.Controls)if(c!=other&&c.Visible&&other.Visible)Assert(!c.Bounds.IntersectsWith(other.Bounds),"Overlapping window regions: "+name);
        Check(form);
        using(var bitmap=new Bitmap(form.Width,form.Height)){form.DrawToBitmap(bitmap,new Rectangle(0,0,form.Width,form.Height));bitmap.Save(Path.Combine(root,name+".png"));}
    }
    static void Check(Control parent){foreach(Control c in parent.Controls){if(c is Button&&c.Visible){var screen=c.RectangleToScreen(c.ClientRectangle);Assert(parent.FindForm().RectangleToScreen(parent.FindForm().ClientRectangle).Contains(screen),"Button outside window: "+c.Name);Assert(c.Parent.ClientRectangle.IntersectsWith(c.Bounds),"Button outside parent: "+c.Name);}Check(c);}}
    [STAThread] static int Main(string[] args){
        Application.EnableVisualStyles();Locale.Set("en");root=args[0];Directory.CreateDirectory(root);
        foreach(bool accept in new[]{false,true})using(var timer=new Timer{Interval=250}){
            timer.Tick+=(s,e)=>{if(Application.OpenForms.Count==0)return;timer.Stop();var form=Application.OpenForms[0];var confirm=(Button)form.Controls.Find("confirm",true)[0];Assert(!confirm.Enabled,"Consent defaults to accepted");if(accept){((CheckBox)form.Controls.Find("consentAccepted",true)[0]).Checked=true;Assert(confirm.Enabled,"Consent did not unlock");}Capture(form,"consent-"+accept);((Button)form.Controls.Find(accept?"confirm":"cancel",true)[0]).PerformClick();};
            timer.Start();Assert(MeterTheme.Consent()==accept,"Consent decision mismatch");
        }
        int retries=0,opens=0;
        foreach(bool accept in new[]{false,true})using(var timer=new Timer{Interval=250}){
            timer.Tick+=(s,e)=>{if(Application.OpenForms.Count==0)return;timer.Stop();var form=Application.OpenForms[0];Assert(((Button)form.AcceptButton).Name=="cancel","Restart must default to cancel");Capture(form,"restart-"+accept);((Button)form.Controls.Find(accept?"restartConfirm":"cancel",true)[0]).PerformClick();};
            timer.Start();Assert(MeterRestartDialog.Confirm("Save your work before restarting. This fixture does not close Codex.")==accept,"Restart decision mismatch");
        }
        using(var window=new LaunchWindow(()=>opens++,()=>retries++,()=>{},()=>{})){
            window.Present();window.UpdateState("starting",new Dictionary<string,object>());Capture(window,"startup");
            window.UpdateState("failed",new Dictionary<string,object>{{"code","Codex preparation failed. Run Diagnose.cmd."}});Capture(window,"retry");((Button)window.Controls.Find("reconnect",true)[0]).PerformClick();Assert(retries==1,"Retry callback missing");
            window.UpdateState("mounted",new Dictionary<string,object>{{"quotaAvailable",true},{"usageAvailable",false},{"updatedAt","2026-01-01T12:00:00Z"}});Capture(window,"connected");Assert(window.Controls.Find("reconnect",true)[0].Enabled,"Reconnect must work with an existing monitor");
            foreach(string language in new[]{"en","zh-CN","zh-TW"}){
                Locale.Set(language);
                double now=(DateTime.UtcNow-new DateTime(1970,1,1)).TotalMilliseconds;
                var metrics=(UsageOverview)window.Controls.Find("metric0",true)[0].Parent.Parent;
                metrics.UpdateSnapshot(new Dictionary<string,object>{{"generatedAt",now},{"quotaAt",now},{"usageAt",now},{"week",96900000},{"lifetime",2800000000d},{"daily",new Dictionary<string,object>{{"date","2026-11-14"},{"value",47500000}}},{"windows",new[]{new Dictionary<string,object>{{"minutes",300},{"remaining",75}},new Dictionary<string,object>{{"minutes",10080},{"remaining",68}}}}},true,now);
                Capture(window,"overview-"+language);
            }
            Locale.Set("en");
            foreach(string section in new[]{"Sidebar content","Codex subscription record","Data and settings","Diagnostics","About project","Usage overview"}){
                var buttons=window.Controls.Find(section,true);Assert(buttons.Length==1,"Missing navigation: "+section);
                ((Button)buttons[0]).PerformClick();Application.DoEvents();
                int topLevel=0;foreach(Form f in Application.OpenForms)if(f.TopLevel&&f.Visible)topLevel++;
                Assert(topLevel==1,"Navigation opened a separate top-level window");
                Capture(window,"page-"+section.Replace(" ","-"));
                foreach(string language in new[]{"zh-CN","zh-TW","en"}){Locale.Set(language);Capture(window,"page-"+section.Replace(" ","-")+"-"+language);}
            }
            ((Button)window.Controls.Find("openCodex",true)[0]).PerformClick();Assert(opens==1,"Open action not dispatched");
            window.Feedback("Activation requested");window.UpdateState("mounted",new Dictionary<string,object>());Assert(window.Controls.Find("statusDetail",true)[0].Text=="Activation requested","Polling erased action feedback");
            window.Scale(new SizeF(1.5f,1.5f));Capture(window,"connected-150");window.Finish();
        }
        int installs=0,launches=0;
        string destination=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"wizard");
        using(var setup=new SetupWindow(destination,()=>{if(++installs==1)throw new IOException("Test failure; retry is safe.");},()=>launches++,()=>@"C:\Program Files\WindowsApps\OpenAI.Codex",()=>{})){
            setup.Show();Wait(setup);Capture(setup,"install-environment");Click(setup);
            var path=(TextBox)setup.Controls.Find("destination",true)[0];path.Text=@"D:\CodexTools\CodexQuotaSidebar";Capture(setup,"install-location");
            setup.Scale(new SizeF(1.5f,1.5f));Capture(setup,"location-150");setup.Scale(new SizeF(2f/3f,2f/3f));
            path.Text="relative";Click(setup);Capture(setup,"invalid-location");
            Assert(setup.Controls.Find("setupError",true).Length==1,"Invalid destination must show inline feedback");
            ((TextBox)setup.Controls.Find("destination",true)[0]).Text=destination;Click(setup);
            foreach(string language in new[]{"en","zh-CN","zh-TW"}){Locale.Set(language);Capture(setup,"options-"+language);}Locale.Set("en");
            Capture(setup,"install-options");Click(setup);Wait(setup);
            Assert(installs==1,"Install callback missing");Capture(setup,"install-failed");Click(setup);Wait(setup);
            Assert(installs==2,"Retry did not invoke install");Capture(setup,"installed");
            Assert(launches==0,"Installer connected without consent");
            setup.Scale(new SizeF(1.5f,1.5f));Capture(setup,"installed-150");Click(setup);Assert(launches==1,"Connect callback missing");
        }
        Console.WriteLine("PASS: native consent, real status states, retry callback, installer, 150% layout fixtures");return 0;
    }
    static void Click(Form form){((Button)form.Controls.Find("install",true)[0]).PerformClick();Application.DoEvents();}
    static void Wait(Form form){var end=DateTime.UtcNow.AddSeconds(6);while(!form.Controls.Find("install",true)[0].Enabled&&DateTime.UtcNow<end){Application.DoEvents();System.Threading.Thread.Sleep(10);}Assert(form.Controls.Find("install",true)[0].Enabled,"Setup worker stalled");}
}

