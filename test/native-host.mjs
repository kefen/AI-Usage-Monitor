import {spawn} from 'node:child_process';
import {mkdtemp,mkdir,copyFile,writeFile,readFile,rm} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
import {setTimeout as delay} from 'node:timers/promises';
import assert from 'node:assert/strict';
const source=fileURLToPath(new URL('../',import.meta.url));
const root=await mkdtemp(join(source,'.native-test-'));
let processHandle;
const waitExit=p=>new Promise((resolve,reject)=>{p.once('exit',resolve);p.once('error',reject);});
try{
  await mkdir(join(root,'src'));
  await mkdir(join(root,'.runtime'));
  await writeFile(join(root,'.runtime/preferences.json'),JSON.stringify({cdpConsent:true,setupComplete:true}));
  await copyFile(join(source,'CodexMeter.exe'),join(root,'CodexMeter.exe'));
  await copyFile(join(source,'test/native-start.ps1'),join(root,'Start.ps1'));
  await copyFile(join(source,'test/native-monitor.mjs'),join(root,'src/cli.mjs'));
  await writeFile(join(root,'fixture.json'),JSON.stringify({node:process.execPath}));
  processHandle=spawn(join(root,'CodexMeter.exe'),[],{windowsHide:true,stdio:'ignore'});
  const exited=waitExit(processHandle);
  let state;
  for(let n=0;n<80;n++){
    state=await readFile(join(root,'.runtime/background.json'),'utf8').then(s=>JSON.parse(s.replace(/^\uFEFF/,''))).catch(()=>null);
    if(state?.stage==='running')break;
    if(processHandle.exitCode!==null)throw new Error('Native host exited before its monitor started.');
    await delay(250);
  }
  assert.equal(state?.host,'native');assert.equal(state?.stage,'running');
  assert.ok(state.workingSetBytes>0);assert.ok(state.nodeWorkingSetBytes>0);
  const previousPid=state.monitorPid;
  const reconnect=spawn(join(root,'CodexMeter.exe'),['--reconnect'],{windowsHide:true,stdio:'ignore'});
  assert.equal(await waitExit(reconnect),0);
  for(let n=0;n<100;n++){
    await delay(250);
    state=await readFile(join(root,'.runtime/background.json'),'utf8').then(s=>JSON.parse(s.replace(/^\uFEFF/,''))).catch(()=>null);
    if(state?.stage==='running'&&state.monitorPid!==previousPid)break;
  }
  assert.equal(state?.stage,'running');assert.notEqual(state.monitorPid,previousPid,'Reconnect must replace owned monitor without stopping tray');
  const stop=spawn(join(root,'CodexMeter.exe'),['--stop'],{windowsHide:true,stdio:'ignore'});
  assert.equal(await waitExit(stop),0);
  const code=await Promise.race([exited,delay(15000).then(()=>{throw new Error('Native stop timed out');})]);
  assert.equal(code,0);
  console.log(`PASS: native tray -> transient PowerShell -> direct Node -> graceful stop; fixture working sets ${state.workingSetBytes}/${state.nodeWorkingSetBytes} bytes (not production benchmark)`);
}finally{
  if(processHandle?.exitCode===null){await writeFile(join(root,'.runtime/background-stop.request'),'stop').catch(()=>{});await delay(5000);}
  if(processHandle?.exitCode!==null)await rm(root,{recursive:true,force:true});
}
