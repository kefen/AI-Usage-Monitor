$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public struct CaptureRect { public int X,Y,R,B; }
public class UpgradeNative {
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h,IntPtr dc,uint flags);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out CaptureRect r);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
}
'@
$evidence=New-Item "$PWD/evidence" -ItemType Directory -Force
$root=Join-Path $env:RUNNER_TEMP 'public-upgrade'
$installed=Join-Path $root 'installed'
if(Test-Path $root){throw 'Test directory is not clean'}
New-Item $root -ItemType Directory | Out-Null
$desktop=[Environment]::GetFolderPath('Desktop')
if(!$desktop){throw 'No desktop for the clean runner account'}
New-Item $desktop -ItemType Directory -Force | Out-Null
if(Test-Path (Join-Path $desktop 'AI Usage Monitor.lnk')){throw 'Existing user installation detected'}
if($env:NODE_OPTIONS){throw 'Unexpected NODE_OPTIONS'}
$oldRelease=Invoke-RestMethod 'https://api.github.com/repos/kefen/AI-Usage-Monitor/releases/tags/windows%2Fv0.14.0'
$asset=$oldRelease.assets | Where-Object name -eq 'AI-Usage-Monitor-Windows-0.14.0-x64-Setup.exe'
if(!$asset){throw 'Original public 0.14.0 package missing'}
$setup=Join-Path $root $asset.name
Invoke-WebRequest -UseBasicParsing $asset.browser_download_url -OutFile $setup
$oldHash=(Get-FileHash $setup).Hash.ToLower()
if($asset.digest -and $asset.digest -ne "sha256:$oldHash"){throw 'Old installer checksum mismatch'}
$p=Start-Process $setup -ArgumentList @('--extract',"`"$root/payload`"") -PassThru -Wait
if($p.ExitCode -ne 0){throw 'Extraction failed'}
& "$root/payload/Install.ps1" -Destination $installed
$exe=Join-Path $installed 'CodexMeter.exe'
if((Get-Item $exe).VersionInfo.FileVersion -ne '0.14.0.0'){throw 'Wrong previous version'}
$runtime=New-Item (Join-Path $installed '.runtime') -ItemType Directory -Force
# No Codex account, data, update cache, network overrides, or monitoring fixtures.
[IO.File]::WriteAllText("$runtime/preferences.json",'{"cdpConsent":true,"setupComplete":true}')
[IO.File]::WriteAllText("$runtime/language.json",'"en"')
if(Test-Path "$runtime/updates"){throw 'Update cache must not exist on first launch'}
$ae=[System.Windows.Automation.AutomationElement]
$scope=[System.Windows.Automation.TreeScope]
$all=[System.Windows.Automation.Condition]::TrueCondition
function Nodes($w){$w.FindAll($scope::Descendants,$all)}
function Windows($processId){$p=Get-Process -Id $processId;$p.Refresh();if($p.MainWindowHandle -ne [IntPtr]::Zero){$ae::FromHandle($p.MainWindowHandle)}; $ae::RootElement.FindAll($scope::Children,[System.Windows.Automation.PropertyCondition]::new($ae::ProcessIdProperty,[int]$processId))}
function Wait-Until($fn,$message,$seconds=150){$until=[DateTime]::UtcNow.AddSeconds($seconds);do{try{$v=& $fn;if($v){return $v}}catch [System.Windows.Automation.ElementNotAvailableException]{};Start-Sleep -Milliseconds 200}while([DateTime]::UtcNow -lt $until);throw $message}
function Capture($w,$name){
 $h=[IntPtr]$w.Current.NativeWindowHandle
 $r=New-Object CaptureRect
 if(![UpgradeNative]::GetWindowRect($h,[ref]$r)){throw 'Missing window rectangle'}
 $b=New-Object Drawing.Bitmap ($r.R-$r.X),($r.B-$r.Y)
 $g=[Drawing.Graphics]::FromImage($b)
 try{$dc=$g.GetHdc();try{if(![UpgradeNative]::PrintWindow($h,$dc,0)){throw 'Capture failed'}}finally{$g.ReleaseHdc($dc)};$b.Save("$evidence/$name.png",[Drawing.Imaging.ImageFormat]::Png)}finally{$g.Dispose();$b.Dispose()}
}
function Click($el){
 if(![UpgradeNative]::PostMessage([IntPtr]$el.Current.NativeWindowHandle,0xF5,[IntPtr]::Zero,[IntPtr]::Zero)){throw 'Button click failed'}
}
$old=Start-Process $exe -PassThru
try{
 $window=Wait-Until {foreach($w in (Windows $old.Id)){if($w.Current.Name -eq 'AI Usage Monitor' -and $w.Current.ClassName -ne '#32770'){foreach($b in (Nodes $w)){if(($b.Current.AutomationId -eq 'installUpdate' -or $b.Current.Name -eq 'Update available') -and !$b.Current.IsOffscreen){$script:badge=$b;return $w}}}}} 'Automatic update badge did not appear' 60
 $texts=(Nodes $window)|ForEach-Object {$_.Current.Name}
 if($texts -notcontains 'Windows 0.14.0'){throw 'Old footer not visible'}
 Capture $window '01-old-version-automatic-badge'
 $badgeRect=$badge.Current.BoundingRectangle
 $windowRect=$window.Current.BoundingRectangle
 if($badgeRect.X -lt $windowRect.X+$windowRect.Width/2 -or $badgeRect.Y -gt $windowRect.Y+$windowRect.Height/3){throw 'Badge is not in the upper right'}
 Click $badge
 # The released client downloads and verifies first, then asks permission to restart.
 $dialog=Wait-Until {foreach($w in (Windows $old.Id)){foreach($d in (@($w)+@(Nodes $w))){if($d.Current.ClassName -eq '#32770'){if(((Nodes $d)|ForEach-Object {$_.Current.Name}) -match 'Restart the companion') {return $d}}}}} 'Verified installer confirmation did not appear' 240
 Capture $dialog '02-downloaded-verified-install-confirmation'
 $state=Get-Content "$runtime/updates/state.json" -Raw|ConvertFrom-Json
 if(!$state.ready -or $state.current -ne '0.14.0' -or $state.version -ne '0.14.1'){throw 'Download not verified for intended versions'}
 $latest=Invoke-RestMethod 'https://api.github.com/repos/kefen/AI-Usage-Monitor/releases/tags/windows%2Fv0.14.1'
 $published=$latest.assets|Where-Object name -eq 'AI-Usage-Monitor-Windows-0.14.1-x64-Setup.exe'
 $newHash=(Get-FileHash "$runtime/updates/update.exe").Hash.ToLower()
 if($published.digest -ne "sha256:$newHash"){throw 'Downloaded update differs from official release'}
 $ok=(Nodes $dialog)|Where-Object {$_.Current.AutomationId -eq '1'}|Select-Object -First 1
 if(!$ok){throw 'No install confirmation control'}
 Click $ok
 $next=Wait-Until {Get-Process CodexMeter -ErrorAction SilentlyContinue|Where-Object {$_.Id -ne $old.Id -and $_.Path -eq $exe -and $_.MainModule.FileVersionInfo.FileVersion -eq '0.14.1.0'}|Select-Object -First 1} 'New 0.14.1 process did not restart' 180
 $newWindow=Wait-Until {foreach($w in (Windows $next.Id)){if(((Nodes $w)|ForEach-Object {$_.Current.Name}) -contains 'Windows 0.14.1'){return $w}}} 'New version footer not visible'
 Capture $newWindow '03-restarted-version-0141'
 $transaction=Get-Content "$runtime/updates/transaction.json" -Raw|ConvertFrom-Json
 if($transaction.stage -ne 'installed' -or !$transaction.settingsPreserved){throw 'Install transaction incomplete'}
 $link=(New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desktop 'AI Usage Monitor.lnk'))
 if($link.TargetPath -ne $exe){throw 'Installed shortcut does not target upgraded installation'}
 [ordered]@{passed=$true;source='Original public 0.14.0 Setup.exe and production signed update feed; no mocks';oldVersion='0.14.0';newVersion='0.14.1';oldPid=$old.Id;newPid=$next.Id;oldInstallerSha256=$oldHash;newInstallerSha256=$newHash;automaticUpperRightBadge=$true;downloadedVerified=$true;restartConfirmed=$true;settingsPreserved=$transaction.settingsPreserved;shortcutCorrect=$true;completedAt=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$evidence/result.json" -Encoding UTF8
}finally{
 foreach($p in (Get-Process CodexMeter -ErrorAction SilentlyContinue)){
  foreach($w in (Windows $p.Id)){
   try{Capture $w ('last-window-'+$w.Current.NativeWindowHandle);(Nodes $w)|ForEach-Object {"$($_.Current.Name) | $($_.Current.AutomationId) | $($_.Current.ClassName) | offscreen=$($_.Current.IsOffscreen)"}|Out-File "$evidence/last-window-tree.txt" -Append}catch{Write-Warning $_}
  }
 }
 foreach($name in @('state.json','transaction.json','last-error.json')){if(Test-Path "$runtime/updates/$name"){Copy-Item "$runtime/updates/$name" "$evidence/$name"}}
}
