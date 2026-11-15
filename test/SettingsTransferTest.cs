using System;
using System.IO;
internal static class SettingsTransferTest {
    static int Main(string[] args){
        Directory.CreateDirectory(args[0]);
        string member="{\"enabled\":true,\"plan\":\"plus\",\"purchaseDate\":\"2026-01-31\",\"monthlyEstimate\":true}";
        File.WriteAllText(Path.Combine(args[0],"membership.json"),member);
        string backup=SettingsTransfer.Backup(args[0]);
        if(!backup.Contains("2026-01-31")||backup.Contains("cdpConsent"))throw new Exception("Backup scope invalid");
        SettingsTransfer.Restore(args[0],backup);
        foreach(string bad in new[]{"{}",backup.Replace("2026-01-31","not-a-date"),backup.Replace("plus","unknown-secret")}){
            string before=File.ReadAllText(Path.Combine(args[0],"membership.json"));bool rejected=false;
            try{SettingsTransfer.Restore(args[0],bad);}catch{rejected=true;}
            if(!rejected||File.ReadAllText(Path.Combine(args[0],"membership.json"))!=before)throw new Exception("Invalid backup mutated settings");
        }
        Console.WriteLine("PASS: settings round trip, malformed and unknown fields rejected before writes");return 0;
    }
}
