param([string]$SourcePath=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$workspace=Split-Path $PSScriptRoot -Parent
$root=Join-Path $workspace ('.rollback-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$dest=Join-Path $root 'app';$shortcut=Join-Path $root 'meter.lnk'
$fault=@{Inject=$false;Injected=$false;Target=(Join-Path $dest 'README.md')}
function Copy-Item {
    param([string]$LiteralPath,[string]$Destination,[switch]$Force)
    if($fault.Inject -and -not $fault.Injected -and $Destination -eq $fault.Target){
        $fault.Injected=$true
        [IO.File]::WriteAllText($Destination,'simulated partial copy')
        throw 'Injected copy failure'
    }
    Microsoft.PowerShell.Management\Copy-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force
}
try {
    & (Join-Path $SourcePath 'Install.ps1') -Destination $dest -ShortcutPath $shortcut
    $before=(Get-FileHash (Join-Path $dest 'README.md')).Hash
    $marker=(Get-FileHash (Join-Path $dest 'installation.json')).Hash
    $fault.Inject=$true;$failed=$false
    try {& (Join-Path $SourcePath 'Install.ps1') -Destination $dest -ShortcutPath $shortcut}catch{$failed=$true}
    if(-not $failed -or -not $fault.Injected){throw 'Failure injection did not run'}
    if((Get-FileHash (Join-Path $dest 'README.md')).Hash -ne $before){throw 'Rollback did not restore the partially written file'}
    if((Get-FileHash (Join-Path $dest 'installation.json')).Hash -ne $marker){throw 'Rollback changed the manifest'}
    Write-Host 'PASS: partial-copy failure restores original file and manifest'
} finally {
    $absolute=[IO.Path]::GetFullPath($root)
    if(-not $absolute.StartsWith([IO.Path]::GetFullPath($workspace).TrimEnd('\')+'\.rollback-test-')){throw 'Unsafe cleanup'}
    Remove-Item -LiteralPath $absolute -Recurse -Force
}
