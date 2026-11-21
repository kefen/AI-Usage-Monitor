$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot -Parent
$root = Join-Path $source ('.install-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
function Assert($condition, $message) { if (-not $condition) { throw $message } }
try {
    $dest = Join-Path $root 'app'
    $shortcut = Join-Path $root 'meter.lnk'
    & (Join-Path $source 'Install.ps1') -Destination $dest -ShortcutPath $shortcut
    Assert (Test-Path -LiteralPath (Join-Path $dest 'src\widget.js')) 'Widget was not installed'
    $manifest = Get-Content -LiteralPath (Join-Path $dest 'installation.json') -Raw | ConvertFrom-Json
    Assert ($manifest.id -eq 'local-codex-sidebar-meter') 'Install marker missing'
    Assert ($manifest.files.Count -ge 10) 'Install file list incomplete'
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($shortcut)
    Assert ($link.TargetPath -eq (Join-Path $dest 'CodexMeter.exe')) 'Shortcut must use the native windowless launcher'
    Assert (-not $link.Arguments) 'Native launcher needs no arguments'
    Assert (Test-Path (Join-Path $dest 'runtime\node.exe')) 'Bundled runtime missing'
    Assert (-not (Test-Path (Join-Path $dest '.runtime\membership.json'))) 'Personal data must not be installed'
    Write-Host 'PASS: installed runtime, manifest, hashes and desktop-style shortcut'

    & (Join-Path $source 'Install.ps1') -Destination $dest -ShortcutPath $shortcut
    Write-Host 'PASS: owned install can be updated'
    $link=$shell.CreateShortcut($shortcut);$link.TargetPath=Join-Path $dest 'Start.cmd';$link.Arguments='';$link.Save()
    & (Join-Path $source 'Install.ps1') -Destination $dest -ShortcutPath $shortcut
    $link=$shell.CreateShortcut($shortcut)
    Assert ($link.TargetPath -eq (Join-Path $dest 'CodexMeter.exe')) 'Legacy shortcut was not migrated'
    Write-Host 'PASS: legacy shortcut upgrades to hidden launcher'

    $foreign = Join-Path $root 'foreign'
    New-Item -ItemType Directory -Path $foreign | Out-Null
    Set-Content -LiteralPath (Join-Path $foreign 'keep.txt') -Value 'user content'
    $failed = $false
    try { & (Join-Path $source 'Install.ps1') -Destination $foreign -ShortcutPath (Join-Path $root 'foreign.lnk') } catch { $failed = $true }
    Assert $failed 'Installer accepted a non-owned directory'
    Assert (Test-Path -LiteralPath (Join-Path $foreign 'keep.txt')) 'Installer changed user files'
    Write-Host 'PASS: non-owned directory is not overwritten'

    $otherLink = Join-Path $root 'other.lnk'
    $link = $shell.CreateShortcut($otherLink); $link.TargetPath = $env:ComSpec; $link.Save()
    $failed = $false
    try { & (Join-Path $source 'Install.ps1') -Destination $dest -ShortcutPath $otherLink } catch { $failed = $true }
    Assert $failed 'Installer overwrote another program shortcut'
    Write-Host 'PASS: foreign shortcut is not overwritten'

    $legacy=$shortcut
    $garbled=Join-Path $root ('Codex '+[char]0x951f+[char]0x65a4+'.lnk')
    Copy-Item -LiteralPath $shortcut -Destination $garbled
    $unicodeForeign=Join-Path $root ('Other '+[char]0x951f+'.lnk')
    Copy-Item -LiteralPath $otherLink -Destination $unicodeForeign
    $shortcut=Join-Path $root 'AI Usage Monitor.lnk'
    & (Join-Path $source 'Install.ps1') -Destination $dest -ShortcutPath $shortcut
    Assert (Test-Path -LiteralPath $shortcut) 'English shortcut missing'
    Assert (-not(Test-Path -LiteralPath $legacy)) 'Old shortcut remained'
    Assert (-not(Test-Path -LiteralPath $garbled)) 'Garbled owned duplicate remained'
    Assert (Test-Path -LiteralPath $otherLink) 'Foreign shortcut removed during migration'
    Assert (Test-Path -LiteralPath $unicodeForeign) 'Unicode foreign shortcut removed during migration'
    Assert ((Get-Content (Join-Path $dest 'installation.json') -Raw -Encoding UTF8 | ConvertFrom-Json).shortcut -eq $shortcut) 'Manifest did not record English shortcut'
    Write-Host 'PASS: English name migration removes only verified duplicates'

    Set-Content -LiteralPath (Join-Path $dest 'keep.txt') -Value 'user content'
    Set-Content -LiteralPath (Join-Path $dest 'README.md') -Value 'user modified README'
    & (Join-Path $dest 'Uninstall.ps1')
    Assert (-not (Test-Path -LiteralPath $shortcut)) 'Owned shortcut was not removed'
    Assert (-not (Test-Path -LiteralPath (Join-Path $dest 'Start.cmd'))) 'Owned runtime was not removed'
    Assert (Test-Path -LiteralPath (Join-Path $dest 'keep.txt')) 'Uninstaller removed user content'
    Assert ((Get-Content -LiteralPath (Join-Path $dest 'README.md') -Raw).Trim() -eq 'user modified README') 'Uninstaller removed a modified file'
    Write-Host 'PASS: uninstall removes owned files, preserves user content'
} finally {
    $resolved = [IO.Path]::GetFullPath($root)
    $expected = [IO.Path]::GetFullPath($source).TrimEnd('\') + '\.install-test-'
    if (-not $resolved.StartsWith($expected, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
