param([string]$Destination, [string]$ShortcutPath)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lifecycle.ps1')
$source = [IO.Path]::GetFullPath($PSScriptRoot)
if (-not $Destination) { $Destination = Join-Path $env:USERPROFILE 'Documents\Codex\Apps\CodexSidebarMeter' }
if (-not $ShortcutPath) {
    $name = 'Codex Quota Sidebar.lnk'
    $ShortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) $name
    $prior=Join-Path $Destination 'installation.json'
    if(Test-Path -LiteralPath $prior){
        $record=Get-Content -LiteralPath $prior -Raw | ConvertFrom-Json
        if($record.id -eq 'local-codex-sidebar-meter' -and $record.shortcut){$ShortcutPath=$record.shortcut}
    }
}
$Destination = [IO.Path]::GetFullPath($Destination).TrimEnd('\')
$ShortcutPath = [IO.Path]::GetFullPath($ShortcutPath)
$probe=New-Object Threading.Mutex($false,(Get-MeterMutexName $Destination 'monitor'))
$canInstall=$false
try {
    try {$canInstall=$probe.WaitOne(0)} catch [Threading.AbandonedMutexException] {$canInstall=$true}
    if(-not $canInstall){throw 'Stop the existing meter before upgrading. Leave Codex open.'}
if ($source -eq $Destination -or $source.StartsWith($Destination + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The install directory cannot contain the source directory.'
}
if ([IO.Path]::GetExtension($ShortcutPath) -ne '.lnk') { throw 'ShortcutPath must end in .lnk.' }
for ($path = $Destination; $path; $path = Split-Path $path -Parent) {
    if (Test-Path -LiteralPath $path) {
        if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw 'Installation through a junction or symbolic link is not supported.'
        }
    }
}
$marker = Join-Path $Destination 'installation.json'
foreach ($itemPath in @($marker, (Join-Path $Destination 'browser'), (Join-Path $Destination 'assets'), (Join-Path $Destination 'src'), (Join-Path $Destination 'runtime'), (Join-Path $Destination 'vendor'), (Join-Path $Destination 'vendor\codex-quota'), $ShortcutPath)) {
    if ((Test-Path -LiteralPath $itemPath) -and
        ((Get-Item -LiteralPath $itemPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'An installation path is a symbolic link or junction.'
    }
}
$old = $null
if (Test-Path -LiteralPath $Destination) {
    if (-not (Test-Path -LiteralPath $marker)) {
        if (@(Get-ChildItem -LiteralPath $Destination -Force).Count) { throw 'Refusing to overwrite a directory not owned by this installer.' }
    } else {
        $old = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
        if ($old.id -ne 'local-codex-sidebar-meter') { throw 'Unrecognized install marker.' }
        if ($old.shortcut -ne $ShortcutPath) { throw 'Use the shortcut location recorded by the existing installation.' }
    }
}
$shell = New-Object -ComObject WScript.Shell
$target = Join-Path $Destination 'CodexMeter.exe'
$shortcutArguments = ''
$updateShortcut=$true
if (Test-Path -LiteralPath $ShortcutPath) {
    $existing = $shell.CreateShortcut($ShortcutPath)
    if (-not (Test-OwnedMeterShortcut $existing $Destination)) { throw 'Refusing to overwrite another application shortcut.' }
    $updateShortcut=$existing.TargetPath -ne $target -or $existing.Arguments -ne $shortcutArguments
}
$names = @(Get-Content (Join-Path $source 'runtime-files.json') -Raw | ConvertFrom-Json | ForEach-Object {$_ -replace '/', '\'})
foreach($name in $names){if($name -match '(^[\\/]|:|(^|[\\/])\.\.([\\/]|$))'){throw 'Unsafe runtime manifest path.'}}
$files = @()
foreach ($name in $names) {
    $from = Join-Path $source $name
    if (-not (Test-Path -LiteralPath $from -PathType Leaf)) { throw "Missing source file: $name" }
    $to = Join-Path $Destination $name
    if (Test-Path -LiteralPath $to) {
        if ((Get-Item -LiteralPath $to -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing symbolic link: $name" }
        $owned = @($old.files | Where-Object { $_.path -eq $name })
        if ($owned.Count -ne 1 -or (Get-FileHash -LiteralPath $to -Algorithm SHA256).Hash -ne $owned[0].sha256) {
            throw "An existing file was modified or is not installer-owned: $name"
        }
    }
    $files += [pscustomobject]@{path=$name;sha256=(Get-FileHash -LiteralPath $from -Algorithm SHA256).Hash}
}
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$backup=Join-Path $Destination ('.install-backup-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $backup | Out-Null
$originalMarker=if(Test-Path -LiteralPath $marker){[IO.File]::ReadAllBytes($marker)}else{$null}
$originalShortcut=if(Test-Path -LiteralPath $ShortcutPath){[IO.File]::ReadAllBytes($ShortcutPath)}else{$null}
$changed=@();$cleanupBackup=$false
try {
foreach ($file in $files) {
    $to = Join-Path $Destination $file.path
    New-Item -ItemType Directory -Path (Split-Path $to -Parent) -Force | Out-Null
    if(Test-Path -LiteralPath $to){
        $saved=Join-Path $backup $file.path
        New-Item -ItemType Directory -Path (Split-Path $saved -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $to -Destination $saved
    }
    $changed+= $file.path
    Copy-Item -LiteralPath (Join-Path $source $file.path) -Destination $to -Force
    if ((Get-FileHash -LiteralPath $to -Algorithm SHA256).Hash -ne $file.sha256) { throw "Installed file failed verification: $($file.path)" }
}
if ($updateShortcut) {
    $link = $shell.CreateShortcut($ShortcutPath)
    $link.TargetPath = $target
    $link.Arguments = $shortcutArguments
    $link.WorkingDirectory = $Destination
    $link.Description = 'Start Codex with background quota meter; tray menu stops the meter'
    $link.WindowStyle = 1
    $link.Save()
}
$manifest = [ordered]@{
    id='local-codex-sidebar-meter';version=(Get-Content -LiteralPath (Join-Path $source 'package.json') -Raw|ConvertFrom-Json).version;installedAt=[DateTime]::UtcNow.ToString('o');
    shortcut=$ShortcutPath;files=$files
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $marker -Encoding UTF8
$cleanupBackup=$true
} catch {
    $failure=$_
    foreach($name in $changed){
        $saved=Join-Path $backup $name;$targetFile=Join-Path $Destination $name
        if(Test-Path -LiteralPath $saved){Copy-Item -LiteralPath $saved -Destination $targetFile -Force}
        elseif(Test-Path -LiteralPath $targetFile){Remove-Item -LiteralPath $targetFile -Force}
    }
    if($null -ne $originalMarker){[IO.File]::WriteAllBytes($marker,$originalMarker)}elseif(Test-Path -LiteralPath $marker){Remove-Item -LiteralPath $marker}
    if($null -ne $originalShortcut){[IO.File]::WriteAllBytes($ShortcutPath,$originalShortcut)}elseif(Test-Path -LiteralPath $ShortcutPath){Remove-Item -LiteralPath $ShortcutPath}
    $cleanupBackup=$true
    throw $failure
} finally {
    $resolvedBackup=[IO.Path]::GetFullPath($backup)
    if($cleanupBackup -and $resolvedBackup.StartsWith($Destination+'\.install-backup-',[StringComparison]::OrdinalIgnoreCase)){
        Remove-Item -LiteralPath $resolvedBackup -Recurse -Force
    }
}
Write-Host "Installed: $Destination"
Write-Host "Desktop shortcut: $ShortcutPath"
Write-Host 'Files and shortcut only. The running Codex app has not been stopped or modified.'
} finally {if($canInstall){$probe.ReleaseMutex()};$probe.Dispose()}
