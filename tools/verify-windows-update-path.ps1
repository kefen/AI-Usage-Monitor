param(
    [Parameter(Mandatory)][string]$PriorClient,
    [Parameter(Mandatory)][version]$Version,
    [string]$InstalledVersions
)
$ErrorActionPreference='Stop'
$prior=(Resolve-Path -LiteralPath $PriorClient).Path
if (!$InstalledVersions) { $InstalledVersions=Join-Path $prior 'versions.json' }
$priorVersion=(Get-Content -LiteralPath $InstalledVersions -Raw | ConvertFrom-Json).windows
if ([version]$priorVersion -ge $Version) { throw 'Expected a previous Windows client' }
$scratch=New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ('aim-update-test-'+[guid]::NewGuid().ToString('N')))
Copy-Item -LiteralPath $InstalledVersions -Destination (Join-Path $scratch.FullName 'versions.json')
$updater=Join-Path $prior 'src/update.mjs'
foreach ($action in 'auto','check','download') {
    $result=& node $updater $action $scratch.FullName
    if ($LASTEXITCODE -ne 0) { throw "Previous client failed during $action" }
    $state=$result | ConvertFrom-Json
    if ($state.current -ne $priorVersion -or $state.available -ne $true -or $state.version -ne $Version.ToString()) {
        throw "Update delivery failed ($action): client=$priorVersion advertised=$($state.version) available=$($state.available) expected=$Version"
    }
}
if ($state.ready -ne $true) { throw 'Previous client did not verify and stage the download' }
$release=Invoke-RestMethod -Uri "https://api.github.com/repos/kefen/AI-Usage-Monitor/releases/tags/windows%2Fv$Version"
$assets=@($release.assets | Where-Object name -eq "AI-Usage-Monitor-Windows-$Version-x64-Setup.exe")
$download=Get-Item -LiteralPath (Join-Path $scratch.FullName '.runtime/updates/update.exe')
$digest='sha256:'+(Get-FileHash -Algorithm SHA256 -LiteralPath $download.FullName).Hash.ToLowerInvariant()
if ($release.draft -or $assets.Count -ne 1 -or $assets[0].digest -ne $digest -or $assets[0].size -ne $download.Length) { throw 'Staged installer differs from the public Release' }
Write-Output "Verified: Windows $priorVersion discovered $Version and staged the public installer. Installer was not executed."
