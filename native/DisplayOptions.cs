using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;
internal static class DisplayOptions {
    internal static readonly string[] Keys={"plan","short","week","reset","renewal","daily","average","weekly","lifetime"};
    static readonly string[] Labels={Locale.T("Plan badge"),Locale.T("5h remaining"),Locale.T("Weekly remaining"),Locale.T("Quota reset"),Locale.T("Renewal date"),Locale.T("Daily tokens"),Locale.T("Daily average"),Locale.T("Weekly tokens"),Locale.T("Lifetime tokens")};
    internal static CheckedListBox List(string root){
        var list=new CheckedListBox{Name="displayOptions",CheckOnClick=true,BorderStyle=BorderStyle.None,Dock=DockStyle.Top,Height=200,MultiColumn=true,ColumnWidth=280,IntegralHeight=false};
        Dictionary<string,bool> settings=null;try{settings=new JavaScriptSerializer().Deserialize<Dictionary<string,bool>>(File.ReadAllText(Path.Combine(root,"display.json"),Encoding.UTF8));}catch{}
        for(int i=0;i<Keys.Length;i++)list.Items.Add(Labels[i],settings==null||!settings.ContainsKey(Keys[i])||settings[Keys[i]]);return list;
    }
    internal static Dictionary<string,bool> Capture(CheckedListBox list){var data=new Dictionary<string,bool>();for(int i=0;i<Keys.Length;i++)data[Keys[i]]=list.GetItemChecked(i);return data;}
    internal static Control Grouped(CheckedListBox list){
        var grid=new TableLayoutPanel{Dock=DockStyle.Top,Height=342,ColumnCount=2,RowCount=8};
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));grid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,50));
        for(int i=0;i<8;i++)grid.RowStyles.Add(new RowStyle(SizeType.Absolute,40));
        grid.Controls.Add(MeterTheme.Label("Remaining quota",10,MeterTheme.Muted),0,0);
        grid.Controls.Add(MeterTheme.Label("Token usage",10,MeterTheme.Muted),1,0);
        grid.Controls.Add(MeterTheme.Label("Existing subscription",10,MeterTheme.Muted),0,4);
        var names=new[]{"Plan badge","5-hour remaining","Weekly remaining","Quota reset","Codex renewal date","Daily tokens","Daily average","Weekly tokens","Lifetime tokens"};
        int[] columns={0,0,0,0,0,1,1,1,1},rows={5,1,2,3,6,1,2,3,4};
        for(int i=0;i<Keys.Length;i++){int index=i;var check=new CheckBox{Text=names[i],Checked=list.GetItemChecked(i),Dock=DockStyle.Fill,AutoSize=false,Margin=new Padding(0,4,16,4)};check.CheckedChanged+=(s,e)=>list.SetItemChecked(index,check.Checked);grid.Controls.Add(check,columns[i],rows[i]);}
        list.Visible=false;grid.Controls.Add(list,1,7);Locale.Apply(grid);return grid;
    }
    internal static void Save(string root,Dictionary<string,bool> data){Directory.CreateDirectory(root);var path=Path.Combine(root,"display.json");var temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";try{File.WriteAllText(temp,new JavaScriptSerializer().Serialize(data),new UTF8Encoding(false));if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);}finally{if(File.Exists(temp))File.Delete(temp);}}
    internal static void Edit(string root){using(var form=new Form()){MeterTheme.Style(form,900,590);form.Text="Codex Quota Sidebar";var body=MeterTheme.Body();form.Controls.Add(body);form.Controls.Add(MeterTheme.Header(Locale.T("Sidebar display content"),"Windows 0.11.0-beta.1"));var list=List(root);body.Controls.Add(Grouped(list));var footer=MeterTheme.Footer();var save=MeterTheme.Button("saveDisplay",Locale.T("Save"),true);save.Click+=(s,e)=>{try{Save(root,Capture(list));save.Text=Locale.T("Saved");save.Enabled=false;}catch(Exception ex){MeterTheme.Error(ex.Message);}};list.ItemCheck+=(s,e)=>{save.Text=Locale.T("Save");save.Enabled=true;};var cancel=MeterTheme.Button("cancelDisplay",Locale.T("Close"),false);cancel.Click+=(s,e)=>form.Close();footer.Controls.Add(save);footer.Controls.Add(cancel);form.Controls.Add(footer);body.BringToFront();form.ShowDialog();}}
}
