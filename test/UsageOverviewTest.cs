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
            if(view.Controls.Find("metric2",true)[0].Top!=view.Controls.Find("metric5",true)[0].Top)throw new Exception("Daily and monthly average must share a row");
            if(view.Controls.Find("metric3",true)[0].Top!=view.Controls.Find("metric4",true)[0].Top)throw new Exception("Weekly and lifetime must share a row");
            view.UpdateSnapshot(data,true,now+90001);
            if(view.Controls.Find("metric0",true)[0].Text!="--")throw new Exception("Stale data leaked");
            if(view.Controls.Find("metricCaption0",true)[0].Text!=Locale.T("Data expired"))throw new Exception("Expired state must be explicit");
            view.UpdateSnapshot(data,false,now);
            if(view.Controls.Find("metric4",true)[0].Text!="--")throw new Exception("Disconnected data leaked");
        }
        Console.WriteLine("PASS: three locales, quota values, real zero, stale and disconnected snapshots");return 0;
    }
}
