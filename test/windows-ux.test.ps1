param([string[]]$TestNames=@('UsageOverviewTest','UpdateRunnerTest','SetupSupportTest','DiagnosticsTest','SettingsTransferTest','NativeVisualTest','PreferencesTest','NativeDpiTest'))
$ErrorActionPreference='Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $csc=Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    $shared=@('native/Locale.cs','native/UsageOverview.cs','native/Theme.cs','native/DisplayOptions.cs','native/Preferences.cs','native/SettingsTransfer.cs','native/UpdateRunner.cs')
    foreach($test in $TestNames){
        $extra=@(switch($test){
            'SetupSupportTest' {@('native/SetupSupport.cs')}
            'DiagnosticsTest' {@('native/LocalDiagnostics.cs')}
            'NativeVisualTest' {@('native/SetupSupport.cs','native/SetupWindow.cs','native/LaunchWindow.cs','native/LocalDiagnostics.cs')}
            'NativeDpiTest' {@('native/LaunchWindow.cs','native/LocalDiagnostics.cs')}
            default {@()}
        })
        $sources=@($shared+$extra+"test/$test.cs" | ForEach-Object {Join-Path $PWD ($_ -replace '/', '\')})
        & $csc /nologo /win32manifest:native\app.manifest "/out:build\$test.exe" /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:Microsoft.CSharp.dll /resource:assets\cqs-128.png,brand.png /resource:ui\strings.json,strings.json @sources
        if($LASTEXITCODE -ne 0){throw "$test compile failed"}
        $fixture=if($test -eq 'SetupSupportTest'){Join-Path $PWD 'build\s'}else{Join-Path $PWD "verification\v3-windows\$test"}
        $stdout=Join-Path $PWD "build\$test.stdout.txt"
        $stderr=Join-Path $PWD "build\$test.stderr.txt"
        $process=Start-Process -FilePath (Join-Path $PWD "build\$test.exe") -ArgumentList ('"'+$fixture+'"') -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        if(-not $process.WaitForExit(30000)){$process.Kill();throw "$test timed out"}
        Get-Content -LiteralPath $stdout
        Get-Content -LiteralPath $stderr
        if($process.ExitCode -ne 0){throw "$test failed"}
    }
} finally {Pop-Location}
