param([switch]$InspectOnly, [switch]$AfterRestart, [string]$StopFile, [switch]$PrepareOnly, [string]$LaunchToken)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Lifecycle.ps1')
$monitorMutex=$null; $ownsMonitor=$false
$runtime = Join-Path $PSScriptRoot '.runtime'
New-Item -ItemType Directory -Path $runtime -Force | Out-Null
$statusPath = Join-Path $runtime 'status.json'
$script:selectedPort=0
$script:startupPhase='initializing'
$script:elevated=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($InspectOnly) { $statusPath = Join-Path $runtime 'inspection.json' }
function Write-StartupStatus([string]$stage, [string]$code = '', [int]$port = 0) {
    if($stage -ne 'startup-failed'){$script:startupPhase=$stage}
    if($port -gt 0){$script:selectedPort=$port}
    [ordered]@{version='0.9.3-beta.1';stage=$stage;code=$code;port=$script:selectedPort;phase=$script:startupPhase;elevated=$script:elevated;updatedAt=[DateTime]::UtcNow.ToString('o')} |
        ConvertTo-Json | Set-Content -LiteralPath $statusPath -Encoding UTF8
}
function Invoke-NativeHelper([string]$action, [int]$port = 1) {
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $helper = Join-Path $PSScriptRoot 'vendor\codex-quota\codex-cdp.ps1'
    $output = & $ps -NoProfile -ExecutionPolicy Bypass -File $helper -Action $action -Port $port
    $value = ($output -join "`n") | ConvertFrom-Json
    if (-not $value.ok) {
        $script:lastHelperCode = $value.error.code
        throw "Native launcher: $($value.error.code). $($value.error.message)"
    }
    return $value
}
$script:lastHelperCode = 'E_STARTUP'
try {
    if(-not $InspectOnly){
        $preferences=Join-Path $runtime 'preferences.json'
        if(-not (Test-Path -LiteralPath $preferences) -or (Get-Content -LiteralPath $preferences -Raw|ConvertFrom-Json).cdpConsent -ne $true){throw 'Open CodexMeter.exe and accept the local-debugging notice first.'}
    }
    if(-not $InspectOnly -and -not $PrepareOnly) {
        $monitorMutex=New-Object Threading.Mutex($false,(Get-MeterMutexName $PSScriptRoot 'monitor'))
        try { $ownsMonitor=$monitorMutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $ownsMonitor=$true }
        if(-not $ownsMonitor) { Write-Host 'A meter is already running for this installation.'; return }
    }
    Write-StartupStatus 'checking'
    $node = Join-Path $PSScriptRoot 'runtime\node.exe'
    if(-not (Test-Path -LiteralPath $node)){$node=(Get-Command node.exe -ErrorAction Stop).Source}
    if ([int]((& $node --version).TrimStart('v').Split('.')[0]) -lt 22) { throw 'Node.js 22+ is required.' }
    $inspection = Invoke-NativeHelper 'inspect'
    if ($InspectOnly) {
        Write-StartupStatus 'inspected'
        Write-Host "Registered Store app: $($inspection.package.version)"
        Write-Host "Running: $($inspection.running)"
        return
    }
    $port = 0
    if ($inspection.running) {
        $ports = @()
        foreach ($process in $inspection.processes) {
            $info = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $process.pid) -ErrorAction SilentlyContinue
            if ($info -and $info.CommandLine -match '--remote-debugging-port[= ](\d+)') { $ports += [int]$Matches[1] }
        }
        $ports = @($ports | Sort-Object -Unique)
        if ($ports.Count -ne 1) {
            $script:lastHelperCode = 'E_RUNNING_WITHOUT_CDP'
            if ($AfterRestart) { throw 'Codex is still running without a debug port after restart. No further restart was attempted.' }
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -Path (Join-Path $PSScriptRoot 'CodexMeter.exe')
            $question = '"\u5f53\u524d Codex/ChatGPT \u4ecd\u5728\u540e\u53f0\u8fd0\u884c\uff0c\u6ca1\u6709\u6240\u9700\u8c03\u8bd5\u7aef\u53e3\u3002\u8bf7\u5148\u4fdd\u5b58\u6240\u6709\u5de5\u4f5c\uff0c\u5e76\u505c\u6b62\u6b63\u5728\u8fd0\u884c\u7684\u4efb\u52a1\u3002\n\n\u70b9\u51fb\u201c\u662f\u201d\u5c06\u7ed3\u675f\u8be5\u5e94\u7528\u7684\u6240\u6709\u5df2\u6838\u9a8c\u8fdb\u7a0b\uff0c\u5e76\u91cd\u65b0\u542f\u52a8\u4ee5\u52a0\u8f7d\u4fa7\u680f\u9762\u677f\u3002\u672a\u4fdd\u5b58\u5185\u5bb9\u53ef\u80fd\u4e22\u5931\u3002\n\n\u73b0\u5728\u5b8c\u6574\u91cd\u542f\u5417\uff1f"' | ConvertFrom-Json
            $title = '"\u91cd\u542f Codex \u5e76\u52a0\u8f7d\u989d\u5ea6\u9762\u677f"' | ConvertFrom-Json
            $question = $question.Replace([char]0x201c + [string][char]0x662f + [char]0x201d, [char]0x201c + ([string][char]0x5df2) + [char]0x4fdd + [char]0x5b58 + [char]0xff0c + [char]0x91cd + [char]0x542f + [char]0x201d)
            if (-not [MeterRestartDialog]::Confirm($question)) {
                Write-StartupStatus 'restart-cancelled'
                return
            }
            . (Join-Path $PSScriptRoot 'RestartSafety.ps1')
            Write-StartupStatus 'restarting-after-user-confirmation'
            $fresh = Invoke-NativeHelper 'inspect'
            foreach ($expected in $fresh.processes) {
                $actualProcess = Get-Process -Id $expected.pid -ErrorAction SilentlyContinue
                if (-not $actualProcess) { continue }
                try {
                    $actual = [pscustomobject]@{
                        Id=$actualProcess.Id; Path=$actualProcess.Path;
                        StartedAt=$actualProcess.StartTime.ToUniversalTime().ToString('o')
                    }
                } catch {
                    if (-not (Get-Process -Id $expected.pid -ErrorAction SilentlyContinue)) { continue }
                    throw
                }
                $stopId = Get-ApprovedMeterStopId $expected $actual $true
                if ($null -eq $stopId) {
                    if (-not (Get-Process -Id $expected.pid -ErrorAction SilentlyContinue)) { continue }
                    throw 'A process identity changed. Restart stopped for safety.'
                }
                Stop-Process -Id $stopId -Force -ErrorAction SilentlyContinue
            }
            $exited = $false
            for ($attempt=0; $attempt -lt 10; $attempt++) {
                if (-not (Invoke-NativeHelper 'inspect').running) { $exited=$true; break }
                Start-Sleep -Seconds 1
            }
            if (-not $exited) { throw 'Some verified Codex processes are still running. No new app was launched.' }
            & (Join-Path $PSScriptRoot 'Start.ps1') -AfterRestart -StopFile $StopFile -PrepareOnly:$PrepareOnly -LaunchToken $LaunchToken
            return
        }
        $port = $ports[0]
    } else {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.Start(); $port = $listener.LocalEndpoint.Port; $listener.Stop()
    }
    Write-StartupStatus 'activating-store-app' '' $port
    $launch = Invoke-NativeHelper 'launch' $port
    $ownerReady = $false
    $deadline=[DateTime]::UtcNow.AddSeconds(60)
    Write-StartupStatus 'waiting-for-listener' '' $port
    while ([DateTime]::UtcNow -lt $deadline) {
        try { $null = Invoke-NativeHelper 'verify-owner' $port; $ownerReady = $true; break }
        catch {
            if ($script:lastHelperCode -ne 'E_CDP_NOT_LISTENING') { throw }
            Start-Sleep -Seconds 1
        }
    }
    if (-not $ownerReady) { throw 'The Store app did not open its verified local debug listener.' }
    Write-StartupStatus 'listener-verified' '' $port
    $cli = Join-Path $launch.package.installLocation 'app\resources\codex.exe'
    if (-not (Test-Path -LiteralPath $cli -PathType Leaf)) { throw 'Bundled Codex CLI is missing.' }
    if($PrepareOnly) {
        if($LaunchToken -notmatch '^[a-f0-9]{32}$'){throw 'Missing preparation nonce.'}
        [ordered]@{nonce=$LaunchToken;node=$node;cli=$cli;port=$port} | ConvertTo-Json |
            Set-Content -LiteralPath (Join-Path $runtime 'launch.json') -Encoding UTF8
        return
    }
    Write-Host 'Native Store activation verified. Meter active; Codex app files are unchanged.'
    $meterArgs=@((Join-Path $PSScriptRoot 'src\cli.mjs'),'attach','--port',"$port",'--codex',$cli)
    if($StopFile){$meterArgs+=@('--stop-file',$StopFile)}
    & $node @meterArgs
    if ($LASTEXITCODE -ne 0) { $script:lastHelperCode = 'E_METER_ATTACH'; throw 'Meter attachment failed. Inspect .runtime\status.json.' }
} catch {
    Write-StartupStatus 'startup-failed' $script:lastHelperCode
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Diagnostic status: $statusPath"
    exit 1
} finally {
    if($ownsMonitor){$monitorMutex.ReleaseMutex()}
    if($monitorMutex){$monitorMutex.Dispose()}
}
