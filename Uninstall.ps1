$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lifecycle.ps1')
$root = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
$marker = Join-Path $root 'installation.json'
if (-not (Test-Path -LiteralPath $marker)) { throw 'No installation marker. Nothing was removed.' }
foreach ($itemPath in @($root, $marker, (Join-Path $root 'src'), (Join-Path $root 'runtime'), (Join-Path $root 'vendor'), (Join-Path $root 'vendor\codex-quota'))) {
    if ((Test-Path -LiteralPath $itemPath) -and
        ((Get-Item -LiteralPath $itemPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Refusing to uninstall through a symbolic link or junction.'
    }
}
$manifest = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
if ($manifest.id -ne 'local-codex-sidebar-meter') { throw 'Unrecognized installation. Nothing was removed.' }
$allowed = @(Get-Content (Join-Path $root 'runtime-files.json') -Raw | ConvertFrom-Json | ForEach-Object {$_ -replace '/', '\'})
foreach ($file in $manifest.files) {
    if ($file.path -notin $allowed) { throw 'Unexpected manifest path. Nothing was removed.' }
    $path = [IO.Path]::GetFullPath((Join-Path $root $file.path))
    if (-not $path.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe uninstall path.' }
}
$probe=New-Object Threading.Mutex($false,(Get-MeterMutexName $root 'monitor'))
$canRemove=$false
try {
    try {$canRemove=$probe.WaitOne(0)} catch [Threading.AbandonedMutexException] {$canRemove=$true}
    if(-not $canRemove){throw 'Stop the background meter from its tray menu or Stop.cmd before uninstalling.'}
Write-Host 'The meter must be stopped before uninstalling. Codex itself will not be stopped.'
$kept = 0
foreach ($file in $manifest.files) {
    $path = Join-Path $root $file.path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $item = Get-Item -LiteralPath $path -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.sha256) {
        Write-Host "Preserved modified file: $($file.path)"; $kept++; continue
    }
    Remove-Item -LiteralPath $path -Force
}
if ($manifest.shortcut -and [IO.Path]::GetExtension($manifest.shortcut) -eq '.lnk' -and (Test-Path -LiteralPath $manifest.shortcut)) {
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($manifest.shortcut)
    if (Test-OwnedMeterShortcut $link $root) { Remove-Item -LiteralPath $manifest.shortcut -Force }
}
if (-not $kept) { Remove-Item -LiteralPath $marker -Force }
foreach ($dir in @('src','runtime','vendor\codex-quota','vendor')) {
    $path = Join-Path $root $dir
    if ((Test-Path -LiteralPath $path) -and -not @(Get-ChildItem -LiteralPath $path -Force).Count) { Remove-Item -LiteralPath $path }
}
if (-not @(Get-ChildItem -LiteralPath $root -Force).Count) { Remove-Item -LiteralPath $root }
Write-Host 'Installer-owned files removed. Other files were preserved.'
} finally {if($canRemove){$probe.ReleaseMutex()};$probe.Dispose()}
