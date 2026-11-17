using System;
using System.Collections.Generic;
using System.Windows.Forms;
internal static class UsageOverviewTest {
    [STAThread] static int Main(){
        foreach(string language in new[]{"en","zh-CN","zh-TW"}){Locale.Set(language);if(Locale.T("Language")=="")throw new Exception("Language missing");}
        Locale.Set("en");
        foreach(string canonical in new[]{"Credits","Quota remaining"}){
            using(var label=new Label{Text=canonical}){
                foreach(string language in new[]{"en","zh-CN","zh-TW","en"}){Locale.Set(language);Locale.Apply(label);}
                if(label.Text!=canonical)throw new Exception("Language cycle changed canonical label: "+canonical+" -> "+label.Text);
            }
        }
        foreach(string language in new[]{"zh-CN","zh-TW"}){
            Locale.Set(language);string caption=Locale.T("Remaining 62% / Used 38%");Locale.Set("en");
            if(Locale.T(caption)!="Remaining 62% / Used 38%")throw new Exception("Dynamic quota caption retained previous language");
        }
        using(var view=new UsageOverview()){
            double now=10000000;
            var data=new Dictionary<string,object>{{"generatedAt",now},{"quotaAt",now},{"usageAt",now},{"monthAverage",0},{"week",1200000},{"lifetime",0},{"daily",new Dictionary<string,object>{{"date","2026-11-14"},{"value",0}}},{"windows",new[]{new Dictionary<string,object>{{"minutes",300},{"remaining",75}}}}};
            view.UpdateSnapshot(data,true,now);
            if(view.Controls.Find("metric0",true)[0].Text!="75%"||view.Controls.Find("metric2",true)[0].Text!="0")throw new Exception("Real zero or quota incorrect");
            if(view.Controls.Find("metric5",true).Length!=1||view.Controls.Find("metric5",true)[0].Text!="0")throw new Exception("Monthly average missing");
            if(view.Controls.Find("metricCaption1",true)[0].Text!=Locale.T("Not returned"))throw new Exception("Missing quota must explain its state");
            if(view.Controls.Find("metric10",true).Length!=1)throw new Exception("V3 must expose all eleven selected metrics");
            var scale=view.GetType().GetProperty("TokenScale",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic);
            if(scale==null)throw new Exception("V3 needs a real shared Token scale");
            if(Convert.ToDouble(scale.GetValue(view,null))!=0)throw new Exception("All-zero Token scale must not fabricate a maximum");
            data["monthAverage"]=800000000;
            view.UpdateSnapshot(data,true,now);
            if(Convert.ToDouble(scale.GetValue(view,null))<800000000)throw new Exception("Token scale clips real values");
            data["creditBalance"]="0";data["resetCredits"]=0;data["planBadge"]="Pro";data["renewalDate"]="2026-12-13";
            data["visible"]=new Dictionary<string,object>{{"short",false},{"credits",true}};
            view.UpdateSnapshot(data,true,now);
            if(view.Controls.Find("metric8",true)[0].Text!="0"||view.Controls.Find("metric7",true)[0].Text!="0")throw new Exception("Credit/reset zero must not become missing");
            if(view.Controls.Find("group-short",true)[0].Visible)throw new Exception("Deselected metric still visible");
            if(view.Controls.Find("metric9",true)[0].Text!="Pro"||view.Controls.Find("metric10",true)[0].Text!="2026-12-13")throw new Exception("Subscription metadata missing");
            data["creditBalance"]="invalid";data["resetCredits"]=-1;view.UpdateSnapshot(data,true,now);
            if(view.Controls.Find("metric8",true)[0].Text!="--"||view.Controls.Find("metric7",true)[0].Text!="--")throw new Exception("Invalid quota values fabricated");
            data["creditBalance"]="162.811999999";
            data["windows"]=new[]{new Dictionary<string,object>{{"minutes",300},{"remaining",75},{"resetsAt",1794916800d}}};
            view.UpdateSnapshot(data,true,now);
            if(view.Controls.Find("metric8",true)[0].Text!="162")throw new Exception("Credits must be floored to whole credits");
            string reset=view.Controls.Find("metric6",true)[0].Text;
            string expected=new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddSeconds(1794916800d).ToLocalTime().ToString("MM/dd HH:mm");
            if(reset!=expected)throw new Exception("Epoch seconds interpreted as milliseconds: "+reset);
            data["windows"]=new[]{new Dictionary<string,object>{{"minutes",300},{"remaining",75},{"resetsAt",1794916800000d}}};
            view.UpdateSnapshot(data,true,now);
            if(view.Controls.Find("metric6",true)[0].Text!=expected)throw new Exception("Millisecond reset compatibility lost");
            view.UpdateSnapshot(data,true,now+90001);
            if(view.Controls.Find("metric0",true)[0].Text!="--")throw new Exception("Stale data leaked");
            if(view.Controls.Find("metricCaption0",true)[0].Text!=Locale.T("Data expired"))throw new Exception("Expired state must be explicit");
            view.UpdateSnapshot(data,false,now);
            if(view.Controls.Find("metric4",true)[0].Text!="--")throw new Exception("Disconnected data leaked");
        }
        Console.WriteLine("PASS: three locales, quota values, real zero, stale and disconnected snapshots");return 0;
    }
}
