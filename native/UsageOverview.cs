using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Web.Script.Serialization;
using System.Windows.Forms;
internal sealed class UsageOverview : UserControl {
    readonly Label[] values=new Label[6],captions=new Label[6];
    readonly Panel[] bars=new Panel[2];
    readonly Label stamp;
    internal UsageOverview(){
        Dock=DockStyle.Top;Height=316;BackColor=MeterTheme.Surface;
        var grid=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=2,RowCount=11,Margin=new Padding(0)};
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));
        foreach(int h in new[]{22,40,26,16,22,38,24,22,38,24,38})grid.RowStyles.Add(new RowStyle(SizeType.Absolute,h));
        Controls.Add(grid);
        string[] labels={"5-hour remaining","Weekly remaining","Daily tokens","Weekly tokens","Lifetime tokens","Monthly daily average"};
        int[] columns={0,1,0,0,1,1},rows={0,0,4,7,7,4};
        for(int i=0;i<6;i++){
            int column=columns[i],row=rows[i];
            var name=MeterTheme.Label(labels[i],10,MeterTheme.Muted);name.Margin=new Padding(0,0,20,0);grid.Controls.Add(name,column,row);
            values[i]=MeterTheme.Label("--",23,MeterTheme.Muted);values[i].Name="metric"+i;values[i].Margin=new Padding(0,0,20,0);grid.Controls.Add(values[i],column,row+1);
            captions[i]=MeterTheme.Label("Not returned",9,MeterTheme.Muted);captions[i].Name="metricCaption"+i;captions[i].Margin=new Padding(0,0,20,0);grid.Controls.Add(captions[i],column,row+2);
            if(i<2){var track=new Panel{Dock=DockStyle.Bottom,Height=4,BackColor=MeterTheme.Line,Margin=new Padding(0,0,20,2)};bars[i]=new Panel{Dock=DockStyle.Left,Width=0,BackColor=i==0?MeterTheme.Green:Color.FromArgb(35,149,112)};track.Controls.Add(bars[i]);captions[i].Controls.Add(track);}
        }
        var divider=new Panel{Dock=DockStyle.Top,Height=1,BackColor=MeterTheme.Line,Margin=new Padding(0,6,20,0)};grid.Controls.Add(divider,0,3);grid.SetColumnSpan(divider,2);
        stamp=MeterTheme.Label("",9,MeterTheme.Muted);stamp.Margin=new Padding(0,8,20,0);grid.Controls.Add(stamp,0,10);grid.SetColumnSpan(stamp,2);
    }
    static double? Number(object value){if(value==null||value is bool||value is string)return null;try{double n=Convert.ToDouble(value);return Double.IsNaN(n)||Double.IsInfinity(n)||n<0?null:(double?)n;}catch{return null;}}
    static double? N(Dictionary<string,object> data,string key){object v;return data.TryGetValue(key,out v)?Number(v):null;}
    static bool Fresh(Dictionary<string,object> d,string key,double now,double age){var n=N(d,key);return n.HasValue&&now>=n.Value&&now-n.Value<age;}
    static string Count(double? n){if(!n.HasValue||n.Value>9007199254740991||n.Value!=Math.Floor(n.Value))return "--";return n.Value>=1e9?(n.Value/1e9).ToString("0.##",System.Globalization.CultureInfo.InvariantCulture)+"B":n.Value>=1e6?(n.Value/1e6).ToString("0.##",System.Globalization.CultureInfo.InvariantCulture)+"M":n.Value>=1e3?(n.Value/1e3).ToString("0.##",System.Globalization.CultureInfo.InvariantCulture)+"K":n.Value.ToString("0");}
    void Set(int index,string value,string caption){values[index].Text=value;values[index].ForeColor=value=="--"?MeterTheme.Muted:MeterTheme.Ink;captions[index].Text=Locale.T(caption);}
    internal void UpdateSnapshot(Dictionary<string,object> data,bool connected,double now){
        string state=!connected?"Not connected":!N(data,"generatedAt").HasValue||Fresh(data,"generatedAt",now,90000)?"Not returned":"Data expired";
        for(int i=0;i<6;i++)Set(i,"--",state);foreach(var bar in bars)bar.Width=0;
        stamp.Text=Locale.T("Quota synced")+": "+Time(N(data,"quotaAt"))+"    /    "+Locale.T("Tokens synced")+": "+Time(N(data,"usageAt"));
        if(!connected||!Fresh(data,"generatedAt",now,90000))return;
        if(Fresh(data,"quotaAt",now,180000)){
            object windows;if(data.TryGetValue("windows",out windows)&&windows is IEnumerable){var seen=new HashSet<int>();foreach(object item in (IEnumerable)windows){var w=item as Dictionary<string,object>;if(w==null)continue;var duration=N(w,"minutes");var remaining=N(w,"remaining");int index=duration==300?0:duration==10080?1:-1;if(index<0||!remaining.HasValue||remaining>100)continue;if(!seen.Add(index)){Set(index,"--","Not returned");bars[index].Width=0;continue;}Set(index,remaining.Value.ToString("0.#",System.Globalization.CultureInfo.InvariantCulture)+"%","");bars[index].Width=(int)(bars[index].Parent.ClientSize.Width*remaining.Value/100);}}
        }else if(N(data,"quotaAt").HasValue){Set(0,"--","Data expired");Set(1,"--","Data expired");}
        if(Fresh(data,"usageAt",now,5400000)){
            foreach(var item in new[]{new KeyValuePair<int,string>(3,"week"),new KeyValuePair<int,string>(4,"lifetime"),new KeyValuePair<int,string>(5,"monthAverage")}){string value=Count(N(data,item.Value));Set(item.Key,value,value=="--"?"Not returned":"");}
            object daily;if(data.TryGetValue("daily",out daily)&&daily is Dictionary<string,object>){var d=(Dictionary<string,object>)daily;object label;DateTime day;if(d.TryGetValue("date",out label)&&DateTime.TryParseExact(Convert.ToString(label),"yyyy-MM-dd",System.Globalization.CultureInfo.InvariantCulture,System.Globalization.DateTimeStyles.None,out day)){
                string value=Count(N(d,"value"));var local=new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddMilliseconds(now).ToLocalTime().Date;
                Set(2,value,value=="--"?"Not returned":day.Date==local.AddDays(-1)?"Yesterday":day.Date==local?"Today":Locale.T("Data date")+": "+day.ToString("yyyy-MM-dd"));
            }}
        }else if(N(data,"usageAt").HasValue)for(int i=2;i<6;i++)Set(i,"--","Data expired");
    }
    static string Time(double? n){if(!n.HasValue)return "--";try{return new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddMilliseconds(n.Value).ToLocalTime().ToString("MM/dd HH:mm");}catch{return "--";}}
    internal void ReadSnapshot(bool connected){try{string path=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,".runtime","browser-state.json");if(new FileInfo(path).Length>131072)throw new IOException();var data=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(path));UpdateSnapshot(data,connected,(DateTime.UtcNow-new DateTime(1970,1,1)).TotalMilliseconds);}catch{UpdateSnapshot(new Dictionary<string,object>(),connected,0);}}
}
