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
                Assert(required.Width+icon+8*g.DpiX/96<=c.Width,"Button text clipped: "+c.Name+" '"+c.Text+"' width "+c.Width+" text "+required.Width);
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
            Assert(window.Controls.Find("language",true).Length==0,"Language belongs in settings");
            var updateAction=(Button)window.Controls.Find("installUpdate",true)[0];
            var updateSlot=updateAction.Parent;
            Assert(!updateSlot.Visible,"Update action must be hidden until a new version is available");
            updateSlot.Visible=true;updateAction.Visible=true;
            var initialSize=window.ClientSize;
            foreach(var width in new[]{900,1184,1440}){
                window.ClientSize=new Size(width,initialSize.Height);
                foreach(string lang in new[]{"en","zh-CN","zh-TW"}){
                    Locale.Set(lang);Application.DoEvents();
                    var updateBounds=updateAction.RectangleToScreen(updateAction.ClientRectangle);
                    Assert(updateAction.Text==Locale.T("Update available")&&updateAction.Enabled,"Update action lacks a visible localized label");
                    Assert(updateSlot.ClientRectangle.Contains(updateAction.Bounds),"Update action clipped: "+updateAction.Bounds+" slot "+updateSlot.ClientRectangle);
                    Check(updateSlot);
                }
            }
            using(var bitmap=new Bitmap(window.Width,window.Height)){
                window.DrawToBitmap(bitmap,new Rectangle(Point.Empty,bitmap.Size));
                bitmap.Save(Path.Combine(args[0],"updated-header-"+dpi+".png"));
            }
            if(Environment.GetEnvironmentVariable("CQS_TEST_HEADER_ONLY")=="1"){
                Console.WriteLine("PASS: update and language controls at three widths and in three languages");window.Finish();return 0;
            }
            window.ClientSize=initialSize;
            updateSlot.Visible=false;
            var defaultOverview=(UsageOverview)window.Controls.Find("usageOverview",true)[0];
            Assert(!defaultOverview.VerticalScroll.Visible,"Default overview should fit without scrolling");
            Assert(Screen.FromControl(window).WorkingArea.Contains(window.Bounds),"Default window exceeds the available screen");
            foreach(string language in new[]{"zh-CN","zh-TW","en"}){Locale.Set(language);Application.DoEvents();Assert(!defaultOverview.VerticalScroll.Visible,"Default translated overview needs scrolling: "+language);}
            using(var fixture=new Form{ClientSize=new Size(560,820)}){
                var responsive=new UsageOverview();fixture.Controls.Add(responsive);fixture.Show();Application.DoEvents();
                foreach(Control track in responsive.Controls.Find("linearScale2",true))Assert(track.Width>=80*dpi/96,"Narrow overview lost its token chart");
                responsive.Dock=DockStyle.None;responsive.Size=new Size((int)(475*dpi/96),(int)(940*dpi/96));Application.DoEvents();
                var shortCell=responsive.Controls.Find("group-short",true)[0];var weekCell=responsive.Controls.Find("group-week",true)[0];
                Assert(shortCell.Top==weekCell.Top&&weekCell.Left>shortCell.Left,"Tall narrow view should reflow quota cells horizontally");
                var narrowPlot=responsive.Controls.Find("monthlyTrend",true)[0];
                Assert(narrowPlot.Bottom<weekCell.Parent.Top,"Tall narrow view should stack quota below the trend");
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
            window.ShowPage("Data and settings");Assert(((ComboBox)window.Controls.Find("language",true)[0]).Items.Count==4,"Missing system language option");window.ShowPage("Usage overview");
            window.UpdateState("starting",new Dictionary<string,object>());
            var progress=window.Controls.Find("connectionProgress",true)[0];var status=window.Controls.Find("statusDetail",true)[0];
            Assert(progress.Width<=200*dpi/96&&Math.Abs(progress.Left-status.Left)<=1,"Connection progress must be compact and aligned with its status");
            window.UpdateState("mounted",new Dictionary<string,object>());
            Assert(status.Text==Locale.T("Connected")&&!progress.Visible,"Connected status retained temporary connecting text or animation");
            var overviewNav=(NavigationItem)window.Controls.Find("Usage overview",true)[0];var displayNav=(NavigationItem)window.Controls.Find("Sidebar content",true)[0];
            overviewNav.Focus();overviewNav.PerformClick();displayNav.Focus();displayNav.PerformClick();Application.DoEvents();
            using(var pixels=new Bitmap(overviewNav.Width,overviewNav.Height)){
                overviewNav.DrawToBitmap(pixels,overviewNav.ClientRectangle);
                Assert(pixels.GetPixel(overviewNav.Width/2,0).ToArgb()==overviewNav.Parent.BackColor.ToArgb()&&pixels.GetPixel(0,overviewNav.Height/2).ToArgb()==overviewNav.Parent.BackColor.ToArgb(),"Inactive navigation retained a colored native border after focus changed");
            }
            foreach(var size in new[]{initialSize,new Size(1440,1000),new Size(900,1000),new Size(1040,740),new Size(1184,792)}){
                window.ClientSize=size;Application.DoEvents();
                Assert(window.ClientSize==size,"Requested physical viewport was not honored: "+window.ClientSize);
                foreach(string page in new[]{"Usage overview","Sidebar content","Codex subscription record","Data and settings","Diagnostics","About project"}){
                    window.ShowPage(page);Application.DoEvents();
                    if(page=="Codex subscription record"){
                        ((ComboBox)window.Controls.Find("plan",true)[0]).SelectedIndex=3;
                        ((ComboBox)window.Controls.Find("tier",true)[0]).SelectedIndex=1;
                        ((ComboBox)window.Controls.Find("dateMode",true)[0]).SelectedIndex=0;
                        var purchase=(BlankDatePicker)window.Controls.Find("purchaseDate",true)[0];
                        purchase.Value=new DateTime(2026,11,13);purchase.Checked=true;
                        ((CheckBox)window.Controls.Find("membershipEnabled",true)[0]).Checked=true;
                    }
                    if(page=="Usage overview"){
                        window.UpdateState("mounted",new Dictionary<string,object>());
                        double now=(DateTime.UtcNow-new DateTime(1970,1,1)).TotalMilliseconds;
                        ((UsageOverview)window.Controls.Find("usageOverview",true)[0]).UpdateSnapshot(new Dictionary<string,object>{{"generatedAt",now},{"quotaAt",now},{"usageAt",now},{"creditBalance","162.811999999"},{"resetCredits",3},{"planBadge","Pro 100"},{"renewalDate","2026-12-13"},{"monthTotal",2480000000d},{"monthTrend",new Dictionary<string,object>{{"month",DateTime.UtcNow.ToString("yyyy-MM")},{"days",new object[]{103000000,134000000,64000000,189000000,96000000,null,67000000,164000000,0,190000000,116000000,89000000,128000000,193000000,48000000,137000000,198000000,181000000,226000000}}}},{"monthAverage",125350000},{"week",754000000},{"lifetime",4310000000d},{"daily",new Dictionary<string,object>{{"date",DateTime.Today.AddDays(-1).ToString("yyyy-MM-dd")},{"value",202650000}}},{"windows",new[]{new Dictionary<string,object>{{"minutes",300},{"remaining",62},{"resetsAt",now/1000+86400}},new Dictionary<string,object>{{"minutes",10080},{"remaining",37}}}}},true,now);
                    }
                    foreach(string lang in new[]{"en","zh-CN","zh-TW"}){
                        Locale.Set(lang);Application.DoEvents();Check(window);
                        var body=window.Controls.Find("pageBody",true)[0];
                        var title=window.Controls.Find("statusHeadline",true)[0];
                        Assert(title.PointToScreen(Point.Empty).X==body.PointToScreen(body.DisplayRectangle.Location).X,"Title does not share body gutter: "+page);
                        var quit=window.Controls.Find("exitSoftware",true)[0];Assert(quit.BackColor==quit.Parent.BackColor,"Exit action has a filled background");
                        if(page=="Codex subscription record"){
                            var purchase=window.Controls.Find("purchaseDate",true)[0];
                            var clear=window.Controls.Find("purchaseDateClear",true)[0];
                            Assert(purchase.Parent.ClientRectangle.Contains(purchase.Bounds)&&purchase.Parent.ClientRectangle.Contains(clear.Bounds),"Calendar or clear action extends below its field");
                            Assert(clear.Visible&&purchase.Right<clear.Left&&purchase.Top==clear.Top,"Clear action must sit beside the date on its baseline");
                            var family=window.Controls.Find("plan",true)[0];var mode=window.Controls.Find("dateMode",true)[0];
                            foreach(string field in new[]{"plan","tier","dateMode","nextDate","membershipEnabled"})Assert(window.Controls.Find(field,true)[0].Font.Equals(purchase.Font),"Mixed plan editor typefaces: "+field);
                            Assert(Math.Abs((mode.Top*2+mode.Height)-(purchase.Top*2+purchase.Height))<=2,"Plan date and date-type editors are not vertically centered together");
                            Assert(family.Parent.Left==purchase.Parent.Left&&mode.Parent.Top==purchase.Parent.Top,"Plan and date columns drifted from the reference grid");
                        }
                        if(page=="Codex subscription record"){
                            var save=(Button)window.Controls.Find("save",true)[0];
                            int width=save.Width;save.Text=Locale.T("Saved successfully");Check(window);Assert(save.Width==width,"Saved feedback changed button geometry");save.Text=Locale.T("Save");
                        }
                        var overview=window.Controls.Find("usageOverview",true)[0] as UsageOverview;if(page=="Usage overview"){if(overview.HorizontalScroll.Visible){Console.WriteLine("Overflow client="+overview.ClientSize+" display="+overview.DisplayRectangle);foreach(Control c in overview.Controls)Console.WriteLine(c.Name+" "+c.Bounds);}Assert(!overview.HorizontalScroll.Visible,"Overview has horizontal overflow");}
                        if(page=="Usage overview"&&size.Width==1440){Console.WriteLine("Effective large viewport="+overview.ClientSize+" requested="+window.ClientSize);if(overview.ClientSize.Height>=Math.Ceiling(544*dpi/96))Assert(!overview.VerticalScroll.Visible,"Sufficient overview viewport should not require vertical scrolling");}
                        var footerFeedback=window.Controls.Find("footerFeedback",true)[0];Assert(!String.IsNullOrEmpty(footerFeedback.Text)||!footerFeedback.Visible,"Empty feedback label is covering the version");
                        if(page=="Usage overview"){
                            var planField=overview.Controls.Find("metric9",true)[0].Parent;var renewalField=overview.Controls.Find("metric10",true)[0].Parent;
                            Assert(planField.RectangleToScreen(planField.ClientRectangle).Left==overview.RectangleToScreen(overview.ClientRectangle).Left,"Plan metadata must align with the left data column");
                            Assert(renewalField.Top==planField.Top&&renewalField.Left==planField.Right,"Plan and renewal must share a compact footer row");
                            var planValue=overview.Controls.Find("metric9",true)[0];var renewalValue=overview.Controls.Find("metric10",true)[0];
                            Assert(planValue.Top==renewalValue.Top&&planValue.Font.Equals(renewalValue.Font),"Subscription values must share a baseline and type style");
                            var plot=(UsageTrend)overview.Controls.Find("monthlyTrend",true)[0];
                            Assert(plot.Visible&&plot.SelectedValue.HasValue,"Connected layout must show the real trend fixture");
                            foreach(string trackName in new[]{"linearScale2","linearScale3"})Assert(overview.Controls.Find(trackName,true)[0].Width>=64*dpi/96,"Responsive chart disappeared: "+trackName);
                            foreach(Control label in renewalField.Controls)if(label is Label&&label.Text==Locale.T("Renewal date"))using(var g=label.CreateGraphics())Assert(TextRenderer.MeasureText(g,label.Text,label.Font,new Size(Int32.MaxValue,Int32.MaxValue),TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine).Width<=label.Width,"Immediate language switch clipped the renewal label");
                        }
                        using(var bitmap=new Bitmap(window.Width,window.Height)){using(var g=Graphics.FromImage(bitmap)){IntPtr dc=g.GetHdc();try{Assert(PrintWindow(window.Handle,dc,2),"Native window capture failed");}finally{g.ReleaseHdc(dc);}}bitmap.Save(Path.Combine(args[0],"dpi-"+dpi+"-"+size.Width+"-"+page.Replace(" ","-")+"-"+lang+".png"));}
                    }
                    if(page=="Codex subscription record")((Button)window.Controls.Find("save",true)[0]).PerformClick();
                }
            }
            window.Finish();
        }
        Console.WriteLine("PASS: real system DPI, font metrics, six pages, three locales, narrow and regular sizes");return 0;
    }
}
