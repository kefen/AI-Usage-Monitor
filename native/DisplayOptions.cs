using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;
internal static class DisplayOptions {
    internal static readonly string[] Keys={"plan","short","week","reset","renewal","daily","average","weekly","lifetime","credits","resetCredits"};
    static readonly string[] Labels={Locale.T("Plan badge"),Locale.T("5h remaining"),Locale.T("Weekly remaining"),Locale.T("Quota reset"),Locale.T("Renewal date"),Locale.T("Daily tokens"),Locale.T("Monthly daily average"),Locale.T("Weekly tokens"),Locale.T("Lifetime tokens"),Locale.T("Credits"),Locale.T("Available quota resets")};
    internal static CheckedListBox List(string root){
        var list=new CheckedListBox{Name="displayOptions",CheckOnClick=true,BorderStyle=BorderStyle.None,Dock=DockStyle.Top,Height=200,MultiColumn=true,ColumnWidth=280,IntegralHeight=false};
        Dictionary<string,bool> settings=null;try{settings=new JavaScriptSerializer().Deserialize<Dictionary<string,bool>>(File.ReadAllText(Path.Combine(root,"display.json"),Encoding.UTF8));}catch{}
        for(int i=0;i<Keys.Length;i++)list.Items.Add(Labels[i],settings==null||!settings.ContainsKey(Keys[i])||settings[Keys[i]]);return list;
    }
    internal static Dictionary<string,bool> Capture(CheckedListBox list){var data=new Dictionary<string,bool>();for(int i=0;i<Keys.Length;i++)data[Keys[i]]=list.GetItemChecked(i);return data;}
    internal static Control Grouped(CheckedListBox list){
        var group=new Panel{Name="displayGroups",Dock=DockStyle.Top,Height=294};
        var toolbar=new TableLayoutPanel{Dock=DockStyle.Top,Height=48,ColumnCount=3,RowCount=1,Margin=new Padding(0)};
        toolbar.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));toolbar.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,112));toolbar.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,112));
        var none=MeterTheme.Button("selectNone","Select none",false);none.Dock=DockStyle.Top;none.Margin=new Padding(12,0,0,0);var all=MeterTheme.Button("selectAll","Select all",false);all.Dock=DockStyle.Top;all.Margin=new Padding(0,0,0,0);toolbar.Controls.Add(all,1,0);toolbar.Controls.Add(none,2,0);group.Controls.Add(toolbar);
        var count=MeterTheme.Label("",9,MeterTheme.Muted);count.Name="selectionCount";count.Dock=DockStyle.Fill;count.Margin=new Padding(0);toolbar.Controls.Add(count,0,0);
        Action refresh=()=>{int n=0;for(int i=0;i<Keys.Length;i++)if(list.GetItemChecked(i))n++;count.Tag=n;count.Text=Locale.T("Selected")+" "+n+" / 11";};
        var grid=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=3,RowCount=6,Margin=new Padding(0)};group.Controls.Add(grid);grid.BringToFront();
        for(int i=0;i<3;i++)grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,33.333f));
        for(int i=0;i<6;i++)grid.RowStyles.Add(new RowStyle(SizeType.Absolute,i==0?48:36));
        string[] headings={"Plan and dates","Quota and resets","Token usage"};for(int i=0;i<3;i++){var heading=MeterTheme.Label(headings[i],10,MeterTheme.Ink);heading.Margin=new Padding(0,12,24,8);grid.Controls.Add(heading,i,0);}
        var names=new[]{"Plan badge","5-hour remaining","Weekly remaining","Quota reset","Codex renewal date","Daily tokens","Monthly daily average","Weekly tokens","Lifetime tokens","Credits","Available quota resets"};
        int[] columns={0,1,1,1,0,2,2,2,2,1,1},rows={1,1,2,3,2,1,2,3,4,5,4};
        var checks=new CheckBox[Keys.Length];
        for(int i=0;i<Keys.Length;i++){int index=i;var check=checks[i]=new CheckBox{Name="display-"+Keys[i],Text=names[i],Checked=list.GetItemChecked(i),Dock=DockStyle.Fill,AutoSize=false,Margin=new Padding(0,0,20,0),Font=MeterTheme.Font(9.75f)};check.CheckedChanged+=(s,e)=>{list.SetItemChecked(index,check.Checked);refresh();};grid.Controls.Add(check,columns[i],rows[i]);}
        all.Click+=(s,e)=>{foreach(var check in checks)check.Checked=true;};none.Click+=(s,e)=>{foreach(var check in checks)check.Checked=false;};
        list.Visible=false;group.Controls.Add(list);refresh();Locale.Apply(group);return group;
    }
    internal static void Save(string root,Dictionary<string,bool> data){Directory.CreateDirectory(root);var path=Path.Combine(root,"display.json");var temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";try{File.WriteAllText(temp,new JavaScriptSerializer().Serialize(data),new UTF8Encoding(false));if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);}finally{if(File.Exists(temp))File.Delete(temp);}}
    internal static void Edit(string root){using(var form=new Form()){MeterTheme.Style(form,960,640);form.Text="Codex Quota Sidebar";var body=MeterTheme.Body();form.Controls.Add(body);form.Controls.Add(MeterTheme.Header(Locale.T("Sidebar display content"),"Windows "+MeterTheme.Version));var list=List(root);body.Controls.Add(Grouped(list));var footer=MeterTheme.Footer();var save=MeterTheme.Button("saveDisplay",Locale.T("Save"),true);save.Click+=(s,e)=>{try{Save(root,Capture(list));save.Text=Locale.T("Saved");save.Enabled=false;}catch(Exception ex){MeterTheme.Error(ex.Message);}};list.ItemCheck+=(s,e)=>{save.Text=Locale.T("Save");save.Enabled=true;};var cancel=MeterTheme.Button("cancelDisplay",Locale.T("Close"),false);cancel.Click+=(s,e)=>form.Close();footer.Controls.Add(save);footer.Controls.Add(cancel);form.Controls.Add(footer);body.BringToFront();form.ShowDialog();}}
}
