$ErrorActionPreference = 'Stop'
$version = (Get-Content demo8/package.json -Raw | ConvertFrom-Json).version
$stage = (Resolve-Path "demo8/build/windows-$version-stage").Path
$build = New-Item -Force -ItemType Directory "demo8/build/windows-$version-compact"
$installer = Join-Path $PWD "AI-Usage-Monitor-$version-Windows-x64-Setup.exe"
$icon = (Resolve-Path demo8/assets/Monitor.ico).Path
$source = (Resolve-Path tools/WinDemo8Setup.cs).Path
Push-Location $build.FullName
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $raw = Join-Path $PWD 'payload.zip'
    if (Test-Path $raw) { Remove-Item -LiteralPath $raw }
    [IO.Compression.ZipFile]::CreateFromDirectory($stage, $raw, [IO.Compression.CompressionLevel]::NoCompression, $false)
    @('.OPTION EXPLICIT','.Set Cabinet=ON','.Set Compress=ON','.Set CompressionType=LZX',
      '.Set CompressionMemory=21','.Set MaxDiskSize=0','.Set FolderSizeThreshold=0',
      '.Set CabinetNameTemplate=payload.cab','.Set DiskDirectoryTemplate=.','payload.zip') | Set-Content -Encoding ascii pack.ddf
    & "$env:SystemRoot/System32/makecab.exe" /V0 /F pack.ddf
    if ($LASTEXITCODE) { throw "makecab: $LASTEXITCODE" }
    & "$env:SystemRoot/Microsoft.NET/Framework64/v4.0.30319/csc.exe" /nologo /target:winexe /platform:x64 "/win32icon:$icon" "/out:$installer" /resource:payload.cab,payload.cab /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll /reference:System.Windows.Forms.dll $source
    if ($LASTEXITCODE) { throw "csc: $LASTEXITCODE" }
} finally { Pop-Location }
