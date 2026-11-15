param([switch]$Stop)
$ErrorActionPreference='Stop'
if($Stop){Start-Process -FilePath (Join-Path $PSScriptRoot 'CodexMeter.exe') -ArgumentList '--stop' -WindowStyle Hidden}
else{Start-Process -FilePath (Join-Path $PSScriptRoot 'CodexMeter.exe') -WindowStyle Hidden}
