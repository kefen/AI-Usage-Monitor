// Disposable GitHub macOS runner only: never run against a user's installation.
import {mkdtemp,mkdir,writeFile,readFile,copyFile,access} from 'node:fs/promises';
import {tmpdir,homedir,arch} from 'node:os';
import {join,resolve,basename} from 'node:path';
import {spawn,spawnSync} from 'node:child_process';
import {createHash,generateKeyPairSync,sign,randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
import {waitForRecord} from '../src/update-transaction.mjs';

if(process.platform!=='darwin'||process.env.CI!=='true')throw Error('Only an isolated GitHub macOS runner may execute this test');
const versions=JSON.parse(await readFile('versions.json','utf8')),version=versions.macos;
const architecture=arch()==='arm64'?'arm64':'x86_64';
const artifact=resolve('dist/Codex-Quota-Sidebar-macOS-'+version+'-'+architecture+'-unsigned-test.dmg');
const root=join(homedir(),'Library','Application Support','CodexSidebarMeter');
const destination=join(homedir(),'Applications','Codex Quota Sidebar.app');
for(const target of [root,destination]){let present=true;try{await access(target);}catch{present=false;}if(present)throw Error('Refusing an existing runner installation');}
await mkdir(join(root,'.runtime','updates'),{recursive:true});await mkdir(join(destination,'Contents','MacOS'),{recursive:true});
await copyFile('/usr/bin/true',join(destination,'Contents','MacOS','QuotaSidebar'));
await writeFile(join(root,'versions.json'),JSON.stringify({windows:'0.12.6',macos:'0.4.8-alpha.1'}));
const settings={
 'membership.json':{enabled:true,plan:'pro',tier:'100',purchaseDate:'2026-09-06',kind:'renewal',date:'2026-12-06',planSource:'manual',manualOverride:true},
 'display.json':{short:false,week:true,plan:true,renewal:true,credits:true},
 'language.json':'en',
 'preferences.json':{cdpConsent:true,setupComplete:true,macGuideVersion:'0.4.8-alpha.1'}
};
for(const [name,value]of Object.entries(settings))await writeFile(join(root,'.runtime',name),JSON.stringify(value));
const folder=await mkdtemp(join(tmpdir(),'cqs-update-integration-'));
for(const name of ['update.mjs','update-transaction.mjs'])await copyFile(join('src',name),join(folder,name));
const {publicKey,privateKey}=generateKeyPairSync('ed25519');
await writeFile(join(folder,'update-public-key.pem'),publicKey.export({type:'spki',format:'pem'}));
const bytes=await readFile(artifact),asset={version,url:'https://github.com/kefen/codex-quota-sidebar/releases/download/macos/'+version+'/'+basename(artifact),size:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')};
const target='macos-'+arch(),payload=Buffer.from(JSON.stringify({schema:1,expiresAt:Date.now()+600000,releases:{[target]:asset}}));
const envelope={payload:payload.toString('base64'),signature:sign(null,payload,privateKey).toString('base64')};
const oldProcess=spawn('/bin/sleep',['90'],{stdio:'ignore'});
const id=randomUUID(),transactionPath=join(root,'.runtime','updates','transaction.json');
const plan={id,envelope,target,version,root,transactionPath,backupFolder:join(root,'.runtime','updates','settings-'+id),file:artifact,destination,pids:[oldProcess.pid]};
const planPath=join(folder,'plan.json');await writeFile(planPath,JSON.stringify(plan));
const worker=spawn(process.execPath,[join(folder,'update.mjs'),'apply',planPath],{stdio:['ignore','pipe','pipe']});
let errors='';worker.stderr.on('data',chunk=>{errors+=String(chunk).slice(0,1500);});
try{
 await waitForRecord(join(folder,'worker-ready.json'),v=>v.id===id,15000);
 assert.equal(oldProcess.exitCode,null,'running app must not be terminated by the updater');
 oldProcess.kill('SIGTERM');
 const outcome=await waitForRecord(transactionPath,v=>['complete','failed','rolled-back','needs-attention'].includes(v.stage),90000);
 assert.equal(outcome.stage,'complete',JSON.stringify(outcome)+' '+errors);
 const installed=JSON.parse(await readFile(join(root,'versions.json'),'utf8'));assert.equal(installed.macos,version);
 for(const [name,original]of Object.entries(settings)){const actual=JSON.parse(await readFile(join(root,'.runtime',name),'utf8'));for(const key of typeof original==='object'?Object.keys(original):[]){assert.deepEqual(actual[key],original[key],name+'/'+key);}if(typeof original==='string')assert.equal(actual,original);}
 const ack=JSON.parse(await readFile(join(root,'.runtime','updates','ack.json'),'utf8'));assert.equal(ack.version,version);assert.equal(ack.bundlePath,destination);
 console.log('Verified real Mac replacement, new-version launch acknowledgement and saved plan/date/language/display preservation: '+architecture);
}finally{
 if(oldProcess.exitCode===null)oldProcess.kill('SIGTERM');
 // Stop only this test companion. Never target Codex or another application.
 const ps=spawnSync('/bin/ps',['-axo','pid=,comm='],{encoding:'utf8'});
 for(const line of (ps.stdout||'').split('\n')){const match=/^\s*(\d+)\s+(.+)$/.exec(line);if(match&&match[2]===join(destination,'Contents','MacOS','QuotaSidebar')){try{process.kill(Number(match[1]),'SIGTERM');}catch{}}}
 if(worker.exitCode===null){await Promise.race([new Promise(done=>worker.once('exit',done)),new Promise(done=>setTimeout(done,3000))]);if(worker.exitCode===null)worker.kill('SIGTERM');}
}
