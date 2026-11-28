// Disposable hosted runners only. Neither QA keys nor this fixture ship in the update.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import {execFileSync,spawn} from 'node:child_process';
import {createHash,generateKeyPairSync,sign,randomBytes} from 'node:crypto';
import {setTimeout as sleep} from 'node:timers/promises';
assert.equal(process.env.GITHUB_ACTIONS,'true');
assert.ok(process.env.RUNNER_TEMP);
const mac=process.platform==='darwin', v='0.16.17', file=path.resolve(process.argv[2]), bytes=fs.readFileSync(file), prior=path.resolve(process.argv[3]);
const root=mac?path.join(os.homedir(),'Applications','AI Usage Monitor.app'):path.join(process.env.LOCALAPPDATA,'Programs','AI Usage Monitor');
const resources=path.join(root,mac?'Contents/Resources/app':'resources/app'),exe=path.join(root,mac?'Contents/MacOS/Electron':'AI Usage Monitor.exe');
const tmp=fs.mkdtempSync(path.join(process.env.RUNNER_TEMP,'upgrade-')),profile=path.join(mac?path.join(os.homedir(),'Library/Application Support'):process.env.APPDATA,'AI-Usage-Monitor-Demo8-QA-r13','local');
assert.ok(!fs.existsSync(root)&&!fs.existsSync(profile),'clean test user required');
const run=(bin,args)=>execFileSync(bin,args,{encoding:'utf8',stdio:['ignore','pipe','pipe'],timeout:90000});
const wait=async(fn,limit=90000)=>{const end=Date.now()+limit;let error;while(Date.now()<end){try{const r=await fn();if(r)return r;}catch(e){error=e;}await sleep(300);}throw Error('Timed out: '+fn+' '+(error??''));};
fs.mkdirSync(path.dirname(root),{recursive:true});
if(mac){
  const mount=path.join(tmp,'mount');fs.mkdirSync(mount);run('hdiutil',['attach','-readonly','-nobrowse','-mountpoint',mount,prior]);
  try{run('ditto',[path.join(mount,path.basename(root)),root]);}finally{run('hdiutil',['detach',mount]);}
}else run(prior,['--test-install',root]);
const pkg=path.join(resources,'package.json'),original=JSON.parse(fs.readFileSync(pkg));assert.equal(original.version,'0.16.16');
const {publicKey,privateKey}=generateKeyPairSync('ed25519');
const digest=createHash('sha256').update(bytes).digest('hex');
const target=mac?'macos-'+process.arch:'windows-x64',url='https://github.com/kefen/AI-Usage-Monitor/releases/download/qa/'+path.basename(file);
const payload=Buffer.from(JSON.stringify({schema:1,expiresAt:Date.now()+1800000,releases:{[target]:{version:v,size:bytes.length,sha256:digest,url}}}));
const feed=JSON.stringify({payload:payload.toString('base64'),signature:sign(null,payload,privateKey).toString('base64')});
let downloads=0;
const server=http.createServer((req,res)=>{
  if(req.url==='/feed'){res.end(feed);return;}
  if(req.url==='/asset'){downloads++;res.writeHead(200,{'Content-Length':bytes.length});fs.createReadStream(file).pipe(res);return;}
  res.writeHead(404);res.end();
});
await new Promise(ok=>server.listen(0,'127.0.0.1',ok));
const port=server.address().port;
// A pre-updater public client cannot initiate this transaction. Instrument only the SOURCE
// fixture: route requests to the isolated HTTP server and answer the native confirmation.
fs.writeFileSync(path.join(resources,'src/update-public-key.pem'),publicKey.export({format:'pem',type:'spki'}));
const entry=path.join(resources,'desktop/demo8/main.mjs');
fs.writeFileSync(entry,"import './qa-only.mjs';\n"+fs.readFileSync(entry,'utf8'));
fs.writeFileSync(path.join(path.dirname(entry),'qa-only.mjs'),`
import {dialog} from 'electron';import fs from 'node:fs';
const net=globalThis.fetch;globalThis.fetch=(url,opts)=>net(String(url).endsWith('/desktop.json')?'http://127.0.0.1:${port}/feed':String(url)===${JSON.stringify(url)}?'http://127.0.0.1:${port}/asset':url,opts);
const orig=dialog.showMessageBox.bind(dialog);dialog.showMessageBox=(...args)=>{
  if(args.at(-1).detail==='0.16.16 → 0.16.17'){fs.writeFileSync(${JSON.stringify(path.join(tmp,'confirmed'))},'yes');return Promise.resolve({response:0});}
  return orig(...args);
};`);
if(mac)run('codesign',['--force','--sign','-',root]);
const session=()=>spawn(exe,['--remote-debugging-port=19276'],{stdio:'ignore'});
async function evaluate(expr){
  const pages=await (await fetch('http://127.0.0.1:19276/json/list')).json(),p=pages.find(p=>p.url.startsWith('aum-preview:')&&p.url.includes('frosted.html'));
  if(!p)return null;
  const ws=new WebSocket(p.webSocketDebuggerUrl);
  return new Promise((ok,no)=>{const stop=setTimeout(()=>{ws.close();no(Error('CDP timeout'));},5000);
    ws.onopen=()=>ws.send(JSON.stringify({id:1,method:'Runtime.evaluate',params:{expression:expr,returnByValue:true}}));
    ws.onmessage=({data})=>{const m=JSON.parse(data);if(m.id===1){clearTimeout(stop);ws.close();if(m.result?.exceptionDetails)no(Error('renderer evaluation failed'));else ok(m.result?.result?.value);}};ws.onerror=no;
  });
}
const prefs='aum-dual-v2-preferences',stamp=randomBytes(8).toString('hex');
const alive=pid=>{try{process.kill(pid,0);return true;}catch{return false;}};
const readActive=()=>JSON.parse(fs.readFileSync(path.join(profile,'active-build.json')));
try{
  const old=session();await wait(()=>evaluate("!!document.querySelector('.app-main h1')"));
  assert.equal(await evaluate(`(()=>{const k='${prefs}',p=JSON.parse(localStorage.getItem(k)||'{}');Object.assign(p,{language:'en',glass:65});localStorage.setItem(k,JSON.stringify(p));localStorage.setItem('qa-history','${stamp}');return true})()`),true);
  await evaluate("void window.aumDesktop.checkUpdates().then(r=>console.log('check',r));true");
  await wait(()=>fs.existsSync(path.join(tmp,'confirmed')));
  const cache=fs.readFileSync(path.join(profile,'desktop-update-cache',mac?'update.dmg':'update.exe'));
  assert.equal(createHash('sha256').update(cache).digest('hex'),digest);assert.equal(downloads,1);
  console.log('Downloaded full candidate; signed feed, payload digest and restart confirmation verified');
  await wait(()=>!alive(old.pid));
  const active=await wait(()=>{const a=readActive();return a.pid!==old.pid&&a.version===v&&alive(a.pid)&&!fs.existsSync(path.join(path.dirname(entry),'qa-only.mjs'))&&a;});
  if(mac)await wait(()=>!fs.readdirSync(path.dirname(root)).some(n=>n.startsWith('.aum-update-')));
  else await wait(()=>Number(run('powershell',['-NoProfile','-Command',`(Get-Process -Id ${active.pid}).MainWindowHandle.ToInt64()`]).trim())>0);
  console.log('Installer relaunched candidate and opened workspace, PID',active.pid);
  process.kill(active.pid);await wait(()=>!alive(active.pid));await sleep(1200);
  session();await wait(()=>evaluate("!!document.querySelector('.app-main h1')"));
  const after=await evaluate(`[JSON.parse(localStorage.getItem('${prefs}')).language,JSON.parse(localStorage.getItem('${prefs}')).glass,localStorage.getItem('qa-history'),document.querySelector('.sidebar-version strong').textContent.trim()]`);
  assert.deepEqual(after,['en',65,stamp,v]);
  await evaluate('setTimeout(()=>window.aumDesktop.quit(),100);true');await wait(()=>!fs.existsSync(path.join(profile,'active-build.json')));
  console.log('Preferences and storage marker survived restart');
  for(let i=0;i<2;i++){
    const result=run(exe,['--profile=dock-qa-'+i,'--tray-test','--dock-lifecycle-test']);
    assert.match(result,/all four edges passed/);
    console.log(result);
  }
  if(mac){
    const stage=fs.mkdtempSync(path.join(path.dirname(root),'.aum-update-')),nonce=randomBytes(24).toString('hex');
    fs.writeFileSync(path.join(stage,'expected'),v+':'+nonce);
    fs.copyFileSync(path.join(path.dirname(entry),'replace-mac.sh'),path.join(stage,'replace.sh'));
    const fake=path.join(stage,'next.app/Contents/MacOS/Electron');fs.mkdirSync(path.dirname(fake),{recursive:true});
    fs.writeFileSync(fake,'#!/bin/sh\nexit 1\n',{mode:0o755});
    const dead=spawn('/usr/bin/true');await new Promise(ok=>dead.once('exit',ok));
    const helper=spawn('/bin/sh',[path.join(stage,'replace.sh'),String(dead.pid),root,stage,v,nonce],{stdio:'inherit'});
    assert.equal(await new Promise(ok=>helper.once('exit',ok)),1);
    assert.ok(fs.existsSync(path.join(stage,'failed.app')));
    await wait(()=>alive(readActive().pid));assert.equal(JSON.parse(fs.readFileSync(pkg)).version,v);
    console.log('Failed candidate restored prior bundle and relaunched it');
  }
}finally{server.close();server.closeAllConnections();}
process.exit(0);
