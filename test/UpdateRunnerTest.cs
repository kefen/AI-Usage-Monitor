using System;
using System.Diagnostics;
using System.IO;
using System.Text;
internal static class UpdateRunnerTest {
    static void Assert(bool ok,string message){if(!ok)throw new Exception(message);}
    static UpdateResult Child(string operation,int timeout){return UpdateRunner.Execute(new ProcessStartInfo(typeof(UpdateRunnerTest).Assembly.Location,"--child "+operation),timeout);}
    static int Main(string[] args){
        if(args.Length>0&&args[0].EndsWith("update.mjs",StringComparison.OrdinalIgnoreCase)){
            if(args.Length!=5||args[1]!="check"||args[2]!=args[3]){Console.WriteLine("{\"error\":\"E_TEST_ARGUMENTS\"}");return 1;}
            Console.WriteLine("{\"available\":false,\"current\":\"0.13.1\",\"version\":\"0.13.1\"}");return 0;
        }
        if(args.Length==2&&args[0]=="--child"){
            Console.OutputEncoding=new UTF8Encoding(false);
            switch(args[1]){
                case "success":Console.WriteLine("{\"available\":false,\"current\":\"0.13.0\",\"version\":\"0.13.0\",\"notes\":\"\u5df2\u662f\u6700\u65b0\u7248\u672c\"}");return 0;
                case "error":Console.Error.WriteLine("Private path and diagnostic detail");Console.WriteLine("{\"error\":\"private network details\",\"code\":\"E_UPDATE_NETWORK\"}");return 1;
                case "junk":Console.WriteLine("noise\n{\"available\":false}");return 0;
                case "large":Console.WriteLine(new string('x',140000));return 0;
                case "timeout":System.Threading.Thread.Sleep(2000);return 0;
            }
        }
        var latest=Child("success",5000);Assert(latest.Success&&!(bool)latest.Data["available"],"Valid latest subprocess result rejected");Assert((string)latest.Data["notes"]=="\u5df2\u662f\u6700\u65b0\u7248\u672c","UTF8 notes corrupted");
        Assert(Child("error",5000).Code=="E_UPDATE_NETWORK","Typed process failure lost");
        foreach(string code in new[]{"E_UPDATE_NETWORK","E_UPDATE_SIGNATURE","E_UPDATE_CHECKSUM","E_UPDATE_CONFIGURATION","E_UPDATE_METADATA"})Assert(UpdateRunner.Parse("{\"error\":\""+code+"\"}",1).Code==code,"Exit 1 JSON code lost: "+code);
        string fixture=Path.Combine(args[0],"app root");Directory.CreateDirectory(Path.Combine(fixture,"runtime"));Directory.CreateDirectory(Path.Combine(fixture,"src"));File.WriteAllText(Path.Combine(fixture,"runtime","node.exe"),"");File.WriteAllText(Path.Combine(fixture,"src","update.mjs"),"");
        Assert(UpdateRunner.AppRoot(Path.Combine(fixture,"runtime"))==fixture,"Runtime subdirectory root resolution failed");
        File.Copy(typeof(UpdateRunnerTest).Assembly.Location,Path.Combine(fixture,"runtime","node.exe"),true);
        var trailing=UpdateRunner.Run(fixture+Path.DirectorySeparatorChar,"check");
        Assert(trailing.Success,"Actual AppDomain trailing-slash root corrupted child arguments: "+trailing.Code);
        Assert(Child("junk",5000).Code=="E_UPDATE_JSON","Junk stdout accepted");
        Assert(Child("large",5000).Code=="E_UPDATE_OUTPUT_LIMIT","Output unbounded");
        Assert(Child("timeout",100).Code=="E_UPDATE_TIMEOUT","Timeout lost");
        Assert(!UpdateRunner.Parse("{\"available\":false}",0).Success,"Missing current/version reported latest");
        Assert(!UpdateRunner.Parse("{\"available\":false,\"current\":\"1\",\"version\":\"1\"}{}",0).Success,"Multiple JSON records accepted");
        Assert(UpdateRunner.SafeCode("C:\\secret","E_UPDATE_PROCESS")=="E_UPDATE_PROCESS","Private error exposed");
        Console.WriteLine("PASS: fresh subprocess UTF8 latest, typed errors, exact JSON, bounded output, timeout");return 0;
    }
}
