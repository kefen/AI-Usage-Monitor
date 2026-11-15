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
        Application.EnableVisualStyles();root=args[0];Directory.CreateDirectory(root);
        foreach(bool accept in new[]{false,true})using(var timer=new Timer{Interval=250}){
            timer.Tick+=(s,e)=>{if(Application.OpenForms.Count==0)return;timer.Stop();var form=Application.OpenForms[0];var confirm=(Button)form.Controls.Find("confirm",true)[0];Assert(!confirm.Enabled,"Consent defaults to accepted");if(accept){((CheckBox)form.Controls.Find("consentAccepted",true)[0]).Checked=true;Assert(confirm.Enabled,"Consent did not unlock");}Capture(form,"consent-"+accept);((Button)form.Controls.Find(accept?"confirm":"cancel",true)[0]).PerformClick();};
            timer.Start();Assert(MeterTheme.Consent()==accept,"Consent decision mismatch");
        }
        int retries=0,opens=0;
        using(var window=new LaunchWindow(()=>opens++,()=>retries++,()=>{},()=>{})){
            window.Present();window.UpdateState("starting",new Dictionary<string,object>());Capture(window,"startup");
            window.UpdateState("failed",new Dictionary<string,object>{{"code","Codex preparation failed. Run Diagnose.cmd."}});Capture(window,"retry");((Button)window.Controls.Find("reconnect",true)[0]).PerformClick();Assert(retries==1,"Retry callback missing");
            window.UpdateState("mounted",new Dictionary<string,object>{{"quotaAvailable",true},{"usageAvailable",false},{"updatedAt","2026-01-01T12:00:00Z"}});Capture(window,"connected");Assert(window.Controls.Find("reconnect",true)[0].Enabled,"Reconnect must work with an existing monitor");
            ((Button)window.Controls.Find("openCodex",true)[0]).PerformClick();Assert(opens==1,"Open action not dispatched");
            window.Feedback("Activation requested");window.UpdateState("mounted",new Dictionary<string,object>());Assert(window.Controls.Find("statusDetail",true)[0].Text=="Activation requested","Polling erased action feedback");
            window.Scale(new SizeF(1.5f,1.5f));Capture(window,"connected-150");window.Finish();
        }
        using(var setup=new SetupWindow("User profile / Documents / Codex / Apps",()=>{},()=>{})){
            setup.Show();Capture(setup,"install");((Button)setup.Controls.Find("install",true)[0]).PerformClick();
            var end=DateTime.UtcNow.AddSeconds(5);while(!setup.Controls.Find("install",true)[0].Enabled&&DateTime.UtcNow<end){Application.DoEvents();System.Threading.Thread.Sleep(10);}
            Assert(setup.Controls.Find("install",true)[0].Enabled,"Setup worker stalled");Capture(setup,"installed");setup.Close();
        }
        Console.WriteLine("PASS: native consent, real status states, retry callback, installer, 150% layout fixtures");return 0;
    }
}
