param([Parameter(Mandatory=$true)][ValidatePattern('^[a-p]{32}$')][string]$ExtensionId,[switch]$Remove)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$runtime=Join-Path $root '.runtime'
$key='HKCU:\Software\Google\Chrome\NativeMessagingHosts\org.kefen.codex_quota_sidebar'
$manifest=Join-Path $runtime 'browser-native.json'
if($Remove){if(Test-Path $key){if((Get-Item $key).GetValue('') -ne $manifest){throw 'Registration belongs to another installation'};Remove-Item -LiteralPath $key};return}
if(-not(Test-Path (Join-Path $root 'BrowserHost.exe'))){throw 'Build/install the Windows native host first'}
if(Test-Path $key){if((Get-Item $key).GetValue('') -ne $manifest){throw 'Refusing to replace another registration'}}
New-Item -ItemType Directory -Path $runtime -Force|Out-Null
@{extensionId=$ExtensionId}|ConvertTo-Json|Set-Content (Join-Path $runtime 'browser-host.json') -Encoding ascii
@{name='org.kefen.codex_quota_sidebar';description='Read-only Codex quota snapshot by KEFEN';path=(Join-Path $root 'BrowserHost.exe');type='stdio';allowed_origins=@("chrome-extension://$ExtensionId/")}|ConvertTo-Json|Set-Content $manifest -Encoding ascii
New-Item -Path $key -Force|Out-Null
Set-Item -LiteralPath $key -Value $manifest
Write-Host 'Registered only for the specified extension ID. Use -Remove before uninstalling.'
