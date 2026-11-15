using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;
internal static class DisplayOptions {
    internal static readonly string[] Keys={"plan","short","week","reset","renewal","daily","average","weekly","lifetime"};
    static readonly string[] Labels={"\u5957\u9910\u6807\u8bc6","5h \u5269\u4f59","\u672c\u5468\u5269\u4f59","\u989d\u5ea6\u91cd\u7f6e\u65e5","\u4f1a\u5458\u7eed\u8d39\u65e5","\u6bcf\u65e5 Token","\u65e5\u5747 Token","\u672c\u5468 Token","\u7d2f\u8ba1 Token"};
    internal static CheckedListBox List(string root){
        var list=new CheckedListBox{Name="displayOptions",CheckOnClick=true,BorderStyle=BorderStyle.None,Dock=DockStyle.Top,Height=200,MultiColumn=true,ColumnWidth=280,IntegralHeight=false};
        Dictionary<string,bool> settings=null;try{settings=new JavaScriptSerializer().Deserialize<Dictionary<string,bool>>(File.ReadAllText(Path.Combine(root,"display.json"),Encoding.UTF8));}catch{}
        for(int i=0;i<Keys.Length;i++)list.Items.Add(Labels[i],settings==null||!settings.ContainsKey(Keys[i])||settings[Keys[i]]);return list;
    }
    internal static Dictionary<string,bool> Capture(CheckedListBox list){var data=new Dictionary<string,bool>();for(int i=0;i<Keys.Length;i++)data[Keys[i]]=list.GetItemChecked(i);return data;}
    internal static void Save(string root,Dictionary<string,bool> data){Directory.CreateDirectory(root);var path=Path.Combine(root,"display.json");var temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";try{File.WriteAllText(temp,new JavaScriptSerializer().Serialize(data),new UTF8Encoding(false));if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);}finally{if(File.Exists(temp))File.Delete(temp);}}
    internal static void Edit(string root){using(var form=new Form()){MeterTheme.Style(form,660,390);form.Text="Codex Quota Sidebar";var body=MeterTheme.Body();form.Controls.Add(body);form.Controls.Add(MeterTheme.Header("\u4fa7\u680f\u663e\u793a\u5185\u5bb9","Windows"));var list=List(root);body.Controls.Add(list);var footer=MeterTheme.Footer();var save=MeterTheme.Button("saveDisplay","\u4fdd\u5b58",true);save.Click+=(s,e)=>{try{Save(root,Capture(list));save.Text="\u5df2\u4fdd\u5b58";save.Enabled=false;}catch(Exception ex){MeterTheme.Error(ex.Message);}};list.ItemCheck+=(s,e)=>{save.Text="\u4fdd\u5b58";save.Enabled=true;};var cancel=MeterTheme.Button("cancelDisplay","\u5173\u95ed",false);cancel.Click+=(s,e)=>form.Close();footer.Controls.Add(save);footer.Controls.Add(cancel);form.Controls.Add(footer);body.BringToFront();form.ShowDialog();}}
}
