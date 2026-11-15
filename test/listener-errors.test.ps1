$ErrorActionPreference='Stop'
$path=Join-Path (Split-Path $PSScriptRoot -Parent) 'vendor\codex-quota\codex-cdp.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
foreach($name in @('Throw-CodedError','Get-LoopbackListener')){
    $fn=$ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$true) | Where-Object {$_.Name -eq $name}
    . ([ScriptBlock]::Create($fn.Extent.Text))
}
function Get-NetTCPConnection {
    [CmdletBinding()]param($State,$LocalPort)
    if($script:case -eq 'denied'){throw [UnauthorizedAccessException]::new('Access denied')}
    if($script:case -eq 'missing'){$PSCmdlet.ThrowTerminatingError([Management.Automation.ErrorRecord]::new([Exception]::new('No matching listener'),'CmdletizationQuery_NotFound_LocalPort',[Management.Automation.ErrorCategory]::ObjectNotFound,$null))}
    return [pscustomobject]@{LocalAddress='127.0.0.1';OwningProcess=42}
}
$script:case='denied';$code=''
try{Get-LoopbackListener 12101|Out-Null}catch{$code=$_.Exception.Data['Code']}
if($code -ne 'E_CDP_QUERY_FAILED'){throw 'Access failure was incorrectly classified as no listener'}
$script:case='missing'
if($null -ne (Get-LoopbackListener 12101)){throw 'Absent listener not handled'}
$script:case='present'
if((Get-LoopbackListener 12101).pid -ne 42){throw 'Valid listener rejected'}
Write-Host 'PASS: query denied, listener absent and valid listener stay distinct'
