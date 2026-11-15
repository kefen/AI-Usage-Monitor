$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    $pins=Get-Content dependency-pins.json -Raw|ConvertFrom-Json
    New-Item -ItemType Directory -Path runtime,build,dist -Force | Out-Null
    if(-not (Test-Path runtime/node.exe)){Invoke-WebRequest -Uri "https://nodejs.org/dist/v$($pins.nodeVersion)/win-x64/node.exe" -OutFile runtime/node.exe -UseBasicParsing}
    if(-not (Test-Path runtime/LICENSE)){Invoke-WebRequest -Uri "https://raw.githubusercontent.com/nodejs/node/v$($pins.nodeVersion)/LICENSE" -OutFile runtime/LICENSE -UseBasicParsing}
    foreach($entry in $pins.files.PSObject.Properties){
        if((Get-FileHash -LiteralPath $entry.Name -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.Value){throw "Dependency checksum mismatch: $($entry.Name)"}
    }
    $signature=Get-AuthenticodeSignature runtime/node.exe
    if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'OpenJS Foundation'){throw 'Node signer validation failed'}
    $csc=Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    & $csc /nologo /out:build\BrandAssets.exe /r:System.Drawing.dll (Join-Path $PWD 'tools\BrandAssets.cs')
    if($LASTEXITCODE -ne 0){throw 'Asset tool compilation failed'}
    & ./build/BrandAssets.exe (Join-Path $PWD 'assets')
    if($LASTEXITCODE -ne 0){throw 'Asset generation failed'}
    Copy-Item assets/cqs-32.png browser/icon-32.png
    Copy-Item assets/cqs-128.png browser/icon-128.png
    & $csc /nologo /target:exe /platform:x64 /optimize+ /out:BrowserHost.exe (Join-Path $PWD 'native\BrowserHost.cs')
    if($LASTEXITCODE -ne 0){throw 'Browser host compilation failed'}
    & ./runtime/node.exe --test test/*.test.mjs
    if($LASTEXITCODE -ne 0){throw 'Tests failed'}
    $csc=Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    & $csc /nologo /target:winexe /platform:x64 /optimize+ /out:CodexMeter.exe /win32icon:assets\cqs.ico /win32manifest:native\app.manifest /resource:assets\cqs-128.png,brand.png /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll (Join-Path $PWD 'native\TrayHost.cs') (Join-Path $PWD 'native\Preferences.cs') (Join-Path $PWD 'native\Theme.cs') (Join-Path $PWD 'native\LaunchWindow.cs') (Join-Path $PWD 'native\DisplayOptions.cs')
    if($LASTEXITCODE -ne 0){throw 'Tray compilation failed'}
    & python build_release.py
    if($LASTEXITCODE -ne 0){throw 'Payload build failed'}
    $version=(Get-Content versions.json -Raw|ConvertFrom-Json).windows
    $out="dist\Codex-Quota-Sidebar-Windows-$version-x64-Setup.exe"
    & $csc /nologo /target:winexe /platform:x64 /optimize+ "/out:$out" /win32icon:assets\cqs.ico /win32manifest:native\app.manifest /resource:assets\cqs-128.png,brand.png /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.IO.Compression.dll /resource:build\payload.zip,payload.zip (Join-Path $PWD 'native\Installer.cs') (Join-Path $PWD 'native\Theme.cs') (Join-Path $PWD 'native\SetupWindow.cs') (Join-Path $PWD 'native\DisplayOptions.cs')
    if($LASTEXITCODE -ne 0){throw 'Installer compilation failed'}
    Get-ChildItem dist -File | Where-Object {$_.Extension -in '.exe','.zip'} | Get-FileHash -Algorithm SHA256 | ForEach-Object {$_.Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($_.Path)} | Set-Content dist/SHA256SUMS.txt -Encoding ascii
    Write-Host "Built: $out (unsigned local candidate; not published)"
} finally {Pop-Location}
