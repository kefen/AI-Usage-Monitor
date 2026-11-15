$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'RestartSafety.ps1')
function Assert($value, $label) { if (-not $value) { throw $label } }
$expected = [pscustomobject]@{pid=98765;executablePath='C:\Store\OpenAI.Codex\app\ChatGPT.exe';startedAt='2026-11-14T04:00:00.0000000Z'}
$actual = [pscustomobject]@{Id=98765;Path=$expected.executablePath;StartedAt=$expected.startedAt}
Assert ($null -eq (Get-ApprovedMeterStopId $expected $actual $false)) 'Unconfirmed restart must not stop anything'
Assert ((Get-ApprovedMeterStopId $expected $actual $true) -eq 98765) 'Exact verified process should qualify after consent'
foreach ($field in @('Id','Path','StartedAt')) {
    $changed = [pscustomobject]@{Id=$actual.Id;Path=$actual.Path;StartedAt=$actual.StartedAt}
    if ($field -eq 'Id') { $changed.Id = 12345 }
    elseif ($field -eq 'Path') { $changed.Path = 'C:\OtherApp\ChatGPT.exe' }
    else { $changed.StartedAt = '2026-11-14T05:00:00.0000000Z' }
    Assert ($null -eq (Get-ApprovedMeterStopId $expected $changed $true)) "Unsafe identity accepted: $field"
}
Assert ($null -eq (Get-ApprovedMeterStopId $expected $null $true)) 'Missing process must not qualify'
Write-Host 'PASS: consent, exact path/PID, PID reuse and missing-process restart guards'
