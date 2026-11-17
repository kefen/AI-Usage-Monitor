using System;
using System.Collections.Generic;
using System.Windows.Forms;
internal static class UsageOverviewTest {
    [STAThread] static int Main(){
        foreach(string language in new[]{"en","zh-CN","zh-TW"}){Locale.Set(language);if(Locale.T("Language")=="")throw new Exception("Language missing");}
        Locale.Set("en");
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
            view.UpdateSnapshot(data,true,now+90001);
            if(view.Controls.Find("metric0",true)[0].Text!="--")throw new Exception("Stale data leaked");
            if(view.Controls.Find("metricCaption0",true)[0].Text!=Locale.T("Data expired"))throw new Exception("Expired state must be explicit");
            view.UpdateSnapshot(data,false,now);
            if(view.Controls.Find("metric4",true)[0].Text!="--")throw new Exception("Disconnected data leaked");
        }
        Console.WriteLine("PASS: three locales, quota values, real zero, stale and disconnected snapshots");return 0;
    }
}
