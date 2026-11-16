import {readFile,writeFile,mkdir,mkdtemp,copyFile,rename,lstat,chmod} from 'node:fs/promises';
import {createHash,verify} from 'node:crypto';
import {join,resolve,dirname,basename} from 'node:path';
import {tmpdir,homedir,arch} from 'node:os';
import {spawn,spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const feedURL='https://raw.githubusercontent.com/kefen/codex-quota-sidebar/main/docs/updates/latest.json';
export const wholeCredits=value=>typeof value==='string'&&/^\d+(\.\d+)?$/.test(value)&&Number.isSafeInteger(Math.floor(Number(value)))?String(Math.floor(Number(value))):'--';
export function newer(a,b){
 const parse=v=>{const m=/^(\d+)\.(\d+)\.(\d+)(?:-(alpha|beta)\.(\d+))?$/.exec(v);if(!m)throw Error('Invalid version');return [+m[1],+m[2],+m[3],m[4]==='alpha'?0:m[4]==='beta'?1:2,+(m[5]||0)];};
 const x=parse(a),y=parse(b);for(let i=0;i<x.length;i++)if(x[i]!==y[i])return x[i]>y[i];return false;
}
export function validateAsset(a){
 const u=new URL(a.url);if(u.protocol!=='https:'||u.hostname!=='github.com'||u.username||u.password||u.port||!u.pathname.startsWith('/kefen/codex-quota-sidebar/releases/download/')||u.search||u.hash)throw Error('Untrusted asset');
 if(!/^[a-f0-9]{64}$/.test(a.sha256)||!Number.isSafeInteger(a.size)||a.size<1||a.size>180000000)throw Error('Invalid asset');newer(a.version,'0.0.0');return a;
}
export function verifyFeed(envelope,key,now=Date.now()){
 if(typeof envelope.payload!=='string'||envelope.payload.length>90000||typeof envelope.signature!=='string')throw Error('Invalid update envelope');
 const bytes=Buffer.from(envelope.payload,'base64');if(!verify(null,bytes,key,Buffer.from(envelope.signature,'base64')))throw Error('Update signature rejected');
 const data=JSON.parse(bytes);if(data.schema!==1||!Number.isSafeInteger(data.expiresAt)||data.expiresAt<now||!data.releases)throw Error('Update feed expired or invalid');return data;
}
async function bytes(url,limit,asset=false){
 let current=url;
 for(let i=0;i<6;i++){
  const u=new URL(current);if(u.protocol!=='https:'||!(u.hostname==='raw.githubusercontent.com'||asset&&['github.com','release-assets.githubusercontent.com','objects.githubusercontent.com'].includes(u.hostname)))throw Error('Untrusted redirect');
  const r=await fetch(current,{redirect:'manual',signal:AbortSignal.timeout(120000),headers:{'User-Agent':'Codex-Quota-Sidebar-Updater'}});
  if([301,302,303,307,308].includes(r.status)){current=new URL(r.headers.get('location'),current).href;continue;}
  if(!r.ok)throw Error('Update network error '+r.status);if(Number(r.headers.get('content-length'))>limit)throw Error('Update too large');
  const chunks=[];let size=0;for await(const c of r.body){size+=c.length;if(size>limit)throw Error('Update too large');chunks.push(c);}return Buffer.concat(chunks);
 }throw Error('Too many redirects');
}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const run=(file,args)=>{const r=spawnSync(file,args,{windowsHide:true,timeout:180000,encoding:'utf8'});if(r.error||r.status!==0)throw Error('Update operation failed: '+basename(file));return r.stdout;};
async function noLinks(path){for(let p=resolve(path);;p=dirname(p)){if((await lstat(p)).isSymbolicLink())throw Error('Linked update paths are not supported');if(dirname(p)===p)break;}}
async function apply(planPath){
 const plan=JSON.parse(await readFile(planPath,'utf8'));const key=await readFile(new URL('./update-public-key.pem',import.meta.url),'utf8');
 const data=verifyFeed(plan.envelope,key);const asset=validateAsset(data.releases[plan.target]);
 const content=await readFile(plan.file);if(content.length!==asset.size||createHash('sha256').update(content).digest('hex')!==asset.sha256)throw Error('Downloaded update changed');
 await noLinks(plan.destination);
 for(let n=0;n<120;n++){let alive=false;for(const pid of plan.pids){try{process.kill(pid,0);alive=true;}catch{}}if(!alive)break;if(n===119)throw Error('Software still running; update cancelled');await sleep(1000);}
 if(plan.target==='windows-x64'){
  const extracted=join(dirname(planPath),'payload');run(plan.file,['--extract',extracted]);
  run(join(process.env.SystemRoot,'System32','WindowsPowerShell','v1.0','powershell.exe'),['-NoProfile','-ExecutionPolicy','Bypass','-File',join(extracted,'Install.ps1'),'-Destination',plan.destination]);
  spawn(join(plan.destination,'CodexMeter.exe'),[],{detached:true,stdio:'ignore',windowsHide:true}).unref();
 }else{
  const allowed=[join('/Applications','Codex Quota Sidebar.app'),join(homedir(),'Applications','Codex Quota Sidebar.app')];if(!allowed.includes(plan.destination))throw Error('Install in Applications before updating');
  const mount=join(dirname(planPath),'mount');await mkdir(mount);
  const next=plan.destination+'.update-'+Date.now(),backup=plan.destination+'.backup-'+Date.now();let moved=false;
  try{
   run('/usr/bin/hdiutil',['attach','-readonly','-nobrowse','-mountpoint',mount,plan.file]);
   const app=join(mount,'Codex Quota Sidebar.app');run('/usr/bin/codesign',['--verify','--deep','--strict',app]);
   run('/usr/bin/ditto',[app,next]);await rename(plan.destination,backup);moved=true;await rename(next,plan.destination);
   run('/usr/bin/open',['-n',plan.destination]);
  }catch(e){if(moved){try{await rename(plan.destination,next+'.failed');}catch{}await rename(backup,plan.destination);}throw e;}
  finally{try{run('/usr/bin/hdiutil',['detach',mount]);}catch{}}
 }
}
async function main(){
 const [command,rootArg,destination,pidArg]=process.argv.slice(2);
 if(command==='apply'){try{await apply(rootArg);}catch(e){await writeFile(join(dirname(rootArg),'update-error.txt'),e.message);throw e;}return;}
 if(!['check','auto','download','prepare'].includes(command))throw Error('Unsupported update operation');
 const root=resolve(rootArg),cache=join(root,'.runtime','updates');await mkdir(cache,{recursive:true});await noLinks(cache);
 const statePath=join(cache,'state.json');let previous={};try{previous=JSON.parse(await readFile(statePath,'utf8'));}catch{}
 if(command==='auto'&&Date.now()-(previous.checkedAt||0)<86400000){console.log(JSON.stringify(previous));return;}
 const key=await readFile(new URL('./update-public-key.pem',import.meta.url),'utf8');
 const envelope=JSON.parse((await bytes(feedURL,100000)).toString());const feed=verifyFeed(envelope,key);
 const versions=JSON.parse(await readFile(join(root,'versions.json'),'utf8'));
 const target=process.platform==='win32'?'windows-x64':'macos-'+arch();const current=versions[process.platform==='win32'?'windows':'macos'];
 const asset=validateAsset(feed.releases[target]);const available=newer(asset.version,current);
 const state={checkedAt:Date.now(),available,version:asset.version,notes:typeof asset.notes==='string'?asset.notes.slice(0,3000):'',ready:false};
 const file=join(cache,process.platform==='win32'?'update.exe':'update.dmg');
 if(available&&['download','prepare'].includes(command)){
  let content;try{content=await readFile(file);}catch{}
  if(!content||content.length!==asset.size||createHash('sha256').update(content).digest('hex')!==asset.sha256){content=await bytes(asset.url,asset.size,true);if(content.length!==asset.size||createHash('sha256').update(content).digest('hex')!==asset.sha256)throw Error('Update checksum rejected');await writeFile(file+'.part',content);await rename(file+'.part',file);}
  state.ready=true;
  if(command==='prepare'){
   const folder=await mkdtemp(join(tmpdir(),'cqs-update-'));const node=join(folder,process.platform==='win32'?'node.exe':'node');await copyFile(process.execPath,node);await chmod(node,0o700);
   await copyFile(file,join(folder,basename(file)));await copyFile(fileURLToPath(import.meta.url),join(folder,'update.mjs'));await copyFile(new URL('./update-public-key.pem',import.meta.url),join(folder,'update-public-key.pem'));
   const pids=[Number(pidArg)];if(!Number.isSafeInteger(pids[0])||pids[0]<2)throw Error('Invalid application PID');
   for(const name of ['background-status.json','mac.pid']){try{const text=await readFile(join(root,'.runtime',name),'utf8');const value=name==='mac.pid'?Number(text.trim()):JSON.parse(text).monitorPid;if(Number.isSafeInteger(value)&&value>1)pids.push(value);}catch{}}
   const plan=join(folder,'plan.json');await writeFile(plan,JSON.stringify({envelope,target,file:join(folder,basename(file)),destination:resolve(destination),pids}));
   const worker=spawn(node,[join(folder,'update.mjs'),'apply',plan],{detached:true,stdio:'ignore',windowsHide:true});worker.unref();
  }
 }
 await writeFile(statePath,JSON.stringify(state));console.log(JSON.stringify(state));
}
if(process.argv[1]===fileURLToPath(import.meta.url))main().catch(e=>{console.log(JSON.stringify({error:e.message}));process.exitCode=1;});
