using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;
internal static class Locale {
    internal const string Repository="https://github.com/kefen/codex-quota-sidebar";
    static readonly Dictionary<string,string[]> Catalog=ReadCatalog();
    internal static string Language=SystemLanguage();
    static string root;
    static bool applying;
    static int depth;
    internal static bool IsTranslating {get{return applying||depth>0;}}
    static readonly HashSet<Control> watched=new HashSet<Control>();
    static Dictionary<string,string[]> ReadCatalog(){using(var stream=typeof(Locale).Assembly.GetManifestResourceStream("strings.json")){if(stream==null)throw new InvalidDataException("Missing UI language catalog");using(var reader=new StreamReader(stream))return new JavaScriptSerializer().Deserialize<Dictionary<string,string[]>>(reader.ReadToEnd());}}
    static string SystemLanguage(){string id=CultureInfo.CurrentUICulture.Name;return id.StartsWith("zh",StringComparison.OrdinalIgnoreCase)?(id.Contains("TW")||id.Contains("HK")||id.Contains("Hant")?"zh-TW":"zh-CN"):"en";}
    internal static void Load(string runtime){root=runtime;try{string value=File.ReadAllText(Path.Combine(root,"language.json")).Trim().Trim('"');if(new[]{"en","zh-CN","zh-TW"}.Contains(value))Language=value;}catch{}}
    internal static void Save(string runtime){Directory.CreateDirectory(runtime);File.WriteAllText(Path.Combine(runtime,"language.json"),"\""+Language+"\"",new UTF8Encoding(false));root=runtime;}
    internal static void Set(string value){if(applying||!new[]{"en","zh-CN","zh-TW"}.Contains(value))return;Language=value;if(root!=null&&Directory.Exists(root))Save(root);applying=true;try{foreach(Form f in Application.OpenForms)Apply(f);}finally{applying=false;}}
    internal static string T(string text){
        if(String.IsNullOrEmpty(text))return text;
        if(text.Trim()!=text)return text.Substring(0,text.Length-text.TrimStart().Length)+T(text.Trim())+text.Substring(text.TrimEnd().Length);
        string key=text;string[] values;
        if(!Catalog.TryGetValue(key,out values)){
            // These overview labels share translations with legacy catalog aliases.
            foreach(string preferred in new[]{"Credits","Quota remaining"}){
                string[] aliases;if(Catalog.TryGetValue(preferred,out aliases)&&aliases.Contains(text)){key=preferred;values=aliases;break;}
            }
            if(values==null)foreach(var pair in Catalog)if(pair.Value.Contains(text)){key=pair.Key;values=pair.Value;break;}
        }
        if(values!=null)return Language=="en"?key:values[Language=="zh-TW"?1:0];
        if(text.Contains(" / "))return String.Join(" / ",text.Split(new[]{" / "},StringSplitOptions.None).Select(T));
        if(text.Contains("\n"))return String.Join("\n",text.Split('\n').Select(T));
        foreach(string label in new[]{"Remaining","Used"})foreach(string prefix in Translations(label))if(text.StartsWith(prefix+" ",StringComparison.Ordinal)){
            string number=text.Substring(prefix.Length+1);
            if(System.Text.RegularExpressions.Regex.IsMatch(number,@"^\d+(\.\d+)?%$"))return T(label)+" "+number;
        }
        return text;
    }
    internal static IEnumerable<string> Translations(string key){yield return key;string[] values;if(Catalog.TryGetValue(key,out values))foreach(string value in values)yield return value;}
    internal static void Apply(Control control){
        depth++;try{
        if(control is DateTimePicker)return;
        if(control.Name=="selectionCount"){control.Text=T("Selected")+" "+Convert.ToString(control.Tag)+" / 11";return;}
        if(control.Name=="language"){((ComboBox)control).SelectedIndex=Language=="en"?0:Language=="zh-CN"?1:2;return;}
        var box=control as TextBox;
        if(!(control is ComboBox)&&(box==null||box.ReadOnly))control.Text=T(control.Text);
        var list=control as CheckedListBox;if(list!=null)for(int i=0;i<list.Items.Count;i++)list.Items[i]=T(Convert.ToString(list.Items[i]));
        var combo=control as ComboBox;if(combo!=null){int selected=combo.SelectedIndex;for(int i=0;i<combo.Items.Count;i++){string old=Convert.ToString(combo.Items[i]),next=T(old);if(old!=next)combo.Items[i]=next;}combo.SelectedIndex=selected;}
        foreach(Control child in control.Controls)Apply(child);
        if(watched.Add(control)){
            if(box==null||box.ReadOnly)control.TextChanged+=(s,e)=>{string translated=T(control.Text);if(control.Text!=translated)control.Text=translated;};
            control.ControlAdded+=(s,e)=>Apply(e.Control);
            control.Disposed+=(s,e)=>watched.Remove(control);
        }
        }finally{depth--;}
    }
    internal static ComboBox Picker(){var box=new ComboBox{Name="language",DropDownStyle=ComboBoxStyle.DropDownList,Width=126};box.Items.AddRange(new object[]{"English","\u7b80\u4f53\u4e2d\u6587","\u7e41\u9ad4\u4e2d\u6587"});box.SelectedIndex=Language=="en"?0:Language=="zh-CN"?1:2;box.SelectedIndexChanged+=(s,e)=>Set(new[]{"en","zh-CN","zh-TW"}[box.SelectedIndex]);return box;}
}
