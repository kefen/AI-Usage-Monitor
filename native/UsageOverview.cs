using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Web.Script.Serialization;
using System.Windows.Forms;

internal sealed class UsageOverview : UserControl {
    readonly Label[] values=new Label[11],captions=new Label[11],names=new Label[11];
    readonly Panel[] groups=new Panel[11];
    readonly bool[] selected=new bool[11];
    readonly LinearScale[] charts=new LinearScale[4];
    readonly Label quotaTitle,tokenTitle,scope,source,empty;
    readonly LinearAxis axis;
    readonly Panel details,meta,tail;
    readonly string[] keys={"short","week","daily","weekly","lifetime","average","reset","resetCredits","credits","plan","renewal"};
    internal double TokenScale {get;private set;}
    internal UsageOverview(){
        Name="usageOverview";Dock=DockStyle.Fill;Height=540;BackColor=MeterTheme.Surface;
        string[] labels={"5-hour remaining","Weekly remaining","Daily tokens","Weekly tokens","Lifetime tokens","Monthly daily average","Quota reset date","Reset count","Credits","Plan","Renewal"};
        quotaTitle=Label("Quota remaining",10,MeterTheme.Ink);tokenTitle=Label("Yesterday vs monthly daily average",10,MeterTheme.Ink);
        scope=Label("Shared Token scale",8,MeterTheme.Muted);axis=new LinearAxis();Controls.Add(axis);
        source=Label("Usage: local CLI. Plan: desktop detection or manual record.",9,MeterTheme.Muted);
        empty=Label("No metrics selected.",10,MeterTheme.Muted);empty.Visible=false;
        details=new Panel{BackColor=Color.FromArgb(247,248,250)};meta=new Panel();tail=new Panel();Controls.Add(details);Controls.Add(meta);Controls.Add(tail);
        foreach(var panel in new[]{meta,tail})panel.Paint+=(s,e)=>{var p=(Panel)s;using(var pen=new Pen(MeterTheme.Line))e.Graphics.DrawLine(pen,0,0,p.Width,0);};
        for(int i=0;i<11;i++){
            selected[i]=true;var group=groups[i]=new Panel{Name="group-"+keys[i]};
            (i>=6&&i<=8?details:i>=9?meta:i==3||i==4?tail:(Control)this).Controls.Add(group);
            names[i]=MeterTheme.Label(labels[i],9,MeterTheme.Muted);names[i].Dock=DockStyle.None;group.Controls.Add(names[i]);
            values[i]=MeterTheme.Label("--",i<2?20:i==3||i==4?18:i>=9?9:i>=6?12:11,MeterTheme.Ink);values[i].Name="metric"+i;values[i].Dock=DockStyle.None;group.Controls.Add(values[i]);
            captions[i]=MeterTheme.Label("Not returned",8,MeterTheme.Muted);captions[i].Name="metricCaption"+i;captions[i].Dock=DockStyle.None;group.Controls.Add(captions[i]);
        }
        for(int i=0;i<4;i++){charts[i]=new LinearScale(i<2);charts[i].Name="linearScale"+i;groups[i==2?2:i==3?5:i].Controls.Add(charts[i]);}
        Resize+=(s,e)=>Arrange();Arrange();
    }
    Label Label(string text,float size,Color color){var label=MeterTheme.Label(text,size,color);label.Dock=DockStyle.None;Controls.Add(label);return label;}
    new void Bounds(Control c,float x,float y,float w,float h,float s){c.SetBounds((int)(x*s),(int)(y*s),Math.Max(0,(int)(w*s)),Math.Max(0,(int)(h*s)));}
    void Arrange(){
        if(groups[10]==null)return;
        float s;using(var g=CreateGraphics())s=Font.Size/10f*g.DpiX/96f;
        float w=ClientSize.Width/s,left=(w-36)*.465f,right=left+36,rw=w-right;
        Bounds(quotaTitle,0,0,left,24,s);Bounds(tokenTitle,right,0,rw,24,s);Bounds(scope,right,28,rw,22,s);
        int q=0;for(int i=0;i<2;i++)if(selected[i]){Bounds(groups[i],0,40+q*142,left,128,s);Bounds(names[i],0,0,left,22,s);Bounds(values[i],0,25,left,36,s);Bounds(charts[i],0,64,left,32,s);Bounds(captions[i],0,100,left,22,s);q++;}
        int row=0;foreach(int i in new[]{2,5})if(selected[i]){Bounds(groups[i],right,68+row*55,rw,42,s);Bounds(names[i],0,0,108,34,s);Bounds(values[i],rw-84,0,84,34,s);values[i].TextAlign=ContentAlignment.MiddleRight;Bounds(charts[i==2?2:3],108,8,Math.Max(0,rw-194),20,s);Bounds(captions[i],0,30,rw,12,s);row++;}
        Bounds(axis,right+108,160,Math.Max(0,rw-194),22,s);
        Bounds(tail,right,214,rw,110,s);int n=0;foreach(int i in new[]{3,4})if(selected[i]){float width=rw/(selected[3]&&selected[4]?2:1);Bounds(groups[i],n++*width,18,width,90,s);Bounds(names[i],0,0,width,24,s);Bounds(values[i],0,26,width,32,s);Bounds(captions[i],0,62,width,22,s);}
        Bounds(details,0,342,w,86,s);int count=0;for(int i=6;i<=8;i++)if(selected[i])count++;n=0;
        for(int i=6;i<=8;i++)if(selected[i]){float width=(w-40)/Math.Max(1,count);Bounds(groups[i],20+n++*width,12,width,62,s);Bounds(names[i],0,0,width,24,s);Bounds(values[i],0,30,width,28,s);captions[i].Visible=false;}
        Bounds(meta,0,452,w,42,s);float x=0;for(int i=9;i<=10;i++)if(selected[i]){Bounds(groups[i],x,8,210,28,s);Bounds(names[i],0,0,i==9?40:68,26,s);Bounds(values[i],i==9?44:72,0,138,26,s);captions[i].Visible=false;x+=210;}
        Bounds(source,0,496,w,30,s);Bounds(empty,0,20,w,40,s);
        quotaTitle.Visible=selected[0]||selected[1];tokenTitle.Visible=scope.Visible=axis.Visible=selected[2]||selected[5];
        tail.Visible=selected[3]||selected[4];details.Visible=count>0;meta.Visible=selected[9]||selected[10];
        bool any=false;foreach(bool v in selected)any|=v;empty.Visible=!any;source.Visible=any;
        for(int i=0;i<groups.Length;i++)groups[i].Visible=selected[i];
    }
    static double? Number(object value){if(value==null||value is bool||value is string)return null;try{double n=Convert.ToDouble(value);return Double.IsNaN(n)||Double.IsInfinity(n)||n<0?null:(double?)n;}catch{return null;}}
    static double? N(Dictionary<string,object> data,string key){object v;return data.TryGetValue(key,out v)?Number(v):null;}
    static bool Fresh(Dictionary<string,object> d,string key,double now,double age){var n=N(d,key);return n.HasValue&&now>=n.Value&&now-n.Value<age;}
    internal static string Count(double? n){if(!n.HasValue||n.Value>9007199254740991)return "--";return n.Value>=1e9?(n.Value/1e9).ToString("0.##",CultureInfo.InvariantCulture)+"B":n.Value>=1e6?(n.Value/1e6).ToString("0.##",CultureInfo.InvariantCulture)+"M":n.Value>=1e3?(n.Value/1e3).ToString("0.##",CultureInfo.InvariantCulture)+"K":n.Value.ToString("0.##",CultureInfo.InvariantCulture);}
    static double? Integer(double? n){return n.HasValue&&n<=9007199254740991&&n==Math.Floor(n.Value)?n:null;}
    void Set(int index,string value,string caption){values[index].Text=value;values[index].ForeColor=value=="--"?MeterTheme.Muted:MeterTheme.Ink;captions[index].Text=Locale.T(caption);groups[index].AccessibleName=Locale.T(names[index].Text)+": "+value+" "+Locale.T(caption);}
    internal void UpdateSnapshot(Dictionary<string,object> data,bool connected,double now){
        string state=!connected?"Not connected":!N(data,"generatedAt").HasValue||Fresh(data,"generatedAt",now,90000)?"Not returned":"Data expired";
        for(int i=0;i<11;i++)Set(i,"--",state);foreach(var chart in charts)chart.Amount=null;
        object visible;var map=data.TryGetValue("visible",out visible)?visible as Dictionary<string,object>:null;
        for(int i=0;i<keys.Length;i++){object v;selected[i]=map==null||!map.TryGetValue(keys[i],out v)||!(v is bool)||(bool)v;}
        TokenScale=0;axis.Maximum=null;
        if(connected&&Fresh(data,"generatedAt",now,90000)){
            if(Fresh(data,"quotaAt",now,180000)){
                object windows;if(data.TryGetValue("windows",out windows)&&windows is IEnumerable){var seen=new HashSet<int>();foreach(object item in (IEnumerable)windows){var d=item as Dictionary<string,object>;if(d==null)continue;var minutes=N(d,"minutes");var remaining=N(d,"remaining");int index=minutes==300?0:minutes==10080?1:-1;if(index<0||!remaining.HasValue||remaining>100)continue;if(!seen.Add(index)){Set(index,"--","Not returned");charts[index].Amount=null;continue;}Set(index,remaining.Value.ToString("0.#",CultureInfo.InvariantCulture)+"%",Locale.T("Remaining")+" "+remaining.Value.ToString("0.#")+"% / "+Locale.T("Used")+" "+(100-remaining.Value).ToString("0.#")+"%");charts[index].Amount=remaining.Value/100;var reset=N(d,"resetsAt");if(reset.HasValue)Set(6,Time(reset),"");}}
                Set(7,Count(Integer(N(data,"resetCredits"))),"");object balance;decimal credit;if(data.TryGetValue("creditBalance",out balance)&&balance is string&&System.Text.RegularExpressions.Regex.IsMatch((string)balance,@"^\d+(\.\d+)?$")&&Decimal.TryParse((string)balance,NumberStyles.AllowDecimalPoint,CultureInfo.InvariantCulture,out credit))Set(8,credit.ToString(CultureInfo.InvariantCulture),"");
            }else if(N(data,"quotaAt").HasValue){Set(0,"--","Data expired");Set(1,"--","Data expired");}
            if(Fresh(data,"usageAt",now,5400000)){
                foreach(var item in new[]{new KeyValuePair<int,string>(3,"week"),new KeyValuePair<int,string>(4,"lifetime"),new KeyValuePair<int,string>(5,"monthAverage")}){string value=Count(Integer(N(data,item.Value)));Set(item.Key,value,value=="--"?"Not returned":item.Key==3?"Monday to now":item.Key==4?"Account lifetime":"");}
                double? dailyValue=null;object daily;if(data.TryGetValue("daily",out daily)&&daily is Dictionary<string,object>){var d=(Dictionary<string,object>)daily;object label;DateTime day;if(d.TryGetValue("date",out label)&&DateTime.TryParseExact(Convert.ToString(label),"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out day)){dailyValue=Integer(N(d,"value"));string value=Count(dailyValue);var local=new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddMilliseconds(now).ToLocalTime().Date;string caption=day.Date==local.AddDays(-1)?"Yesterday":day.Date==local?"Today":Locale.T("Data date")+": "+day.ToString("yyyy-MM-dd");names[2].Text=Locale.T(caption);Set(2,value,value=="--"?"Not returned":"");}}
                double? average=Integer(N(data,"monthAverage"));double a=dailyValue.GetValueOrDefault(),b=average.GetValueOrDefault();
                TokenScale=SharedMaximum(Math.Max(selected[2]?a:0,selected[5]?b:0));
                charts[2].Amount=!dailyValue.HasValue?null:(double?)(TokenScale==0?0:a/TokenScale);charts[3].Amount=!average.HasValue?null:(double?)(TokenScale==0?0:b/TokenScale);
                axis.Maximum=dailyValue.HasValue||average.HasValue?(double?)TokenScale:null;
            }else if(N(data,"usageAt").HasValue)for(int i=2;i<6;i++)Set(i,"--","Data expired");
            object v;if(data.TryGetValue("planBadge",out v)&&v is string&&!String.IsNullOrWhiteSpace((string)v))Set(9,(string)v,"");
            if(data.TryGetValue("renewalDate",out v)&&v is string&&!String.IsNullOrWhiteSpace((string)v))Set(10,(string)v,"");
        }
        charts[0].Tone=charts[2].Tone=MeterTheme.Green;charts[1].Tone=charts[3].Tone=Color.FromArgb(36,134,109);
        Arrange();axis.Invalidate();foreach(var chart in charts)chart.Invalidate();
    }
    internal static double SharedMaximum(double value){if(value<=0)return 0;double unit=Math.Pow(10,Math.Floor(Math.Log10(value)));return Math.Ceiling(value/unit/0.5)*unit*.5;}
    static string Time(double? n){if(!n.HasValue)return "--";try{return new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddMilliseconds(n.Value).ToLocalTime().ToString("MM/dd HH:mm");}catch{return "--";}}
    static Dictionary<string,object> Read(string path){try{if(new FileInfo(path).Length>131072)return new Dictionary<string,object>();return new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(path));}catch{return new Dictionary<string,object>();}}
    internal void ReadSnapshot(bool connected){
        string root=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,".runtime");var data=Read(Path.Combine(root,"browser-state.json"));
        var display=Read(Path.Combine(root,"display.json"));if(display.Count>0)data["visible"]=display;
        UpdateSnapshot(data,connected,(DateTime.UtcNow-new DateTime(1970,1,1)).TotalMilliseconds);
        var member=Read(Path.Combine(root,"membership.json"));object v;
        if(member.TryGetValue("plan",out v)&&v is string){string tier=member.ContainsKey("tier")?Convert.ToString(member["tier"]):"";Set(9,CultureInfo.InvariantCulture.TextInfo.ToTitleCase((string)v)+(tier==""||tier=="unknown"?"":" "+tier),"");}
        if(member.Count>0){bool enabled=!member.ContainsKey("enabled")||Convert.ToString(member["enabled"])!="False";string date=member.ContainsKey("date")?Convert.ToString(member["date"]):"";DateTime purchase;if(enabled&&DateTime.TryParseExact(member.ContainsKey("purchaseDate")?Convert.ToString(member["purchaseDate"]):"","yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out purchase)){if(member.ContainsKey("monthlyEstimate")&&Convert.ToString(member["monthlyEstimate"])=="True")date=purchase.AddMonths(1).ToString("yyyy-MM-dd");if(member.ContainsKey("annualEstimate")&&Convert.ToString(member["annualEstimate"])=="True")date=purchase.AddYears(1).ToString("yyyy-MM-dd");}Set(10,enabled&&!String.IsNullOrWhiteSpace(date)?date:"--","");}
    }
}

internal sealed class LinearAxis : Control {
    internal double? Maximum;
    protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);using(var f=MeterTheme.Font(7.5f*Font.Size/10f))using(var b=new SolidBrush(MeterTheme.Muted)){var g=e.Graphics;g.DrawString(Maximum.HasValue?"0":"--",f,b,0,0);if(Maximum>0){string mid=UsageOverview.Count(Maximum/2),end=UsageOverview.Count(Maximum);g.DrawString(mid,f,b,Width/2-g.MeasureString(mid,f).Width/2,0);g.DrawString(end,f,b,Width-g.MeasureString(end,f).Width,0);}}}
}
internal sealed class LinearScale : Control {
    readonly bool quota;
    internal double? Amount;
    internal Color Tone=MeterTheme.Green;
    internal LinearScale(bool quota){this.quota=quota;SetStyle(ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.UserPaint,true);}
    protected override void OnPaint(PaintEventArgs e){
        base.OnPaint(e);float s=Font.Size/10f*e.Graphics.DpiX/96f;int y=quota?0:Height/2;var g=e.Graphics;
        using(var track=new SolidBrush(MeterTheme.Line))g.FillRectangle(track,0,y,Width,quota?9*s:2*s);
        if(quota)using(var gap=new Pen(BackColor,4*s))for(int i=1;i<10;i++)g.DrawLine(gap,Width*i/10f,0,Width*i/10f,9*s);
        if(Amount.HasValue){float width=(float)Math.Max(0,Math.Min(1,Amount.Value))*Math.Max(0,quota?Width:Width-6*s);using(var fill=new SolidBrush(Tone)){g.FillRectangle(fill,0,y,width,quota?9*s:2*s);if(!quota){g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;g.FillEllipse(fill,Math.Max(0,width-5*s),y-5*s,11*s,11*s);}}}
        if(quota)using(var f=MeterTheme.Font(7*s))using(var b=new SolidBrush(MeterTheme.Muted)){g.DrawString("0",f,b,0,14*s);g.DrawString("50",f,b,Width/2f-7*s,14*s);g.DrawString("100%",f,b,Width-30*s,14*s);}
    }
}
