using System;
using System.IO;
internal static class DiagnosticsTest {
    static int Main(string[] args){
        Directory.CreateDirectory(args[0]);
        File.WriteAllText(Path.Combine(args[0],"status.json"),"{\"stage\":\"mounted\",\"code\":\"secret-account-token\",\"auth\":\"secret-account-token\",\"path\":\"private-user\",\"quotaAvailable\":true}");
        string report=LocalDiagnostics.Snapshot(args[0]);
        if(!report.Contains("background.json"))throw new Exception("Tray status missing from diagnostic scope");
        if(report.Contains("secret-account-token")||report.Contains("private-user")||!report.Contains("mounted")||!report.Contains("quotaAvailable"))throw new Exception("Diagnostics whitelist failed");
        Console.WriteLine("PASS: diagnostic export excludes secrets, paths and unknown fields");return 0;
    }
}
