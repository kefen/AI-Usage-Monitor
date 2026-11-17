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
            if(c is NavigationItem&&!String.IsNullOrEmpty(c.Text))using(var g=c.CreateGraphics()){
                var required=TextRenderer.MeasureText(g,c.Text,c.Font,new Size(Int32.MaxValue,Int32.MaxValue),TextFormatFlags.NoPadding|TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine);
                Assert(required.Width+40*g.DpiX/96<=c.Width,"Navigation label clipped: "+c.Text);
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
            var defaultOverview=(UsageOverview)window.Controls.Find("usageOverview",true)[0];
            Assert(!defaultOverview.VerticalScroll.Visible,"Default overview should fit without scrolling");
            Assert(Screen.FromControl(window).WorkingArea.Contains(window.Bounds),"Default window exceeds the available screen");
            foreach(string language in new[]{"zh-CN","zh-TW","en"}){Locale.Set(language);Application.DoEvents();Assert(!defaultOverview.VerticalScroll.Visible,"Default translated overview needs scrolling: "+language);}
            using(var fixture=new Form{ClientSize=new Size(560,820)}){
                var responsive=new UsageOverview();fixture.Controls.Add(responsive);fixture.Show();Application.DoEvents();
                foreach(Control track in responsive.Controls.Find("linearScale2",true))Assert(track.Width>=80*dpi/96,"Narrow overview lost its token chart");
                responsive.Dock=DockStyle.None;responsive.Size=new Size(550,950);Application.DoEvents();
                var shortCell=responsive.Controls.Find("group-short",true)[0];var weekCell=responsive.Controls.Find("group-week",true)[0];
                Assert(shortCell.Top==weekCell.Top&&weekCell.Left>shortCell.Left,"Tall narrow view should reflow quota cells horizontally");
                Assert(responsive.Controls.Find("group-daily",true)[0].Top>weekCell.Bottom,"Tall narrow view should stack Token section below quota");
                Assert(!responsive.VerticalScroll.Visible&&!responsive.HorizontalScroll.Visible,"Tall narrow overview should fit its layout");
                fixture.Close();
            }
            var localizedNav=window.Controls.Find("Usage overview",true)[0];int repaintRequests=0;localizedNav.Invalidated+=(s,e)=>repaintRequests++;
            var languageTimer=System.Diagnostics.Stopwatch.StartNew();Locale.Set("zh-CN");languageTimer.Stop();Console.WriteLine("Synchronous language switch and repaint: "+languageTimer.ElapsedMilliseconds+"ms");Assert(localizedNav.Text==Locale.T("Usage overview")&&repaintRequests>0,"Language switch did not invalidate navigation immediately");Locale.Set("en");
            Assert(window.Controls.Find("footerVersion",true).Length==1,"Version must have a permanent footer field separate from feedback");
            var version=window.Controls.Find("footerVersion",true)[0];string versionText=version.Text;window.Feedback("Connection feedback fixture");
            Assert(version.Text==versionText&&version.Text.Contains(MeterTheme.Version),"Feedback replaced the version");
            var exitAction=window.Controls.Find("exitSoftware",true)[0];var reconnectAction=window.Controls.Find("reconnect",true)[0];var openAction=window.Controls.Find("openCodex",true)[0];
            Assert(exitAction.Width==reconnectAction.Width&&reconnectAction.Width==openAction.Width,"Footer actions must have equal widths");
            Assert(reconnectAction.Left-exitAction.Right==openAction.Left-reconnectAction.Right,"Footer action gaps must be equal");
            Assert(Math.Abs(version.RectangleToScreen(version.ClientRectangle).Left-localizedNav.RectangleToScreen(localizedNav.ClientRectangle).Left)<=1,"Version must align with the navigation inset");
            var languageBox=(ComboBox)window.Controls.Find("language",true)[0];using(var g=languageBox.CreateGraphics()){
                int text=TextRenderer.MeasureText(g,languageBox.Text,languageBox.Font,new Size(Int32.MaxValue,Int32.MaxValue),TextFormatFlags.NoPadding|TextFormatFlags.SingleLine).Width;
                Assert(languageBox.Width-text<=SystemInformation.VerticalScrollBarWidth+16*dpi/96,"Language text and arrow are unnecessarily far apart");
            }
            window.UpdateState("starting",new Dictionary<string,object>());
            var progress=window.Controls.Find("connectionProgress",true)[0];var status=window.Controls.Find("statusDetail",true)[0];
            Assert(progress.Width<=200*dpi/96&&Math.Abs(progress.Right-status.Right)<=1,"Connection progress must be compact and aligned with its status");
            window.UpdateState("mounted",new Dictionary<string,object>());
            Assert(status.Text==Locale.T("Connected")&&!progress.Visible,"Connected status retained temporary connecting text or animation");
            var overviewNav=(NavigationItem)window.Controls.Find("Usage overview",true)[0];var displayNav=(NavigationItem)window.Controls.Find("Sidebar content",true)[0];
            overviewNav.Focus();overviewNav.PerformClick();displayNav.Focus();displayNav.PerformClick();Application.DoEvents();
            using(var pixels=new Bitmap(overviewNav.Width,overviewNav.Height)){
                overviewNav.DrawToBitmap(pixels,overviewNav.ClientRectangle);
                Assert(pixels.GetPixel(overviewNav.Width/2,0).ToArgb()==overviewNav.Parent.BackColor.ToArgb()&&pixels.GetPixel(0,overviewNav.Height/2).ToArgb()==overviewNav.Parent.BackColor.ToArgb(),"Inactive navigation retained a colored native border after focus changed");
            }
            foreach(var size in new[]{new Size(900,1000),new Size(1040,740),new Size(1184,792),new Size(1440,1000)}){
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
                        if(page=="Usage overview"&&size.Width==1440){Console.WriteLine("Effective large viewport="+overview.ClientSize+" requested="+window.ClientSize);if(overview.ClientSize.Height>=Math.Ceiling(544*dpi/96))Assert(!overview.VerticalScroll.Visible,"Sufficient overview viewport should not require vertical scrolling");}
                        var footerFeedback=window.Controls.Find("footerFeedback",true)[0];Assert(!String.IsNullOrEmpty(footerFeedback.Text)||!footerFeedback.Visible,"Empty feedback label is covering the version");
                        if(page=="Usage overview"){
                            var planField=overview.Controls.Find("metric9",true)[0].Parent;var renewalField=overview.Controls.Find("metric10",true)[0].Parent;var averageField=overview.Controls.Find("metric5",true)[0].Parent;
                            Assert(planField.RectangleToScreen(planField.ClientRectangle).Left==overview.RectangleToScreen(overview.ClientRectangle).Left,"Plan metadata must align with the left data column");
                            if(overview.Width/dpi*96>=690||overview.Height/dpi*96<660)Assert(Math.Abs(renewalField.RectangleToScreen(renewalField.ClientRectangle).Left-averageField.RectangleToScreen(averageField.ClientRectangle).Left)<=1,"Renewal metadata must align with the right data column");
                            foreach(string trackName in new[]{"linearScale2","linearScale3"})Assert(overview.Controls.Find(trackName,true)[0].Width>=64*dpi/96,"Responsive chart disappeared: "+trackName);
                            foreach(Control label in renewalField.Controls)if(label is Label&&label.Text==Locale.T("Renewal"))using(var g=label.CreateGraphics())Assert(TextRenderer.MeasureText(g,label.Text,label.Font,new Size(Int32.MaxValue,Int32.MaxValue),TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine).Width<=label.Width,"Immediate language switch clipped the renewal label");
                        }
                        using(var bitmap=new Bitmap(window.Width,window.Height)){using(var g=Graphics.FromImage(bitmap)){IntPtr dc=g.GetHdc();try{Assert(PrintWindow(window.Handle,dc,2),"Native window capture failed");}finally{g.ReleaseHdc(dc);}}bitmap.Save(Path.Combine(args[0],"dpi-"+dpi+"-"+size.Width+"-"+page.Replace(" ","-")+"-"+lang+".png"));}
                    }
                }
            }
            window.Finish();
        }
        Console.WriteLine("PASS: real system DPI, font metrics, six pages, three locales, narrow and regular sizes");return 0;
    }
}
