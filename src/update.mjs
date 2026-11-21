import {readFile,writeFile,mkdir,mkdtemp,copyFile,rename,lstat,chmod,realpath,unlink} from 'node:fs/promises';
import {createHash,verify,randomUUID} from 'node:crypto';
import {writeFileSync} from 'node:fs';
import {join,resolve,dirname,basename} from 'node:path';
import {tmpdir,homedir,arch} from 'node:os';
import {spawn,spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {backupSettings,verifySettings,restoreSettings,localizedNotes,canonicalEntry,transactionState,waitForRecord} from './update-transaction.mjs';
const feedURL='https://raw.githubusercontent.com/kefen/AI-Usage-Monitor/main/docs/updates/latest.json';
export const wholeCredits=value=>typeof value==='string'&&/^\d+(\.\d+)?$/.test(value)&&Number.isSafeInteger(Math.floor(Number(value)))?String(Math.floor(Number(value))):'--';
export function reusableCheck(state,current,language,now=Date.now()){
 if(!state||state.current!==current||state.language!==language||!Number.isFinite(state.checkedAt)||state.checkedAt>now||now-state.checkedAt>=21600000)return false;
 try{return state.available===updateAvailable(state.version,current);}catch{return false;}
}
export function updateError(error) {
 const message=String(error?.message||'');
 const code=/^E_UPDATE_[A-Z_]+$/.test(message)?message:
  /signature/i.test(message)?'E_UPDATE_SIGNATURE':
  /checksum/i.test(message)?'E_UPDATE_CHECKSUM':
  /fetch|network|timed?\s*out|abort/i.test(message)?'E_UPDATE_NETWORK':
  ['ENOENT','EACCES','EPERM'].includes(error?.code)?'E_UPDATE_CONFIGURATION':'E_UPDATE_METADATA';
 return {error:code};
}
export function newer(a,b){
 const parse=v=>{const m=/^(\d+)\.(\d+)\.(\d+)(?:-(alpha|beta)\.(\d+))?$/.exec(v);if(!m)throw Error('Invalid version');return [+m[1],+m[2],+m[3],m[4]==='alpha'?0:m[4]==='beta'?1:2,+(m[5]||0)];};
 const x=parse(a),y=parse(b);for(let i=0;i<x.length;i++)if(x[i]!==y[i])return x[i]>y[i];return false;
}
export function validateAsset(a){
 const u=new URL(a.url);
 // Never fetch from a retired repository name: the old slug could be reused.
 u.pathname=u.pathname.replace(/^\/kefen\/(?:codex-quota-sidebar|AI-Quota-Board)\/releases\/download\//,'/kefen/AI-Usage-Monitor/releases/download/');
 if(u.protocol!=='https:'||u.hostname!=='github.com'||u.username||u.password||u.port||!u.pathname.startsWith('/kefen/AI-Usage-Monitor/releases/download/')||u.search||u.hash)throw Error('Untrusted asset');
 if(!/^[a-f0-9]{64}$/.test(a.sha256)||!Number.isSafeInteger(a.size)||a.size<1||a.size>180000000)throw Error('Invalid asset');newer(a.version,'0.0.0');return {...a,url:u.href};
}
export function updateAvailable(advertised,current){
 if(newer(current,advertised))throw Error('E_UPDATE_FEED_BEHIND');
 return newer(advertised,current);
}
export function verifyFeed(envelope,key,now=Date.now()){
 if(typeof envelope.payload!=='string'||envelope.payload.length>90000||typeof envelope.signature!=='string')throw Error('Invalid update envelope');
 const bytes=Buffer.from(envelope.payload,'base64');if(!verify(null,bytes,key,Buffer.from(envelope.signature,'base64')))throw Error('Update signature rejected');
 const data=JSON.parse(bytes);if(data.schema!==1||!Number.isSafeInteger(data.expiresAt)||data.expiresAt<now||!data.releases)throw Error('Update feed expired or invalid');return data;
}
export async function updateBytes(url,limit,asset=false,fetcher=fetch,delay=ms=>new Promise(r=>setTimeout(r,ms)),progress,{idleMs=25000,totalMs=300000}={}){
 if(!asset||!progress)return requestBytes(url,limit,asset,fetcher,delay);
 const deadline=AbortSignal.timeout(totalMs);
 for(let attempt=1;attempt<=2;attempt++){
  const stall=new AbortController();let timer;
  const onBytes=size=>{clearTimeout(timer);timer=setTimeout(()=>stall.abort(),idleMs);progress(size,attempt);};
  try{onBytes(0);return await requestBytes(url,limit,true,fetcher,delay,AbortSignal.any([deadline,stall.signal]),onBytes);}
  catch(error){if(error.message!=='E_UPDATE_NETWORK'||attempt===2||deadline.aborted)throw error;}
  finally{clearTimeout(timer);}
  await delay(500);
 }
}
async function requestBytes(url,limit,asset,fetcher,delay,signal,onBytes){
 let current=url;
 for(let i=0;i<6;i++){
  const u=new URL(current);if(u.protocol!=='https:'||!(u.hostname==='raw.githubusercontent.com'||asset&&['github.com','release-assets.githubusercontent.com','objects.githubusercontent.com'].includes(u.hostname)))throw Error('Untrusted redirect');
  let r;
  for(let attempt=0;attempt<(asset?1:2);attempt++){
   try{
    r=await fetcher(current,{redirect:'manual',signal:signal??AbortSignal.timeout(asset?120000:8000),headers:{'User-Agent':'AI-Usage-Monitor-Updater'}});
    if(r.status===429||r.status>=500)throw Error('E_UPDATE_NETWORK');
    break;
   }catch{if(asset||attempt===1)throw Error('E_UPDATE_NETWORK');await delay(250);}
  }
  if([301,302,303,307,308].includes(r.status)){current=new URL(r.headers.get('location'),current).href;continue;}
  if(!r.ok)throw Error('Update network error '+r.status);if(Number(r.headers.get('content-length'))>limit)throw Error('Update too large');
  const chunks=[];let size=0;
  try{for await(const c of r.body){size+=c.length;if(size>limit)break;chunks.push(c);onBytes?.(size);}}
  catch{throw Error('E_UPDATE_NETWORK');}
  if(size>limit)throw Error('Update too large');
  if(onBytes&&size!==limit)throw Error('E_UPDATE_NETWORK');
  return Buffer.concat(chunks);
 }throw Error('Too many redirects');
}
const bytes=updateBytes;
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const run=(file,args)=>{const r=spawnSync(file,args,{windowsHide:true,timeout:180000,encoding:'utf8'});if(r.error||r.status!==0)throw Error('Update operation failed: '+basename(file));return r.stdout;};
async function noLinks(path){for(let p=resolve(path);;p=dirname(p)){if((await lstat(p)).isSymbolicLink())throw Error('Linked update paths are not supported');if(dirname(p)===p)break;}}
async function apply(planPath){
 const plan=JSON.parse(await readFile(planPath,'utf8'));const key=await readFile(new URL('./update-public-key.pem',import.meta.url),'utf8');
 const data=verifyFeed(plan.envelope,key);const asset=validateAsset(data.releases[plan.target]);
 if(!['windows-x64','macos-arm64','macos-x64'].includes(plan.target)||plan.version!==asset.version||!/^[a-f0-9-]{36}$/.test(plan.id))throw Error('Invalid update plan');
 const root=await realpath(plan.root),cache=join(root,'.runtime','updates');
 if(plan.transactionPath!==join(cache,'transaction.json')||plan.backupFolder!==join(cache,'settings-'+plan.id)||!Array.isArray(plan.pids)||plan.pids.length>4||plan.pids.some(p=>!Number.isSafeInteger(p)||p<2))throw Error('Invalid transaction paths');
 await noLinks(plan.destination);
 const state=(stage,fields={})=>transactionState(plan.transactionPath,stage,{id:plan.id,version:asset.version,destination:plan.destination,...fields});
 try{
  const content=await readFile(plan.file);if(content.length!==asset.size||createHash('sha256').update(content).digest('hex')!==asset.sha256)throw Error('E_UPDATE_CHECKSUM');
  await backupSettings(root,plan.backupFolder);
  await state('worker-ready');await writeFile(join(dirname(planPath),'worker-ready.json'),JSON.stringify({id:plan.id}),{mode:0o600});
  for(let i=0;i<120;i++){const alive=plan.pids.some(pid=>{try{process.kill(pid,0);return true;}catch{return false;}});if(!alive)break;if(i===119)throw Error('E_UPDATE_APP_STILL_RUNNING');await sleep(1000);}
  await backupSettings(root,plan.backupFolder);await state('installing');
  if(plan.target==='windows-x64'){
   const extracted=join(dirname(planPath),'payload');run(plan.file,['--extract',extracted]);
   run(join(process.env.SystemRoot,'System32','WindowsPowerShell','v1.0','powershell.exe'),['-NoProfile','-ExecutionPolicy','Bypass','-File',join(extracted,'Install.ps1'),'-Destination',plan.destination]);
   await verifySettings(root,plan.backupFolder);
   await state('launching');
   const child=spawn(join(plan.destination,'CodexMeter.exe'),[],{detached:true,stdio:'ignore',windowsHide:true});
   await new Promise((resolve,reject)=>{child.once('spawn',resolve);child.once('error',reject);});child.unref();
   await state('installed',{settingsPreserved:true});return;
  }
  const allowed=[join('/Applications','AI Usage Monitor.app'),join(homedir(),'Applications','AI Usage Monitor.app')];
  if(!allowed.includes(plan.destination))throw Error('E_UPDATE_INSTALL_LOCATION');
  const mount=join(dirname(planPath),'mount');await mkdir(mount,{recursive:true});
  const next=plan.destination+'.update-'+plan.id,backup=plan.destination+'.backup-'+plan.id;
  let moved=false,replaced=false;
  try{
   run('/usr/bin/hdiutil',['attach','-readonly','-nobrowse','-mountpoint',mount,plan.file]);
   const app=join(mount,'AI Usage Monitor.app');
   run('/usr/bin/codesign',['--verify','--deep','--strict',app]);
   const candidateVersion=run('/usr/libexec/PlistBuddy',['-c','Print :CQSReleaseVersion',join(app,'Contents','Info.plist')]).trim();
   if(candidateVersion!==asset.version)throw Error('E_UPDATE_BUNDLE_VERSION');
   run('/usr/bin/ditto',[app,next]);await rename(plan.destination,backup);moved=true;
   await rename(next,plan.destination);replaced=true;
   await unlink(join(cache,'ack.json')).catch(()=>{});
   await state('launching');
   run('/usr/bin/open',['-n',plan.destination,'--args','--update-transaction',plan.transactionPath,'--update-version',asset.version]);
   const ack=await waitForRecord(join(cache,'ack.json'),a=>a.id===plan.id&&a.stage==='app-ready'&&a.version===asset.version&&a.bundlePath===plan.destination,45000);
   if(!ack)throw Error('E_UPDATE_LAUNCH_UNVERIFIED');
   await verifySettings(root,plan.backupFolder);
   await state('complete',{settingsPreserved:true});
  }catch(e){
   // Only roll back when no new app can be found at the exact installed executable.
   const executable=join(plan.destination,'Contents','MacOS','QuotaSidebar');
   const processes=run('/bin/ps',['-axo','comm=']).split('\n').map(v=>v.trim());
   const running=processes.includes(executable);
   if(moved&&!running){
    if(replaced)await rename(plan.destination,next+'.failed');
    await rename(backup,plan.destination);await restoreSettings(root,plan.backupFolder);
    await state('rolled-back',{code:String(e.message).slice(0,160),settingsPreserved:true});
    run('/usr/bin/open',['-n',plan.destination]);
   }else await state('needs-attention',{code:String(e.message).slice(0,160),backupAvailable:moved});
   throw e;
  }finally{try{run('/usr/bin/hdiutil',['detach',mount]);}catch{}}
 }catch(e){
  let last={};try{last=JSON.parse(await readFile(plan.transactionPath,'utf8'));}catch{}
  if(!['rolled-back','needs-attention'].includes(last.stage))await state('failed',{code:String(e.message).slice(0,160)});
  throw e;
 }
}
async function main(){
 const [command,rootArg,destination,pidArg]=process.argv.slice(2);
 if(command==='apply'){try{await apply(rootArg);}catch(e){await writeFile(join(dirname(rootArg),'update-error.txt'),e.message);throw e;}return;}
 if(!['check','auto','download','prepare'].includes(command))throw Error('Unsupported update operation');
 const root=await realpath(resolve(rootArg)),cache=join(root,'.runtime','updates');await mkdir(cache,{recursive:true});await noLinks(cache);
 const statePath=join(cache,'state.json');let previous={};try{previous=JSON.parse(await readFile(statePath,'utf8'));}catch{}
 let language='en';try{const saved=JSON.parse(await readFile(join(root,'.runtime','language.json'),'utf8'));if(['en','zh-CN','zh-TW'].includes(saved))language=saved;}catch{}
 const versions=JSON.parse(await readFile(join(root,'versions.json'),'utf8'));
 const target=process.platform==='win32'?'windows-x64':'macos-'+arch();const current=versions[process.platform==='win32'?'windows':'macos'];
 if(command==='auto'&&reusableCheck(previous,current,language)){console.log(JSON.stringify({...previous,prepared:false}));return;}
 const key=await readFile(new URL('./update-public-key.pem',import.meta.url),'utf8');
 const envelope=JSON.parse((await bytes(feedURL,100000)).toString());const feed=verifyFeed(envelope,key);
 const entry=feed.releases[target];const available=updateAvailable(entry.version,current);
 const asset=available?validateAsset(entry):entry;
 const state={checkedAt:Date.now(),current,language,available,version:asset.version,notes:localizedNotes(asset.notesByLocale||asset.notes,language),ready:false};
 const file=join(cache,process.platform==='win32'?'update.exe':'update.dmg');
 if(available&&['download','prepare'].includes(command)){
  let content;try{content=await readFile(file);}catch{}
  if(!content||content.length!==asset.size||createHash('sha256').update(content).digest('hex')!==asset.sha256){
   let lastProgress=0;
   const progress=process.platform==='darwin'&&command==='download'?(received,attempt)=>{
    if(received!==0&&received!==asset.size&&Date.now()-lastProgress<250)return;
    lastProgress=Date.now();
    try{writeFileSync(join(cache,'download-progress.json'),JSON.stringify({received,total:asset.size,attempt,updatedAt:lastProgress}),{flag:'w',mode:0o600});}catch{}
   }:undefined;
   content=await bytes(asset.url,asset.size,true,undefined,undefined,progress);
   if(content.length!==asset.size||createHash('sha256').update(content).digest('hex')!==asset.sha256)throw Error('Update checksum rejected');
   await writeFile(file+'.part',content);await rename(file+'.part',file);
  }
  state.ready=true;
  if(command==='prepare'){
   const id=randomUUID(),transactionPath=join(cache,'transaction.json'),backupFolder=join(cache,'settings-'+id);
   // Validate saved settings before asking the running application to terminate.
   await backupSettings(root,backupFolder);
   const folder=await mkdtemp(join(tmpdir(),'cqs-update-'));const node=join(folder,process.platform==='win32'?'node.exe':'node');await copyFile(process.execPath,node);await chmod(node,0o700);
   await copyFile(file,join(folder,basename(file)));
   for(const name of ['update.mjs','update-public-key.pem','update-transaction.mjs'])await copyFile(new URL('./'+name,import.meta.url),join(folder,name));
   const pids=[Number(pidArg)];if(!Number.isSafeInteger(pids[0])||pids[0]<2)throw Error('Invalid application PID');
   for(const name of ['background-status.json','mac.pid']){try{const raw=await readFile(join(root,'.runtime',name),'utf8');const value=name==='mac.pid'?Number(raw.trim()):JSON.parse(raw).monitorPid;if(Number.isSafeInteger(value)&&value>1)pids.push(value);}catch{}}
   const plan=join(folder,'plan.json');
   await writeFile(plan,JSON.stringify({id,envelope,target,version:asset.version,root,transactionPath,backupFolder,file:join(folder,basename(file)),destination:await realpath(resolve(destination)),pids:[...new Set(pids)]}),{mode:0o600});
   await transactionState(transactionPath,'preparing',{id,version:asset.version,destination:await realpath(resolve(destination))});
   const worker=spawn(node,[join(folder,'update.mjs'),'apply',plan],{detached:true,stdio:'ignore',windowsHide:true});
   await new Promise((resolve,reject)=>{worker.once('spawn',resolve);worker.once('error',reject);});worker.unref();
   try{await waitForRecord(join(folder,'worker-ready.json'),a=>a.id===id,12000);}
   catch{await transactionState(transactionPath,'failed',{id,version:asset.version,code:'E_UPDATE_WORKER_NOT_READY'});throw Error('E_UPDATE_WORKER_NOT_READY');}
   state.prepared=true;
  }
 }
 await writeFile(statePath,JSON.stringify(state));console.log(JSON.stringify(state));
}
if(canonicalEntry(process.argv[1],import.meta.url))main().catch(async e=>{
 const result=updateError(e);
 try{if(process.argv[2]!=='apply'){const folder=join(await realpath(resolve(process.argv[3])),'.runtime','updates');await noLinks(folder);await transactionState(join(folder,'last-error.json'),'check-failed',{code:result.error});}}catch{}
 console.log(JSON.stringify(result));process.exitCode=1;
});
