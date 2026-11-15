function Initialize-MeterRestartDialog {
    Add-Type -AssemblyName System.Windows.Forms
    # Windows PowerShell 5.1 Add-Type -Path rejects EXE files, even managed assemblies.
    $assembly=[Reflection.Assembly]::LoadFrom((Join-Path $PSScriptRoot 'CodexMeter.exe'))
    $null=$assembly.GetType('MeterRestartDialog',$true)
}

function Get-ApprovedMeterStopId($Expected, $Actual, [bool]$Confirmed) {
    if (-not $Confirmed -or $null -eq $Expected -or $null -eq $Actual) { return $null }
    if ([int]$Expected.pid -le 0 -or [int]$Expected.pid -ne [int]$Actual.Id) { return $null }
    if ([string]::IsNullOrWhiteSpace([string]$Actual.Path) -or
        -not [string]::Equals([string]$Expected.executablePath, [string]$Actual.Path, [StringComparison]::OrdinalIgnoreCase)) { return $null }
    if ([string]::IsNullOrWhiteSpace([string]$Expected.startedAt) -or $Expected.startedAt -cne $Actual.StartedAt) { return $null }
    return [int]$Actual.Id
}
