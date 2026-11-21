using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Web.Script.Serialization;
using System.Windows.Forms;

internal sealed class UsageOverview : UserControl {
    readonly Label[] values=new Label[12],captions=new Label[12],names=new Label[12];
    readonly Panel[] groups=new Panel[12];
    readonly bool[] selected=new bool[12];
    readonly LinearScale[] charts=new LinearScale[6];
    readonly Label quotaTitle,tokenTitle,scope,source,empty;
    readonly UsageTrend trend;
    readonly Button dailyMode,cumulativeMode;
    readonly Label readout,month;
    readonly Panel details,meta;
    readonly Panel canvas;
    bool arranging;
    DateTime snapshotDate=DateTime.UtcNow;
    DateTime? syncTime;
    readonly string[] keys={"short","week","daily","weekly","lifetime","average","reset","resetCredits","credits","plan","renewal","monthly"};
    internal double TokenScale {get;private set;}
    internal UsageOverview(){
        Name="usageOverview";Dock=DockStyle.Fill;Height=560;AutoScroll=true;BackColor=MeterTheme.Surface;
        canvas=new Panel();Controls.Add(canvas);
        string[] labels={"5-hour remaining","Weekly remaining","Daily tokens","Weekly tokens","Lifetime tokens","Monthly daily average","Quota reset date","Reset count","Credits","Plan","Renewal","Monthly tokens"};
        quotaTitle=Label("Quota remaining",11,MeterTheme.Ink);tokenTitle=Label("Usage trend",11,MeterTheme.Ink);
        scope=Label("UTC",8,MeterTheme.Muted);scope.TextAlign=ContentAlignment.MiddleRight;
        month=Label("",9,MeterTheme.Muted);month.Name="usageMonth";
        trend=new UsageTrend{Name="monthlyTrend"};canvas.Controls.Add(trend);
        readout=Label("",9,MeterTheme.Blue);readout.BackColor=MeterTheme.Tint(Color.FromArgb(237,244,255));
        trend.SelectionChanged+=(s,e)=>RefreshReadout();
        dailyMode=MeterTheme.Button("dailyTrend","Daily",false);cumulativeMode=MeterTheme.Button("cumulativeTrend","Cumulative",false);
        foreach(var b in new[]{dailyMode,cumulativeMode}){canvas.Controls.Add(b);b.Click+=(s,e)=>SetTrendMode(b==cumulativeMode);}
        source=Label("Local CLI",8,MeterTheme.Muted);source.TextAlign=ContentAlignment.MiddleRight;source.AccessibleDescription=Locale.T("Usage: local CLI. Plan: desktop detection or manual record.");
        empty=Label("No metrics selected.",10,MeterTheme.Muted);empty.Visible=false;
        details=new Panel{BackColor=MeterTheme.Tint(Color.FromArgb(243,247,254))};meta=new Panel();canvas.Controls.Add(details);canvas.Controls.Add(meta);
        details.Controls.Add(quotaTitle);
        details.Paint+=(s,e)=>{using(var pen=new Pen(MeterTheme.Tint(Color.FromArgb(220,230,246))))e.Graphics.DrawRectangle(pen,0,0,details.Width-1,details.Height-1);};
        meta.Paint+=(s,e)=>{using(var pen=new Pen(MeterTheme.Line))e.Graphics.DrawLine(pen,0,0,meta.Width,0);};
        for(int i=0;i<keys.Length;i++){
            selected[i]=true;var group=groups[i]=new Panel{Name="group-"+keys[i]};
            (i==9||i==10?meta:i==2||i==5?(Control)canvas:details).Controls.Add(group);
            names[i]=MeterTheme.Label(labels[i],i<2?8:9,MeterTheme.Muted);names[i].Dock=DockStyle.None;group.Controls.Add(names[i]);
            values[i]=MeterTheme.Label("--",i<2?14:i==11?14:i>=9?9:i>=6?9:11,MeterTheme.Ink);values[i].Name="metric"+i;values[i].Dock=DockStyle.None;group.Controls.Add(values[i]);
            captions[i]=MeterTheme.Label("Not returned",8,MeterTheme.Muted);captions[i].Name="metricCaption"+i;captions[i].Dock=DockStyle.None;group.Controls.Add(captions[i]);
        }
        int[] chartGroups={0,1,2,5,3,4};
        for(int i=0;i<charts.Length;i++){charts[i]=new LinearScale(i<2);charts[i].Name="linearScale"+i;groups[chartGroups[i]].Controls.Add(charts[i]);}
        tokenTitle.TextChanged+=(s,e)=>{SetTrendMode(trend.Cumulative);Arrange();};source.TextChanged+=(s,e)=>Arrange();
        Resize+=(s,e)=>{Arrange();AutoScrollPosition=Point.Empty;};Load+=(s,e)=>AutoScrollPosition=Point.Empty;Arrange();
    }
    Label Label(string text,float size,Color color){var label=MeterTheme.Label(text,size,color);label.Dock=DockStyle.None;canvas.Controls.Add(label);return label;}
    new void Bounds(Control c,float x,float y,float w,float h,float s){c.SetBounds((int)(x*s),(int)(y*s),Math.Max(0,(int)(w*s)),Math.Max(0,(int)(h*s)));}
    void Arrange(){
        if(groups[10]==null||arranging)return;
        arranging=true;
        try{
        float s;using(var g=CreateGraphics())s=g.DpiX/96f;
        int needed=ArrangeColumns(Width/s,s);
        bool scroll=needed>Height+1;
        int width=Math.Max(0,Width-(scroll?SystemInformation.VerticalScrollBarWidth:0));
        if(scroll)needed=ArrangeColumns(width/s,s);
        AutoScroll=scroll;AutoScrollMinSize=scroll?new Size(0,needed):Size.Empty;
        canvas.Size=new Size(width,Math.Max(Height,needed));
        canvas.Location=new Point(0,scroll?AutoScrollPosition.Y:0);
        }finally{arranging=false;}
    }
    int ArrangeColumns(float w,float s){
        var rightKeys=new[]{11,3,4,6,7,8};
        int quotaCount=(selected[0]?1:0)+(selected[1]?1:0);
        bool hasRight=quotaCount>0||Array.Exists(rightKeys,i=>selected[i]);
        bool plot=selected[2]||selected[11], comparison=selected[2]||selected[5],hasLeft=plot||comparison;
        bool stack=hasLeft&&hasRight&&w<540;
        float rw=hasRight&&hasLeft&&!stack?Math.Max(220,w*.30f):w,left=hasRight&&hasLeft&&!stack?w-rw-22:w;
        bool compact=!stack&&Height/s<445;
        float y=compact?26:31;
        Bounds(month,0,0,w-33,20,s);Bounds(scope,w-33,0,33,20,s);
        Bounds(tokenTitle,0,y,Math.Max(60,left-180),28,s);Bounds(dailyMode,left-172,y,84,26,s);Bounds(cumulativeMode,left-84,y,84,26,s);
        if(plot){
            float graphHeight=compact?Math.Max(145,Math.Min(193,Height/s-205)):213;
            y+=compact?32:39;Bounds(trend,0,y,left,graphHeight,s);y+=graphHeight;Bounds(readout,0,y,left,33,s);y+=compact?37:47;
        }
        if(comparison){
            int n=0,count=(selected[2]?1:0)+(selected[5]?1:0);float cell=(left-(count-1)*12)/count;
            int labelHeight=cell<220?36:24;
            foreach(int i in new[]{2,5})if(selected[i]){
                float valueWidth=Math.Min(81,cell*.45f),nameWidth=cell-valueWidth;
                Bounds(groups[i],n++*(cell+12),y,cell,labelHeight+17,s);Bounds(names[i],0,0,nameWidth,labelHeight,s);
                Bounds(values[i],nameWidth,0,valueWidth,labelHeight,s);values[i].TextAlign=ContentAlignment.MiddleRight;
                Bounds(charts[i==2?2:3],0,labelHeight+5,cell,7,s);captions[i].Visible=false;
            }
            y+=labelHeight+14;
        }
        float panelY=stack?y+8:compact?26:31;
        float inner=Math.Max(0,rw-20),py=compact?32:37;
        Bounds(quotaTitle,10,7,inner,22,s);
        if(quotaCount>0){
            int n=0;float cell=inner/quotaCount;
            for(int i=0;i<2;i++)if(selected[i]){
                Bounds(groups[i],10+n++*cell,py,cell,100,s);
                Bounds(charts[i],0,0,cell,60,s);values[i].Visible=false;
                Bounds(names[i],0,61,cell,18,s);names[i].TextAlign=ContentAlignment.MiddleCenter;
                Bounds(captions[i],0,80,cell,20,s);captions[i].TextAlign=ContentAlignment.MiddleCenter;
            }
            py+=compact?100:106;
        }
        foreach(int i in rightKeys)if(selected[i]){
            float h=i==11?37:25;
            Bounds(groups[i],10,py,inner,h,s);groups[i].BackColor=i==11?MeterTheme.Tint(Color.FromArgb(232,241,255)):details.BackColor;
            float ratio=i==3||i==4?.52f:.63f;
            Bounds(names[i],i==11?6:0,0,inner*ratio,h,s);Bounds(values[i],inner*.63f,0,inner*.37f-5,h,s);values[i].TextAlign=ContentAlignment.MiddleRight;
            if(i==3||i==4)Bounds(charts[i+1],inner*.52f,8,inner*.19f,8,s);
            captions[i].Visible=false;py+=h;
        }
        Bounds(details,stack||!hasLeft?0:left+22,panelY,rw,py+9,s);
        if(hasRight)y=Math.Max(y,panelY+py+9);
        y+=11;Bounds(meta,0,y,w,27,s);
        float mx=0;
        foreach(int i in new[]{9,10})if(selected[i]){
            float cell=Math.Min(210,w/(selected[9]&&selected[10]?2:1));
            Bounds(groups[i],mx,3,cell,24,s);Bounds(names[i],0,0,cell*.43f,23,s);Bounds(values[i],cell*.43f,0,cell*.57f,23,s);captions[i].Visible=false;mx+=cell;
        }
        float sourceLeft=mx==0?0:Math.Min(mx,w);
        bool inline=mx==0||w-sourceLeft>=(syncTime.HasValue?174:75);
        if(!inline)y+=29;
        Bounds(source,inline?sourceLeft:0,y,w-(inline?sourceLeft:0),23,s);Bounds(empty,0,20,w,40,s);
        quotaTitle.Visible=details.Visible=hasRight;tokenTitle.Visible=trend.Visible=readout.Visible=plot;
        dailyMode.Visible=plot&&selected[2];cumulativeMode.Visible=plot&&selected[11];meta.Visible=mx>0;
        bool any=Array.Exists(selected,v=>v);empty.Visible=!any;source.Visible=month.Visible=scope.Visible=any;
        for(int i=0;i<groups.Length;i++)groups[i].Visible=selected[i];
        return (int)Math.Ceiling((any?y+22:64)*s);
    }
    void RefreshReadout(){readout.Text=trend.SelectedValue.HasValue?trend.Month+"-"+(trend.SelectedDay+1).ToString("00")+"   "+Count(trend.SelectedValue)+" Token"+(trend.NoEntry?"   ·   "+Locale.T("No usage records"):""):Locale.T("No usage records");}
    void SetTrendMode(bool cumulative){trend.Cumulative=cumulative;foreach(var b in new[]{dailyMode,cumulativeMode}){bool on=(b==cumulativeMode)==cumulative;b.BackColor=on?MeterTheme.SoftFill:MeterTheme.Secondary;b.ForeColor=on?MeterTheme.SoftInk:MeterTheme.Ink;b.FlatAppearance.BorderColor=on?MeterTheme.Blue:MeterTheme.Line;b.AccessibleDescription=on?Locale.T("Selected"):"";}RefreshReadout();}
    internal void RefreshLanguage(){
        month.Text=snapshotDate.ToString("Y",CultureInfo.GetCultureInfo(Locale.Language=="en"?"en-US":Locale.Language));
        source.Text=Locale.T("Local CLI")+(syncTime.HasValue?"  ·  "+Locale.T("Last sync")+" "+syncTime.Value.ToString("HH:mm",CultureInfo.InvariantCulture):"");
        RefreshReadout();Arrange();
    }
    static double? Number(object value){if(value==null||value is bool||value is string)return null;try{double n=Convert.ToDouble(value);return Double.IsNaN(n)||Double.IsInfinity(n)||n<0?null:(double?)n;}catch{return null;}}
    static double? N(Dictionary<string,object> data,string key){object v;return data.TryGetValue(key,out v)?Number(v):null;}
    static bool Fresh(Dictionary<string,object> d,string key,double now,double age){var n=N(d,key);return n.HasValue&&now>=n.Value&&now-n.Value<age;}
    internal static string Count(double? n){if(!n.HasValue||n.Value>9007199254740991)return "--";return n.Value>=1e9?(n.Value/1e9).ToString("0.##",CultureInfo.InvariantCulture)+"B":n.Value>=1e6?(n.Value/1e6).ToString("0.##",CultureInfo.InvariantCulture)+"M":n.Value>=1e3?(n.Value/1e3).ToString("0.##",CultureInfo.InvariantCulture)+"K":n.Value.ToString("0.##",CultureInfo.InvariantCulture);}
    static double? Integer(double? n){return n.HasValue&&n<=9007199254740991&&n==Math.Floor(n.Value)?n:null;}
    void Set(int index,string value,string caption){values[index].Text=value;values[index].ForeColor=value=="--"?MeterTheme.Muted:MeterTheme.Ink;captions[index].Text=Locale.T(caption);groups[index].AccessibleName=Locale.T(names[index].Text)+": "+value+" "+Locale.T(caption);if(index<2)charts[index].DialText=value;}
    internal void UpdateSnapshot(Dictionary<string,object> data,bool connected,double now){
        string state=!connected?"Not connected":!N(data,"generatedAt").HasValue||Fresh(data,"generatedAt",now,90000)?"Not returned":"Data expired";
        for(int i=0;i<keys.Length;i++)Set(i,"--",state);foreach(var chart in charts)chart.Amount=null;
        object visible;var map=data.TryGetValue("visible",out visible)?visible as Dictionary<string,object>:null;
        for(int i=0;i<keys.Length;i++){object v;selected[i]=map==null||!map.TryGetValue(keys[i],out v)||!(v is bool)||(bool)v;}
        var date=new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddMilliseconds(now);
        string currentMonth=date.ToString("yyyy-MM",CultureInfo.InvariantCulture);
        snapshotDate=date;syncTime=null;
        var usageAt=N(data,"usageAt");if(connected&&usageAt.HasValue&&usageAt.Value<=now)syncTime=new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddMilliseconds(usageAt.Value).ToLocalTime();
        RefreshLanguage();
        double?[] points=new double?[0];
        var missing=new HashSet<int>();
        TokenScale=0;
        if(connected&&Fresh(data,"generatedAt",now,90000)){
            if(Fresh(data,"quotaAt",now,180000)){
                object windows;if(data.TryGetValue("windows",out windows)&&windows is IEnumerable){var seen=new HashSet<int>();foreach(object item in (IEnumerable)windows){var d=item as Dictionary<string,object>;if(d==null)continue;var minutes=N(d,"minutes");var remaining=N(d,"remaining");int index=minutes==300?0:minutes==10080?1:-1;if(index<0||!remaining.HasValue||remaining>100)continue;if(!seen.Add(index)){Set(index,"--","Not returned");charts[index].Amount=null;continue;}Set(index,remaining.Value.ToString("0.#",CultureInfo.InvariantCulture)+"%",(100-remaining.Value).ToString("0.#")+"% "+Locale.T("Used"));charts[index].Amount=remaining.Value/100;var reset=N(d,"resetsAt");if(reset.HasValue)Set(6,Time(reset),"");}}
                Set(7,Count(Integer(N(data,"resetCredits"))),"");object balance;decimal credit;if(data.TryGetValue("creditBalance",out balance)&&balance is string&&System.Text.RegularExpressions.Regex.IsMatch((string)balance,@"^\d+(\.\d+)?$")&&Decimal.TryParse((string)balance,NumberStyles.AllowDecimalPoint,CultureInfo.InvariantCulture,out credit)&&credit<=9007199254740991m)Set(8,Decimal.Floor(credit).ToString(CultureInfo.InvariantCulture),"");
            }else if(N(data,"quotaAt").HasValue){Set(0,"--","Data expired");Set(1,"--","Data expired");}
            if(Fresh(data,"usageAt",now,5400000)){
                foreach(var item in new[]{new KeyValuePair<int,string>(3,"week"),new KeyValuePair<int,string>(4,"lifetime"),new KeyValuePair<int,string>(5,"monthAverage")}){string value=Count(Integer(N(data,item.Value)));Set(item.Key,value,value=="--"?"Not returned":item.Key==3?"Monday to now":item.Key==4?"Account lifetime":"");}
                string monthly=Count(Integer(N(data,"monthTotal")));object partial;
                Set(11,monthly,monthly=="--"?"Not returned":data.TryGetValue("monthPartial",out partial)&&true.Equals(partial)?"Partial data":"");
                double? dailyValue=null;object daily;if(data.TryGetValue("daily",out daily)&&daily is Dictionary<string,object>){var d=(Dictionary<string,object>)daily;object label;DateTime day;if(d.TryGetValue("date",out label)&&DateTime.TryParseExact(Convert.ToString(label),"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out day)){dailyValue=Integer(N(d,"value"));string value=Count(dailyValue);var local=new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddMilliseconds(now).ToLocalTime().Date;string caption=day.Date==local.AddDays(-1)?"Yesterday":day.Date==local?"Today":Locale.T("Data date")+": "+day.ToString("yyyy-MM-dd");names[2].Text=Locale.T(caption);Set(2,value,value=="--"?"Not returned":"");}}
                double? average=Integer(N(data,"monthAverage"));double a=dailyValue.GetValueOrDefault(),b=average.GetValueOrDefault();
                var weekly=Integer(N(data,"week"));var lifetime=Integer(N(data,"lifetime"));
                double range=Math.Max(weekly.GetValueOrDefault(),lifetime.GetValueOrDefault());
                if(weekly.HasValue)charts[4].Amount=range==0?0:weekly.Value/range;
                if(lifetime.HasValue)charts[5].Amount=range==0?0:lifetime.Value/range;
                TokenScale=SharedMaximum(Math.Max(selected[2]?a:0,selected[5]?b:0));
                charts[2].Amount=!dailyValue.HasValue?null:(double?)(TokenScale==0?0:a/TokenScale);charts[3].Amount=!average.HasValue?null:(double?)(TokenScale==0?0:b/TokenScale);
                object series,days,key;
                if(data.TryGetValue("monthTrend",out series)&&series is Dictionary<string,object>){
                    var trendData=(Dictionary<string,object>)series;
                    if(trendData.TryGetValue("month",out key)&&currentMonth.Equals(key)&&trendData.TryGetValue("days",out days)&&days is IList){
                        var list=(IList)days;points=new double?[Math.Min(date.Day,list.Count)];
                        for(int i=0;i<points.Length;i++)points[i]=Integer(Number(list[i]));
                        if(Array.Exists(points,p=>p.HasValue)){
                            for(int i=0;i<points.Length;i++)if(list[i]==null){points[i]=0;missing.Add(i);}
                        }
                    }
                }
            }else if(N(data,"usageAt").HasValue)foreach(int i in new[]{2,3,4,5,11})Set(i,"--","Data expired");
            object v;if(data.TryGetValue("planBadge",out v)&&v is string&&!String.IsNullOrWhiteSpace((string)v))Set(9,(string)v,"");
            if(data.TryGetValue("renewalDate",out v)&&v is string&&!String.IsNullOrWhiteSpace((string)v))Set(10,(string)v,"");
        }
        charts[0].Tone=charts[2].Tone=MeterTheme.Blue;charts[1].Tone=charts[3].Tone=MeterTheme.Tint(Color.FromArgb(33,77,182));
        trend.UpdateSeries(currentMonth,points,missing);
        SetTrendMode(!selected[2]&&selected[11]||selected[11]&&trend.Cumulative);
        Arrange();foreach(var chart in charts)chart.Invalidate();
    }
    internal static double SharedMaximum(double value){if(value<=0)return 0;double unit=Math.Pow(10,Math.Floor(Math.Log10(value)));return Math.Ceiling(value/unit/0.5)*unit*.5;}
    static string Time(double? n){if(!n.HasValue||n<=0)return "--";try{return new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddMilliseconds(n.Value<100000000000d?n.Value*1000:n.Value).ToLocalTime().ToString("MM/dd HH:mm");}catch{return "--";}}
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

internal sealed class UsageTrend : Control {
    double?[] days=new double?[0];
    bool cumulative;
    internal string Month="";
    internal int SelectedDay=-1;
    internal event EventHandler SelectionChanged;
    internal UsageTrend(){TabStop=true;SetStyle(ControlStyles.UserPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.ResizeRedraw|ControlStyles.AllPaintingInWmPaint|ControlStyles.Selectable,true);AccessibleName="Usage trend";}
    internal bool Cumulative {get{return cumulative;} set{cumulative=value;Invalidate();}}
    internal double? SelectedValue{get{return SelectedDay<0||SelectedDay>=days.Length||!days[SelectedDay].HasValue?null:(cumulative?Sum(SelectedDay):days[SelectedDay]);}}
    double Sum(int end){double total=0;for(int i=0;i<=end;i++)total+=days[i].GetValueOrDefault();return total;}
    HashSet<int> noEntries=new HashSet<int>();
    internal bool NoEntry{get{return noEntries.Contains(SelectedDay);}}
    internal void UpdateSeries(string month,double?[] points,HashSet<int> missing){
        noEntries=missing;
        bool changed=Month!=month;Month=month;days=points;
        if(changed||SelectedDay<0||SelectedDay>=days.Length||!days[SelectedDay].HasValue)SelectedDay=Array.FindLastIndex(days,n=>n.HasValue);
        Invalidate();
    }
    void SelectDay(int day,int step){
        while(day>=0&&day<days.Length&&!days[day].HasValue)day+=step;
        if(day<0||day>=days.Length)return;
        SelectedDay=day;Invalidate();if(SelectionChanged!=null)SelectionChanged(this,EventArgs.Empty);
    }
    protected override bool IsInputKey(Keys key){var k=key&Keys.KeyCode;return k==Keys.Left||k==Keys.Right||base.IsInputKey(key);}
    protected override void OnKeyDown(KeyEventArgs e){base.OnKeyDown(e);if(e.KeyCode==Keys.Left||e.KeyCode==Keys.Right){int d=e.KeyCode==Keys.Left?-1:1;SelectDay(SelectedDay+d,d);e.Handled=true;}}
    protected override void OnMouseDown(MouseEventArgs e){base.OnMouseDown(e);Focus();if(days.Length==0)return;using(var g=CreateGraphics()){float s=g.DpiX/96;int i=(int)Math.Round((e.X-49*s)/Math.Max(1,Width-67*s)*Math.Max(1,days.Length-1));i=Math.Min(days.Length-1,Math.Max(0,i));if(days[i].HasValue)SelectDay(i,1);}}
    protected override void OnGotFocus(EventArgs e){base.OnGotFocus(e);Invalidate();}
    protected override void OnLostFocus(EventArgs e){base.OnLostFocus(e);Invalidate();}
    protected override void OnPaint(PaintEventArgs e){
        var g=e.Graphics;float s=g.DpiX/96;g.Clear(SystemInformation.HighContrast?MeterTheme.Surface:MeterTheme.Tint(Color.FromArgb(251,253,255)));
        using(var font=MeterTheme.Font(8.25f))using(var edge=new Pen(MeterTheme.Tint(Color.FromArgb(220,230,246))))using(var ink=new Pen(MeterTheme.Blue,2*s))using(var dot=new SolidBrush(MeterTheme.Blue)){
            g.DrawRectangle(edge,0,0,Math.Max(0,Width-1),Math.Max(0,Height-1));
            float x0=49*s,x1=Math.Max(x0+1,Width-18*s),y0=15*s,y1=Math.Max(y0+1,Height-24*s);
            double max=0;for(int i=0;i<days.Length;i++)if(days[i].HasValue)max=Math.Max(max,cumulative?Sum(i):days[i].Value);
            max=Math.Max(1,UsageOverview.SharedMaximum(max));
            var flags=TextFormatFlags.NoPadding|TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine;
            for(int i=0;i<=4;i++){float y=y1-(y1-y0)*i/4;g.DrawLine(edge,x0,y,x1,y);if(SelectedDay>=0)TextRenderer.DrawText(g,UsageOverview.Count(max*i/4),font,new Point((int)(8*s),(int)(y-6*s)),MeterTheme.Muted,flags);}
            if(SelectedDay<0){TextRenderer.DrawText(g,Locale.T("No usage records"),font,ClientRectangle,MeterTheme.Muted,flags|TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);return;}
            Func<int,float> x=i=>x0+(x1-x0)*i/Math.Max(1,days.Length-1);
            int stride=Math.Max(1,(days.Length+3)/4);
            for(int i=0;i<days.Length;i++)if(i%stride==0||i==days.Length-1&&i%stride>=2)TextRenderer.DrawText(g,(i+1).ToString(),font,new Point((int)x(i)-4,(int)y1+4),MeterTheme.Muted,flags);
            using(var cursor=new Pen(MeterTheme.Tint(Color.FromArgb(165,188,227)))){cursor.DashStyle=System.Drawing.Drawing2D.DashStyle.Dash;g.DrawLine(cursor,x(SelectedDay),y0,x(SelectedDay),y1);}
            g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            PointF? previous=null;
            for(int i=0;i<days.Length;i++){if(!days[i].HasValue){previous=null;continue;}var next=new PointF(x(i),y1-(float)((cumulative?Sum(i):days[i].Value)/max)*(y1-y0));if(previous.HasValue)g.DrawLine(ink,previous.Value,next);float radius=(i==SelectedDay?4:2.5f)*s;g.FillEllipse(dot,next.X-radius,next.Y-radius,radius*2,radius*2);previous=next;}
        }
        if(Focused&&ShowFocusCues)ControlPaint.DrawFocusRectangle(g,new Rectangle(2,2,Width-4,Height-4));
    }
}
internal sealed class LinearScale : Control {
    readonly bool quota;
    internal double? Amount;
    internal string DialText="--";
    internal Color Tone=MeterTheme.Green;
    internal LinearScale(bool quota){this.quota=quota;SetStyle(ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.UserPaint,true);}
    protected override void OnPaint(PaintEventArgs e){
        base.OnPaint(e);float s=e.Graphics.DpiX/96f;var g=e.Graphics;
        if(quota){
            float d=Math.Min(Width-10*s,2*(Height-7*s));if(d<=0)return;
            var arc=new RectangleF((Width-d)/2,5*s,d,d);g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            using(var pen=new Pen(MeterTheme.Tint(Color.FromArgb(209,224,246)),7*s)){pen.StartCap=pen.EndCap=System.Drawing.Drawing2D.LineCap.Round;g.DrawArc(pen,arc,180,180);if(Amount>0){pen.Color=Tone;g.DrawArc(pen,arc,180,(float)Math.Min(180,Amount.Value*180));}}
            using(var font=MeterTheme.Font(14))TextRenderer.DrawText(g,DialText,font,new Rectangle(0,(int)(21*s),Width,(int)(28*s)),Amount.HasValue?MeterTheme.Ink:MeterTheme.Muted,TextFormatFlags.NoPadding|TextFormatFlags.SingleLine|TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);
            return;
        }
        float h=Math.Min(Height,4*s),y=(Height-h)/2;
        using(var track=new SolidBrush(MeterTheme.Line))g.FillRectangle(track,0,y,Width,h);
        if(Amount.HasValue){float width=(float)Math.Max(0,Math.Min(1,Amount.Value))*Width;using(var fill=new SolidBrush(Tone))g.FillRectangle(fill,0,y,width,h);}
    }
}
