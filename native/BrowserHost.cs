using System;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
internal static class BrowserHost {
    static int Main(string[] args){
        if(args.Length<1||!Regex.IsMatch(args[0],"^chrome-extension://[a-p]{32}/$"))return 1;
        string root=AppDomain.CurrentDomain.BaseDirectory;
        var info=new ProcessStartInfo(Path.Combine(root,"runtime","node.exe"),"\""+Path.Combine(root,"browser","native-host.mjs")+"\" "+args[0]){UseShellExecute=false,CreateNoWindow=true,RedirectStandardInput=true,RedirectStandardOutput=true,RedirectStandardError=true};
        using(var child=Process.Start(info)){
            var input=Console.OpenStandardInput();var output=Console.OpenStandardOutput();
            Task.Run(()=>{try{input.CopyTo(child.StandardInput.BaseStream);}catch{}finally{try{child.StandardInput.Close();}catch{}}});
            var copy=child.StandardOutput.BaseStream.CopyToAsync(output);var errors=child.StandardError.ReadToEndAsync();
            if(!child.WaitForExit(10000)){child.Kill();child.WaitForExit();return 1;}copy.Wait();output.Flush();return child.ExitCode;
        }
    }
}
