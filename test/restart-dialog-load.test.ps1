$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'RestartSafety.ps1')
Initialize-MeterRestartDialog
$type=[MeterRestartDialog]
if($type.FullName -ne 'MeterRestartDialog' -or -not $type.GetMethod('Confirm').IsPublic){throw 'Restart dialog entry point unavailable'}
Write-Host ('PASS: restart dialog EXE assembly loads on Windows PowerShell '+$PSVersionTable.PSVersion)
