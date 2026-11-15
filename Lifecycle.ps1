function Get-MeterMutexName([string]$Root, [string]$Kind) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($Root).ToUpperInvariant())
        $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
        return "Local\CodexMeter-$Kind-$hash"
    } finally { $sha.Dispose() }
}

function Test-OwnedMeterShortcut($Link, [string]$Root) {
    $legacy = $Link.TargetPath -eq (Join-Path $Root 'Start.cmd') -and -not $Link.Arguments
    $background = $Link.TargetPath -eq (Join-Path $env:SystemRoot 'System32\wscript.exe') -and
        $Link.Arguments -eq ('"' + (Join-Path $Root 'Background.vbs') + '"')
    $native = $Link.TargetPath -eq (Join-Path $Root 'CodexMeter.exe') -and -not $Link.Arguments
    return $legacy -or $background -or $native
}
