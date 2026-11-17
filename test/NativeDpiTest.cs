using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
internal static class NativeDpiTest {
    [System.Runtime.InteropServices.DllImport("user32.dll")]static extern bool PrintWindow(IntPtr window,IntPtr dc,uint flags);
    [System.Runtime.InteropServices.DllImport("user32.dll")]static extern bool ShowWindow(IntPtr window,int command);
    static void Assert(bool value,string message){if(!value)throw new Exception(message);}
    static void Check(Control parent){
        foreach(Control c in parent.Controls){
            if(!c.Visible)continue;
            var label=c as Label;
            if(label!=null&&!String.IsNullOrEmpty(c.Text))using(var g=c.CreateGraphics()){
                var required=TextRenderer.MeasureText(g,c.Text,c.Font,new Size(Math.Max(1,c.Width),Int32.MaxValue),TextFormatFlags.WordBreak|TextFormatFlags.NoPrefix);
                Assert(required.Height<=c.Height,"Text clipped: "+c.Name+" '"+c.Text+"' needs "+required+" actual "+c.Size);
            }
            var button=c as V3Button;
            if(button!=null)using(var g=c.CreateGraphics()){
                var required=TextRenderer.MeasureText(g,c.Text,c.Font,new Size(Int32.MaxValue,Int32.MaxValue),TextFormatFlags.NoPadding|TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine);
                int icon=String.IsNullOrEmpty(button.Glyph)?0:(int)((String.IsNullOrEmpty(c.Text)?20:28)*g.DpiX/96);
                Assert(required.Width+icon+8*g.DpiX/96<=c.Width,"Button text clipped: "+c.Name+" '"+c.Text+"'");
            }
            Check(c);
        }
    }
    [STAThread] static int Main(string[] args){
        Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);Locale.Set("en");Directory.CreateDirectory(args[0]);
        using(var window=new LaunchWindow(()=>{},()=>{},()=>{},()=>{})){
            window.Show();ShowWindow(window.Handle,5);window.BringToFront();window.Activate();Application.DoEvents();float dpi;using(var g=window.CreateGraphics())dpi=g.DpiX;
            Console.WriteLine("Actual window Graphics.DpiX="+dpi+"; no Control.Scale simulation");
            Console.WriteLine("Font="+window.Font+"; metric="+window.Controls.Find("metric3",true)[0].Font+"; autoscale="+window.AutoScaleDimensions+"; current="+window.CurrentAutoScaleDimensions);
            Assert(window.FormBorderStyle==FormBorderStyle.Sizable&&window.MaximizeBox,"Main window cannot resize/maximize");
            foreach(var size in new[]{new Size(1040,740),new Size(1184,792)}){
                window.ClientSize=size;Application.DoEvents();
                Assert(window.ClientSize==size,"Requested physical viewport was not honored: "+window.ClientSize);
                foreach(string page in new[]{"Usage overview","Sidebar content","Codex subscription record","Data and settings","Diagnostics","About project"}){
                    window.ShowPage(page);Application.DoEvents();
                    if(page=="Usage overview"){
                        window.UpdateState("mounted",new Dictionary<string,object>());
                        double now=(DateTime.UtcNow-new DateTime(1970,1,1)).TotalMilliseconds;
                        ((UsageOverview)window.Controls.Find("usageOverview",true)[0]).UpdateSnapshot(new Dictionary<string,object>{{"generatedAt",now},{"quotaAt",now},{"usageAt",now},{"creditBalance","162.811999999"},{"resetCredits",3},{"planBadge","Pro 100"},{"renewalDate","2026-12-13"},{"monthAverage",125350000},{"week",96900000},{"lifetime",3010000000d},{"daily",new Dictionary<string,object>{{"date",DateTime.Today.AddDays(-1).ToString("yyyy-MM-dd")},{"value",202650000}}},{"windows",new[]{new Dictionary<string,object>{{"minutes",300},{"remaining",62},{"resetsAt",now/1000+86400}},new Dictionary<string,object>{{"minutes",10080},{"remaining",37}}}}},true,now);
                    }
                    foreach(string lang in new[]{"en","zh-CN","zh-TW"}){
                        Locale.Set(lang);Application.DoEvents();Check(window);
                        if(page=="Sidebar content"||page=="Codex subscription record"){
                            var save=(Button)window.Controls.Find(page=="Sidebar content"?"saveDisplay":"save",true)[0];
                            int width=save.Width;save.Text=Locale.T("Saved successfully");Check(window);Assert(save.Width==width,"Saved feedback changed button geometry");save.Text=Locale.T("Save");
                        }
                        var overview=window.Controls.Find("usageOverview",true)[0] as UsageOverview;if(page=="Usage overview"){if(overview.HorizontalScroll.Visible){Console.WriteLine("Overflow client="+overview.ClientSize+" display="+overview.DisplayRectangle);foreach(Control c in overview.Controls)Console.WriteLine(c.Name+" "+c.Bounds);}Assert(!overview.HorizontalScroll.Visible,"Overview has horizontal overflow");}
                        using(var bitmap=new Bitmap(window.Width,window.Height)){using(var g=Graphics.FromImage(bitmap)){IntPtr dc=g.GetHdc();try{Assert(PrintWindow(window.Handle,dc,2),"Native window capture failed");}finally{g.ReleaseHdc(dc);}}bitmap.Save(Path.Combine(args[0],"dpi-"+dpi+"-"+size.Width+"-"+page.Replace(" ","-")+"-"+lang+".png"));}
                    }
                }
            }
            window.Finish();
        }
        Console.WriteLine("PASS: real system DPI, font metrics, six pages, three locales, narrow and regular sizes");return 0;
    }
}
