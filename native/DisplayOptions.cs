using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;
internal static class DisplayOptions {
    internal static readonly string[] Keys={"plan","short","week","reset","renewal","daily","average","weekly","lifetime","credits","resetCredits","monthly"};
    static readonly string[] Labels={Locale.T("Plan badge"),Locale.T("5h remaining"),Locale.T("Weekly remaining"),Locale.T("Quota reset"),Locale.T("Renewal date"),Locale.T("Daily tokens"),Locale.T("Monthly daily average"),Locale.T("Weekly tokens"),Locale.T("Lifetime tokens"),Locale.T("Credits"),Locale.T("Available quota resets"),Locale.T("Monthly tokens")};
    internal static CheckedListBox List(string root){
        var list=new CheckedListBox{Name="displayOptions",CheckOnClick=true,BorderStyle=BorderStyle.None,Dock=DockStyle.Top,Height=200,MultiColumn=true,ColumnWidth=280,IntegralHeight=false};
        Dictionary<string,bool> settings=null;try{settings=new JavaScriptSerializer().Deserialize<Dictionary<string,bool>>(File.ReadAllText(Path.Combine(root,"display.json"),Encoding.UTF8));}catch{}
        for(int i=0;i<Keys.Length;i++)list.Items.Add(Labels[i],settings==null||!settings.ContainsKey(Keys[i])||settings[Keys[i]]);return list;
    }
    internal static Dictionary<string,bool> Capture(CheckedListBox list){var data=new Dictionary<string,bool>();for(int i=0;i<Keys.Length;i++)data[Keys[i]]=list.GetItemChecked(i);return data;}
    internal static Control Grouped(CheckedListBox list,Panel actionHost=null){
        var group=new Panel{Name="displayGroups",Dock=DockStyle.Top,Margin=Padding.Empty};
        var all=MeterTheme.Button("selectAll","Select all",false);
        var count=MeterTheme.Label("",13,MeterTheme.Blue);count.Name="selectionCount";
        var buttons=new[]{all};
        group.Controls.Add(count);
        foreach(var button in buttons){button.Font=MeterTheme.Font(9);(actionHost??group).Controls.Add(button);}
        Action refresh=()=>{int n=0;for(int i=0;i<Keys.Length;i++)if(list.GetItemChecked(i))n++;all.Text=Locale.T(n==Keys.Length?"Select none":"Select all");count.Tag=n;count.Text=Locale.T("Selected")+" "+n+" / "+Keys.Length;};
        string[] titles={"Plan and dates","Quota and resets","Token usage"};
        var headings=new Label[3];var rules=new Panel[3];
        for(int i=0;i<3;i++){headings[i]=MeterTheme.Label(titles[i],10,MeterTheme.Ink);rules[i]=new Panel{BackColor=MeterTheme.Line};group.Controls.Add(headings[i]);group.Controls.Add(rules[i]);}
        var names=new[]{"Plan badge","5-hour remaining","Weekly remaining","Quota reset","Codex renewal date","Daily tokens","Monthly daily average","Weekly tokens","Lifetime tokens","Credits","Available quota resets","Monthly tokens"};
        int[][] groups={new[]{0,4},new[]{1,2,3,10,9},new[]{5,6,7,11,8}};
        var checks=new CheckBox[Keys.Length];
        for(int i=0;i<Keys.Length;i++){int index=i;var check=checks[i]=new CheckBox{Name="display-"+Keys[i],Text=names[i],Checked=list.GetItemChecked(i),AutoSize=false,Font=MeterTheme.Font(9.75f)};check.CheckedChanged+=(s,e)=>{list.SetItemChecked(index,check.Checked);refresh();};group.Controls.Add(check);}
        bool arranging=false;Action arrange=()=>{if(arranging||group.IsDisposed)return;arranging=true;try{using(var g=group.CreateGraphics()){
            Func<int,int> px=n=>(int)Math.Round(n*g.DpiX/96);int width=group.ClientSize.Width;
            count.Dock=DockStyle.None;count.SetBounds(0,0,width,px(31));
            bool stack=width<px(535);int top=px(46),gap=px(18),col=stack?width:(width-2*gap)/3;
            for(int i=0;i<3;i++){int x=stack?0:i*(col+gap);var h=headings[i];int w=Math.Min(col,TextRenderer.MeasureText(g,h.Text,h.Font).Width+px(4));
                h.Dock=DockStyle.None;h.SetBounds(x,top,w,px(24));rules[i].SetBounds(x+w+px(3),top+px(12),Math.Max(0,col-w-px(3)),1);
                for(int j=0;j<groups[i].Length;j++)checks[groups[i][j]].SetBounds(x,top+px(31+j*31),col,px(30));
                if(stack)top+=px(40+31*groups[i].Length);}
            int bottom=stack?top:top+px(31+5*31+12);
            all.SetBounds(0,actionHost==null?bottom:px(4),Math.Max(px(88),TextRenderer.MeasureText(g,all.Text,all.Font).Width+px(22)),px(31));group.Height=actionHost==null?all.Bottom+px(10):bottom;
        }}finally{arranging=false;}};
        group.SizeChanged+=(s,e)=>arrange();group.HandleCreated+=(s,e)=>arrange();
        count.TextChanged+=(s,e)=>arrange();foreach(var c in buttons)c.TextChanged+=(s,e)=>arrange();foreach(var h in headings)h.TextChanged+=(s,e)=>arrange();arrange();
        all.Click+=(s,e)=>{bool choose=list.CheckedItems.Count!=Keys.Length;foreach(var check in checks)check.Checked=choose;};
        list.Visible=false;group.Controls.Add(list);refresh();Locale.Apply(group);return group;
    }
    internal static void Save(string root,Dictionary<string,bool> data){Directory.CreateDirectory(root);var path=Path.Combine(root,"display.json");var temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";try{File.WriteAllText(temp,new JavaScriptSerializer().Serialize(data),new UTF8Encoding(false));if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);}finally{if(File.Exists(temp))File.Delete(temp);}}
    internal static void Edit(string root){using(var form=new Form()){MeterTheme.Style(form,960,640);form.Text="AI Quota Board";var body=MeterTheme.Body();form.Controls.Add(body);form.Controls.Add(MeterTheme.Header(Locale.T("Sidebar display content"),"Windows "+MeterTheme.Version));var list=List(root);body.Controls.Add(Grouped(list));var footer=MeterTheme.Footer();var save=MeterTheme.Button("saveDisplay",Locale.T("Save"),true);save.Click+=(s,e)=>{try{Save(root,Capture(list));save.Text=Locale.T("Saved");save.Enabled=false;}catch(Exception ex){MeterTheme.Error(ex.Message);}};list.ItemCheck+=(s,e)=>{save.Text=Locale.T("Save");save.Enabled=true;};var cancel=MeterTheme.Button("cancelDisplay",Locale.T("Close"),false);cancel.Click+=(s,e)=>form.Close();footer.Controls.Add(save);footer.Controls.Add(cancel);form.Controls.Add(footer);body.BringToFront();form.ShowDialog();}}
}
