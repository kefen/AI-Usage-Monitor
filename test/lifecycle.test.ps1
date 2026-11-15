$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Lifecycle.ps1')
function Assert($value,$message){if(-not $value){throw $message}}
$root='C:\Test\Codex Meter'
Assert ((Get-MeterMutexName $root 'monitor') -eq (Get-MeterMutexName $root.ToLowerInvariant() 'monitor')) 'Case-insensitive path identity must match'
Assert ((Get-MeterMutexName $root 'monitor') -ne (Get-MeterMutexName $root 'tray')) 'Tray and monitor need distinct locks'
$legacy=[pscustomobject]@{TargetPath=(Join-Path $root 'Start.cmd');Arguments=''}
Assert (Test-OwnedMeterShortcut $legacy $root) 'Legacy shortcut must be migratable'
$current=[pscustomobject]@{TargetPath=(Join-Path $env:SystemRoot 'System32\wscript.exe');Arguments=('"'+(Join-Path $root 'Background.vbs')+'"')}
Assert (Test-OwnedMeterShortcut $current $root) 'Owned background shortcut rejected'
$current.Arguments='"C:\Other\script.vbs"'
Assert (-not (Test-OwnedMeterShortcut $current $root)) 'Another wscript shortcut must not qualify'
$native=[pscustomobject]@{TargetPath=(Join-Path $root 'CodexMeter.exe');Arguments=''}
Assert (Test-OwnedMeterShortcut $native $root) 'Native launcher rejected'
$native.Arguments='--stop'
Assert (-not (Test-OwnedMeterShortcut $native $root)) 'Only the exact native launch shortcut is owned'
Write-Host 'PASS: stable mutex names and exact shortcut ownership'
