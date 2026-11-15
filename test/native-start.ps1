param([switch]$PrepareOnly,[string]$LaunchToken)
$ErrorActionPreference='Stop'
$node=(Get-Content (Join-Path $PSScriptRoot 'fixture.json') -Raw|ConvertFrom-Json).node
@{nonce=$LaunchToken;node=$node;cli=$node;port=19001}|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot '.runtime\launch.json') -Encoding UTF8
