// Feasibility-only probe. No credentials, transcripts, settings edits or network calls.
import {lstat} from 'node:fs/promises';
import {join, delimiter} from 'node:path';
import {homedir} from 'node:os';
import {pathToFileURL} from 'node:url';

async function kind(path) {
  try { const s=await lstat(path); return s.isSymbolicLink()?'linked':s.isDirectory()?'directory':s.isFile()?'file':'other'; }
  catch(e) { return e.code==='ENOENT'?'absent':'unreadable'; }
}
export async function inventory({home=homedir(),env=process.env,platform=process.platform}={}) {
  const root=env.CLAUDE_CONFIG_DIR||join(home,'.claude');
  const rootKind=await kind(root);
  const entries={};
  for(const name of ['projects','transcripts','settings.json','stats-cache.json']) entries[name]=rootKind==='directory'?await kind(join(root,name)):'not-scanned';
  const executableNames=platform==='win32'?['claude.exe','claude.cmd','claude.bat']:['claude'];
  const folders=[...(env.PATH||'').split(delimiter).filter(Boolean),join(home,'.local','bin')];
  if(platform==='win32'&&env.APPDATA)folders.push(join(env.APPDATA,'npm'));
  let cliOnPathOrDefault=false;
  for(const folder of new Set(folders))for(const name of executableNames)if(await kind(join(folder,name))==='file')cliOnPathOrDefault=true;
  return {schema:1,platform,checkedAt:new Date().toISOString(),configSource:env.CLAUDE_CONFIG_DIR?'explicit-override':'default-home',configDirectory:rootKind,cliOnPathOrDefault,entries,liveQuotaVerified:false,liveAccountVerified:false,credentialsRead:false,transcriptsRead:false,settingsModified:false,networkUsed:false};
}
const numeric=(v,min=0,max=Number.MAX_SAFE_INTEGER)=>typeof v==='number'&&Number.isFinite(v)&&v>=min&&v<=max?v:null;
const tokens=v=>Number.isSafeInteger(v)&&v>=0?v:null;
export function inspectStatusline(input,now=Date.now()) {
  if(!input||typeof input!=='object'||Array.isArray(input))throw Error('Expected a status-line object');
  const limits={};
  for(const key of ['five_hour','seven_day']) {
    const w=input.rate_limits?.[key];
    const used=numeric(w?.used_percentage,0,100),reset=tokens(w?.resets_at);
    const valid=used!==null&&reset!==null&&reset<=8640000000000;
    const state=!w?'not-provided':!valid?'invalid':reset*1000<=now?'expired':'reported';
    limits[key]={state,usedPercentage:state==='reported'?used:null,remainingPercentage:state==='reported'?100-used:null,resetsAt:state==='reported'?reset:null};
  }
  const usage=input.context_window?.current_usage;
  const cost=numeric(input.cost?.total_cost_usd);
  const version=typeof input.version==='string'&&/^\d+\.\d+\.\d+(?:[-+][a-zA-Z0-9.-]+)?$/.test(input.version)?input.version:null;
  return {schema:1,source:'explicit-statusline-input',receivedAt:now,providerObservedAt:null,version,
    limits,context:{usedPercentage:numeric(input.context_window?.used_percentage,0,100),inputTokens:tokens(usage?.input_tokens),outputTokens:tokens(usage?.output_tokens),cacheReadTokens:tokens(usage?.cache_read_input_tokens),cacheWriteTokens:tokens(usage?.cache_creation_input_tokens)},
    sessionCostEstimateUsd:cost,accountIdentity:'unverified',notificationEligible:false,
    historyTotalTokens:null,billingVerified:false,modelFieldPresent:typeof input.model?.id==='string',sessionFieldPresent:typeof input.session_id==='string',
    evidenceLevel:'payload-contract-only-not-a-live-account-proof'};
}
async function main(){
  if(process.argv[2]==='--inventory'){console.log(JSON.stringify(await inventory(),null,2));return;}
  if(process.argv[2]==='--stdin'){
    let text='',bytes=0;
    for await(const chunk of process.stdin){bytes+=chunk.length;if(bytes>131072)throw Error('Input too large');text+=chunk.toString('utf8');}
    console.log(JSON.stringify(inspectStatusline(JSON.parse(text)),null,2));return;
  }
  throw Error('Use --inventory or --stdin; this tool never installs or changes Claude Code');
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)main().catch(()=>{console.error('Probe failed: input unavailable or invalid; no raw payload printed');process.exitCode=1;});
