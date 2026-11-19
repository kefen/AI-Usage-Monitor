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
    readonly LinearScale[] charts=new LinearScale[4];
    readonly Label quotaTitle,tokenTitle,scope,source,empty;
    readonly LinearAxis axis;
    readonly Panel details,meta,tail;
    readonly Panel canvas;
    bool arranging;
    readonly string[] keys={"short","week","daily","weekly","lifetime","average","reset","resetCredits","credits","plan","renewal","monthly"};
    internal double TokenScale {get;private set;}
    internal UsageOverview(){
        Name="usageOverview";Dock=DockStyle.Fill;Height=560;AutoScroll=true;BackColor=MeterTheme.Surface;
        canvas=new Panel();Controls.Add(canvas);
        string[] labels={"5-hour remaining","Weekly remaining","Daily tokens","Weekly tokens","Lifetime tokens","Monthly daily average","Quota reset date","Reset count","Credits","Plan","Renewal","Monthly tokens"};
        quotaTitle=Label("Quota remaining",10,MeterTheme.Ink);tokenTitle=Label("Yesterday vs monthly daily average",10,MeterTheme.Ink);
        scope=Label("Shared Token scale",8,MeterTheme.Muted);axis=new LinearAxis();canvas.Controls.Add(axis);
        source=Label("Usage: local CLI. Plan: desktop detection or manual record.",9,MeterTheme.Muted);
        empty=Label("No metrics selected.",10,MeterTheme.Muted);empty.Visible=false;
        details=new Panel{BackColor=Color.FromArgb(247,248,250)};meta=new Panel();tail=new Panel();canvas.Controls.Add(details);canvas.Controls.Add(meta);canvas.Controls.Add(tail);
        foreach(var panel in new[]{meta,tail})panel.Paint+=(s,e)=>{var p=(Panel)s;using(var pen=new Pen(MeterTheme.Line))e.Graphics.DrawLine(pen,0,0,p.Width,0);};
        for(int i=0;i<keys.Length;i++){
            selected[i]=true;var group=groups[i]=new Panel{Name="group-"+keys[i]};
            (i>=6&&i<=8?details:i==9||i==10?meta:i==3||i==4||i==11?tail:(Control)canvas).Controls.Add(group);
            names[i]=MeterTheme.Label(labels[i],9,MeterTheme.Muted);names[i].Dock=DockStyle.None;group.Controls.Add(names[i]);
            values[i]=MeterTheme.Label("--",i<2?20:i==3||i==4||i==11?18:i>=9?9:i>=6?12:11,MeterTheme.Ink);values[i].Name="metric"+i;values[i].Dock=DockStyle.None;group.Controls.Add(values[i]);
            captions[i]=MeterTheme.Label("Not returned",8,MeterTheme.Muted);captions[i].Name="metricCaption"+i;captions[i].Dock=DockStyle.None;group.Controls.Add(captions[i]);
        }
        for(int i=0;i<4;i++){charts[i]=new LinearScale(i<2);charts[i].Name="linearScale"+i;groups[i==2?2:i==3?5:i].Controls.Add(charts[i]);}
        tokenTitle.TextChanged+=(s,e)=>Arrange();source.TextChanged+=(s,e)=>Arrange();
        Resize+=(s,e)=>{Arrange();AutoScrollPosition=Point.Empty;};Load+=(s,e)=>AutoScrollPosition=Point.Empty;Arrange();
    }
    Label Label(string text,float size,Color color){var label=MeterTheme.Label(text,size,color);label.Dock=DockStyle.None;canvas.Controls.Add(label);return label;}
    new void Bounds(Control c,float x,float y,float w,float h,float s){c.SetBounds((int)(x*s),(int)(y*s),Math.Max(0,(int)(w*s)),Math.Max(0,(int)(h*s)));}
    void Arrange(){
        if(groups[10]==null||arranging)return;
        arranging=true;
        try{
        float s;using(var g=CreateGraphics())s=g.DpiX/96f;
        // Compact whitespace first. Narrow rows put the chart below its label and value.
        float w=Width/s,available=Height/s,room=Math.Max(0,Math.Min(1,(available-470)/74));
        bool stack=w<690&&available>=660;
        if(stack)room=Math.Max(0,Math.Min(1,(available-604)/110));
        float gap=w<690?24:36,left=stack?w:(w-gap)*.465f,right=stack?0:left+gap,rw=stack?w:w-right;
        bool compactTrack=rw<340;
        float mainHeight=LayoutSections(left,right,rw,stack,compactTrack,room,s);
        float y=mainHeight+12;int count=0;for(int i=6;i<=8;i++)if(selected[i])count++;
        float detailHeight=60+26*room;Bounds(details,0,y,w,detailHeight,s);int n=0;
        for(int i=6;i<=8;i++)if(selected[i]){float width=(w-32)/Math.Max(1,count);Bounds(groups[i],16+n++*width,8,width,detailHeight-12,s);Bounds(names[i],0,0,width,22,s);Bounds(values[i],0,24,width,28,s);captions[i].Visible=false;}
        if(count>0)y+=detailHeight+8;
        float metaY=y;Bounds(meta,0,metaY,w,34,s);float labelWidth=36;
        using(var g=CreateGraphics())for(int i=9;i<=10;i++)if(selected[i])foreach(string text in Locale.Translations(i==9?"Plan":"Renewal"))labelWidth=Math.Max(labelWidth,(float)Math.Ceiling(TextRenderer.MeasureText(g,text,names[i].Font,new Size(Int32.MaxValue,Int32.MaxValue),TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine).Width/s));
        for(int i=9;i<=10;i++)if(selected[i]){
            bool both=selected[9]&&selected[10];float split=stack?(w+gap)*.5f:right;
            float x=i==9||!both?0:split,width=both?(i==9?split-gap:w-split):w;
            Bounds(groups[i],x,4,width,28,s);Bounds(names[i],0,0,labelWidth,26,s);Bounds(values[i],labelWidth+12,0,Math.Max(0,width-labelWidth-12),26,s);captions[i].Visible=false;
        }
        if(selected[9]||selected[10])y+=42;
        int sourceHeight=TextRenderer.MeasureText(source.Text,source.Font,new Size(Math.Max(1,(int)(w*s)),Int32.MaxValue),TextFormatFlags.WordBreak|TextFormatFlags.NoPrefix).Height;
        float sh=Math.Max(24,sourceHeight/s);Bounds(source,0,y,w,sh,s);Bounds(empty,0,20,w,40,s);
        quotaTitle.Visible=selected[0]||selected[1];tokenTitle.Visible=scope.Visible=axis.Visible=selected[2]||selected[5];
        tail.Visible=selected[3]||selected[4]||selected[11];details.Visible=count>0;meta.Visible=selected[9]||selected[10];
        bool any=false;foreach(bool v in selected)any|=v;empty.Visible=!any;source.Visible=any;
        for(int i=0;i<groups.Length;i++)groups[i].Visible=selected[i];
        int needed=(int)Math.Ceiling((any?y+sh:64)*s);
        bool scroll=needed>Height+1;
        AutoScroll=scroll;AutoScrollMinSize=scroll?new Size(0,needed):Size.Empty;
        canvas.Size=new Size(Math.Max(0,Width-(scroll?SystemInformation.VerticalScrollBarWidth:0)),Math.Max(Height,needed));
        canvas.Location=new Point(0,scroll?AutoScrollPosition.Y:0);
        }finally{arranging=false;}
    }
    float LayoutSections(float left,float right,float rw,bool stack,bool compact,float room,float s){
        Bounds(quotaTitle,0,0,left,24,s);int q=0;
        float quotaWidth=stack&&(selected[0]&&selected[1])?(left-24)/2:left;
        for(int i=0;i<2;i++)if(selected[i]){
            Bounds(groups[i],stack?q*(quotaWidth+24):0,32+(stack?0:q*(126+16*room)),quotaWidth,118+10*room,s);
            Bounds(names[i],0,0,quotaWidth,22,s);Bounds(values[i],0,24,quotaWidth,38,s);Bounds(charts[i],0,62,quotaWidth,34,s);Bounds(captions[i],0,98,quotaWidth,24,s);q++;
        }
        float qh=q==0?0:stack?154:32+q*(126+16*room);
        float top=stack?qh+16:0;
        float titleHeight=Math.Max(24,TextRenderer.MeasureText(tokenTitle.Text,tokenTitle.Font,new Size(Math.Max(1,(int)(rw*s)),Int32.MaxValue),TextFormatFlags.WordBreak|TextFormatFlags.NoPrefix).Height/s);
        Bounds(tokenTitle,right,top,rw,titleHeight,s);Bounds(scope,right,top+titleHeight+4,rw,22,s);
        int row=0;float rh=compact?72:58+18*room,rowsTop=top+titleHeight+30+14*room;
        foreach(int i in new[]{2,5})if(selected[i]){
            Bounds(groups[i],right,rowsTop+row*rh,rw,rh,s);
            float label=compact?Math.Max(0,rw-88):Math.Min(130,rw*.27f),chartX=compact?0:label+12,chartWidth=compact?rw:rw-chartX-94;
            Bounds(names[i],0,0,compact?rw-88:label,compact?38:42,s);Bounds(values[i],rw-84,0,84,34,s);values[i].TextAlign=ContentAlignment.MiddleRight;
            Bounds(charts[i==2?2:3],chartX,compact?38:8,Math.Max(0,chartWidth),compact?14:20,s);Bounds(captions[i],0,compact?52:36+8*room,rw,22,s);row++;
        }
        float axisY=rowsTop+row*rh;float ax=compact?0:Math.Min(130,rw*.27f)+12;
        Bounds(axis,right+ax,axisY,Math.Max(0,compact?rw:rw-ax-94),24,s);
        float tailY=row>0?axisY+32:top+32;
        int n=0;
        int columns=(selected[3]?1:0)+(selected[11]?1:0)+(selected[4]?1:0);
        bool wrap=columns==3&&rw<330;
        float rowHeight=84+16*room;
        Bounds(tail,right,tailY,rw,rowHeight*(wrap?2:1),s);
        foreach(int i in new[]{3,11,4})if(selected[i]){float width=rw/(wrap?2:columns);Bounds(groups[i],(wrap?n%2:n)*width,6+(wrap?n/2:0)*rowHeight,width,rowHeight-6,s);n++;Bounds(names[i],0,0,width-4,22,s);Bounds(values[i],0,22,width-4,36,s);Bounds(captions[i],0,58,width-4,20,s);}
        float th=tailY+(n>0?rowHeight*(wrap?2:1):0);
        return Math.Max(qh,th);
    }
    static double? Number(object value){if(value==null||value is bool||value is string)return null;try{double n=Convert.ToDouble(value);return Double.IsNaN(n)||Double.IsInfinity(n)||n<0?null:(double?)n;}catch{return null;}}
    static double? N(Dictionary<string,object> data,string key){object v;return data.TryGetValue(key,out v)?Number(v):null;}
    static bool Fresh(Dictionary<string,object> d,string key,double now,double age){var n=N(d,key);return n.HasValue&&now>=n.Value&&now-n.Value<age;}
    internal static string Count(double? n){if(!n.HasValue||n.Value>9007199254740991)return "--";return n.Value>=1e9?(n.Value/1e9).ToString("0.##",CultureInfo.InvariantCulture)+"B":n.Value>=1e6?(n.Value/1e6).ToString("0.##",CultureInfo.InvariantCulture)+"M":n.Value>=1e3?(n.Value/1e3).ToString("0.##",CultureInfo.InvariantCulture)+"K":n.Value.ToString("0.##",CultureInfo.InvariantCulture);}
    static double? Integer(double? n){return n.HasValue&&n<=9007199254740991&&n==Math.Floor(n.Value)?n:null;}
    void Set(int index,string value,string caption){values[index].Text=value;values[index].ForeColor=value=="--"?MeterTheme.Muted:MeterTheme.Ink;captions[index].Text=Locale.T(caption);groups[index].AccessibleName=Locale.T(names[index].Text)+": "+value+" "+Locale.T(caption);}
    internal void UpdateSnapshot(Dictionary<string,object> data,bool connected,double now){
        string state=!connected?"Not connected":!N(data,"generatedAt").HasValue||Fresh(data,"generatedAt",now,90000)?"Not returned":"Data expired";
        for(int i=0;i<keys.Length;i++)Set(i,"--",state);foreach(var chart in charts)chart.Amount=null;
        object visible;var map=data.TryGetValue("visible",out visible)?visible as Dictionary<string,object>:null;
        for(int i=0;i<keys.Length;i++){object v;selected[i]=map==null||!map.TryGetValue(keys[i],out v)||!(v is bool)||(bool)v;}
        TokenScale=0;axis.Maximum=null;
        if(connected&&Fresh(data,"generatedAt",now,90000)){
            if(Fresh(data,"quotaAt",now,180000)){
                object windows;if(data.TryGetValue("windows",out windows)&&windows is IEnumerable){var seen=new HashSet<int>();foreach(object item in (IEnumerable)windows){var d=item as Dictionary<string,object>;if(d==null)continue;var minutes=N(d,"minutes");var remaining=N(d,"remaining");int index=minutes==300?0:minutes==10080?1:-1;if(index<0||!remaining.HasValue||remaining>100)continue;if(!seen.Add(index)){Set(index,"--","Not returned");charts[index].Amount=null;continue;}Set(index,remaining.Value.ToString("0.#",CultureInfo.InvariantCulture)+"%",Locale.T("Remaining")+" "+remaining.Value.ToString("0.#")+"% / "+Locale.T("Used")+" "+(100-remaining.Value).ToString("0.#")+"%");charts[index].Amount=remaining.Value/100;var reset=N(d,"resetsAt");if(reset.HasValue)Set(6,Time(reset),"");}}
                Set(7,Count(Integer(N(data,"resetCredits"))),"");object balance;decimal credit;if(data.TryGetValue("creditBalance",out balance)&&balance is string&&System.Text.RegularExpressions.Regex.IsMatch((string)balance,@"^\d+(\.\d+)?$")&&Decimal.TryParse((string)balance,NumberStyles.AllowDecimalPoint,CultureInfo.InvariantCulture,out credit)&&credit<=9007199254740991m)Set(8,Decimal.Floor(credit).ToString(CultureInfo.InvariantCulture),"");
            }else if(N(data,"quotaAt").HasValue){Set(0,"--","Data expired");Set(1,"--","Data expired");}
            if(Fresh(data,"usageAt",now,5400000)){
                foreach(var item in new[]{new KeyValuePair<int,string>(3,"week"),new KeyValuePair<int,string>(4,"lifetime"),new KeyValuePair<int,string>(5,"monthAverage")}){string value=Count(Integer(N(data,item.Value)));Set(item.Key,value,value=="--"?"Not returned":item.Key==3?"Monday to now":item.Key==4?"Account lifetime":"");}
                string month=Count(Integer(N(data,"monthTotal")));object partial;
                Set(11,month,month=="--"?"Not returned":data.TryGetValue("monthPartial",out partial)&&true.Equals(partial)?"Partial data":"");
                double? dailyValue=null;object daily;if(data.TryGetValue("daily",out daily)&&daily is Dictionary<string,object>){var d=(Dictionary<string,object>)daily;object label;DateTime day;if(d.TryGetValue("date",out label)&&DateTime.TryParseExact(Convert.ToString(label),"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out day)){dailyValue=Integer(N(d,"value"));string value=Count(dailyValue);var local=new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddMilliseconds(now).ToLocalTime().Date;string caption=day.Date==local.AddDays(-1)?"Yesterday":day.Date==local?"Today":Locale.T("Data date")+": "+day.ToString("yyyy-MM-dd");names[2].Text=Locale.T(caption);Set(2,value,value=="--"?"Not returned":"");}}
                double? average=Integer(N(data,"monthAverage"));double a=dailyValue.GetValueOrDefault(),b=average.GetValueOrDefault();
                TokenScale=SharedMaximum(Math.Max(selected[2]?a:0,selected[5]?b:0));
                charts[2].Amount=!dailyValue.HasValue?null:(double?)(TokenScale==0?0:a/TokenScale);charts[3].Amount=!average.HasValue?null:(double?)(TokenScale==0?0:b/TokenScale);
                axis.Maximum=dailyValue.HasValue||average.HasValue?(double?)TokenScale:null;
            }else if(N(data,"usageAt").HasValue)foreach(int i in new[]{2,3,4,5,11})Set(i,"--","Data expired");
            object v;if(data.TryGetValue("planBadge",out v)&&v is string&&!String.IsNullOrWhiteSpace((string)v))Set(9,(string)v,"");
            if(data.TryGetValue("renewalDate",out v)&&v is string&&!String.IsNullOrWhiteSpace((string)v))Set(10,(string)v,"");
        }
        charts[0].Tone=charts[2].Tone=MeterTheme.Green;charts[1].Tone=charts[3].Tone=Color.FromArgb(36,134,109);
        Arrange();axis.Invalidate();foreach(var chart in charts)chart.Invalidate();
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

internal sealed class LinearAxis : Control {
    internal double? Maximum;
    protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);using(var f=MeterTheme.Font(9)){var g=e.Graphics;var flags=TextFormatFlags.NoPadding|TextFormatFlags.SingleLine|TextFormatFlags.NoPrefix;TextRenderer.DrawText(g,Maximum.HasValue?"0":"--",f,ClientRectangle,MeterTheme.Muted,flags);if(Maximum>0){TextRenderer.DrawText(g,UsageOverview.Count(Maximum/2),f,ClientRectangle,MeterTheme.Muted,flags|TextFormatFlags.HorizontalCenter);TextRenderer.DrawText(g,UsageOverview.Count(Maximum),f,ClientRectangle,MeterTheme.Muted,flags|TextFormatFlags.Right);}}}
}
internal sealed class LinearScale : Control {
    readonly bool quota;
    internal double? Amount;
    internal Color Tone=MeterTheme.Green;
    internal LinearScale(bool quota){this.quota=quota;SetStyle(ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer|ControlStyles.UserPaint,true);}
    protected override void OnPaint(PaintEventArgs e){
        base.OnPaint(e);float s=e.Graphics.DpiX/96f;int y=quota?0:Height/2;var g=e.Graphics;
        using(var track=new SolidBrush(MeterTheme.Line))g.FillRectangle(track,0,y,Width,quota?9*s:2*s);
        if(quota)using(var gap=new Pen(BackColor,4*s))for(int i=1;i<10;i++)g.DrawLine(gap,Width*i/10f,0,Width*i/10f,9*s);
        if(Amount.HasValue){float width=(float)Math.Max(0,Math.Min(1,Amount.Value))*Math.Max(0,quota?Width:Width-6*s);using(var fill=new SolidBrush(Tone)){g.FillRectangle(fill,0,y,width,quota?9*s:2*s);if(!quota){g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;g.FillEllipse(fill,Math.Max(0,width-5*s),y-5*s,11*s,11*s);}}}
        if(quota)using(var f=MeterTheme.Font(9)){var rect=new Rectangle(0,(int)(14*s),Width,Math.Max(0,Height-(int)(14*s)));var flags=TextFormatFlags.NoPadding|TextFormatFlags.NoPrefix|TextFormatFlags.SingleLine;TextRenderer.DrawText(g,"0",f,rect,MeterTheme.Muted,flags);TextRenderer.DrawText(g,"50",f,rect,MeterTheme.Muted,flags|TextFormatFlags.HorizontalCenter);TextRenderer.DrawText(g,"100%",f,rect,MeterTheme.Muted,flags|TextFormatFlags.Right);}
    }
}
