using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Web.Script.Serialization;
using System.Windows.Forms;
internal sealed class UsageOverview : UserControl {
    readonly Label[] values=new Label[5];
    readonly Panel[] bars=new Panel[2];
    readonly Label date,stamp;
    internal UsageOverview(){
        Dock=DockStyle.Top;Height=302;BackColor=MeterTheme.Surface;
        var grid=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=6,RowCount=6};for(int i=0;i<6;i++)grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100f/6));
        foreach(int h in new[]{32,54,24,32,62,50})grid.RowStyles.Add(new RowStyle(SizeType.Absolute,h));
        Controls.Add(grid);
        string[] labels={"5-hour remaining","Weekly remaining","Daily tokens","Weekly tokens","Lifetime tokens"};
        for(int i=0;i<5;i++){
            int column=i<2?i*3:(i-2)*2,span=i<2?3:2,row=i<2?0:3;
            var label=MeterTheme.Label(labels[i],10,MeterTheme.Muted);grid.Controls.Add(label,column,row);grid.SetColumnSpan(label,span);
            values[i]=MeterTheme.Label("--",23,MeterTheme.Ink);values[i].Name="metric"+i;grid.Controls.Add(values[i],column,row+1);grid.SetColumnSpan(values[i],span);
            if(i<2){var track=new Panel{Dock=DockStyle.Top,Height=5,BackColor=MeterTheme.Line,Margin=new Padding(0,6,20,0)};bars[i]=new Panel{Dock=DockStyle.Left,Width=0,BackColor=i==0?MeterTheme.Green:Color.FromArgb(35,149,112)};track.Controls.Add(bars[i]);grid.Controls.Add(track,column,2);grid.SetColumnSpan(track,3);}
        }
        date=MeterTheme.Label("Data date: --",9,MeterTheme.Muted);grid.Controls.Add(date,0,5);grid.SetColumnSpan(date,2);
        stamp=MeterTheme.Label("",9,MeterTheme.Muted);grid.Controls.Add(stamp,2,5);grid.SetColumnSpan(stamp,4);
    }
    static double? Number(object value){if(value==null||value is bool||value is string)return null;try{double n=Convert.ToDouble(value);return Double.IsNaN(n)||Double.IsInfinity(n)||n<0?null:(double?)n;}catch{return null;}}
    static double? N(Dictionary<string,object> data,string key){object v;return data.TryGetValue(key,out v)?Number(v):null;}
    static bool Fresh(Dictionary<string,object> d,string key,double now,double age){var n=N(d,key);return n.HasValue&&now>=n.Value&&now-n.Value<age;}
    static string Count(double? n){if(!n.HasValue||n.Value>9007199254740991||n.Value!=Math.Floor(n.Value))return "--";return n.Value>=1e9?(n.Value/1e9).ToString("0.##")+"B":n.Value>=1e6?(n.Value/1e6).ToString("0.##")+"M":n.Value>=1e3?(n.Value/1e3).ToString("0.##")+"K":n.Value.ToString("0");}
    internal void UpdateSnapshot(Dictionary<string,object> data,bool connected,double now){
        foreach(var label in values)label.Text="--";foreach(var bar in bars)bar.Width=0;date.Text=Locale.T("Data date")+": --";stamp.Text=Locale.T("No valid data. Missing values are not zero.");
        if(!connected||!Fresh(data,"generatedAt",now,90000))return;
        if(Fresh(data,"quotaAt",now,180000)){
            object windows;if(data.TryGetValue("windows",out windows)&&windows is IEnumerable){var seen=new HashSet<int>();foreach(object item in (IEnumerable)windows){var w=item as Dictionary<string,object>;if(w==null)continue;var duration=N(w,"minutes");var remaining=N(w,"remaining");int index=duration==300?0:duration==10080?1:-1;if(index<0||!remaining.HasValue||remaining>100)continue;if(!seen.Add(index)){values[index].Text="--";bars[index].Width=0;continue;}values[index].Text=remaining.Value.ToString("0.#")+"%";bars[index].Width=(int)(bars[index].Parent.ClientSize.Width*remaining.Value/100);}}
        }
        if(Fresh(data,"usageAt",now,5400000)){
            values[3].Text=Count(N(data,"week"));values[4].Text=Count(N(data,"lifetime"));
            object daily;if(data.TryGetValue("daily",out daily)&&daily is Dictionary<string,object>){var d=(Dictionary<string,object>)daily;object label;DateTime day;if(d.TryGetValue("date",out label)&&DateTime.TryParseExact(Convert.ToString(label),"yyyy-MM-dd",System.Globalization.CultureInfo.InvariantCulture,System.Globalization.DateTimeStyles.None,out day)){values[2].Text=Count(N(d,"value"));date.Text=Locale.T("Data date")+": "+day.ToString("yyyy-MM-dd");}}
        }
        stamp.Text=Locale.T("Quota synced")+": "+Time(N(data,"quotaAt"))+"\n"+Locale.T("Tokens synced")+": "+Time(N(data,"usageAt"));
    }
    static string Time(double? n){if(!n.HasValue)return "--";try{return new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddMilliseconds(n.Value).ToLocalTime().ToString("MM/dd HH:mm");}catch{return "--";}}
    internal void ReadSnapshot(bool connected){try{string path=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,".runtime","browser-state.json");if(new FileInfo(path).Length>131072)throw new IOException();var data=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(path));UpdateSnapshot(data,connected,(DateTime.UtcNow-new DateTime(1970,1,1)).TotalMilliseconds);}catch{UpdateSnapshot(new Dictionary<string,object>(),false,0);}}
}
