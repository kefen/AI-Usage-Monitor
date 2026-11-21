$ErrorActionPreference='Stop'
$source=$PSScriptRoot
$project=Split-Path $source -Parent
$manifest=Get-Content (Join-Path $source 'manifest.json') -Raw | ConvertFrom-Json
if($manifest.version -notmatch '^0\.5\.\d+$' -or ($manifest.permissions -join ',') -ne 'storage,alarms'){throw 'Unexpected web preview scope'}
$version=$manifest.version
$folder=Join-Path $project "dist/chrome-web-$version"
$extension=Join-Path $folder 'extension'
New-Item -ItemType Directory -Path $extension -Force | Out-Null
$names=@('manifest.json','source.js','content.js','background.js','icon-32.png','icon-128.png','guide.html','guide.js','README.md')
foreach($name in $names){Copy-Item -LiteralPath (Join-Path $source $name) -Destination (Join-Path $extension $name) -Force}
$zip=Join-Path $folder "AI-Quota-Board-Chrome-$version.zip"
Compress-Archive -LiteralPath @($names | ForEach-Object {Join-Path $extension $_}) -DestinationPath $zip -Force
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($zip)
try{
    if($archive.Entries.Count -ne $names.Count){throw 'Unexpected ZIP contents'}
    foreach($entry in $archive.Entries){
        if($entry.FullName -notin $names){throw 'Non-allowlisted package file'}
        $hash=[Security.Cryptography.SHA256]::Create()
        $stream=$entry.Open()
        try{$actual=[BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','').ToLowerInvariant()}finally{$stream.Dispose();$hash.Dispose()}
        $expected=(Get-FileHash -LiteralPath (Join-Path $source $entry.FullName) -Algorithm SHA256).Hash.ToLowerInvariant()
        if($actual -ne $expected){throw "ZIP hash mismatch: $($entry.FullName)"}
    }
}finally{$archive.Dispose()}
$sums=@($zip)+@($names | ForEach-Object {Join-Path $extension $_}) | ForEach-Object {(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($_)}
$sums | Set-Content -LiteralPath (Join-Path $folder 'SHA256SUMS.txt') -Encoding ascii
Write-Host 'PASS: nine allowlisted runtime/documentation files; extracted ZIP hashes match source; no tests, profiles or account data bundled.'
Write-Host "Release ZIP: $zip"
Write-Host "Load unpacked: $extension"
