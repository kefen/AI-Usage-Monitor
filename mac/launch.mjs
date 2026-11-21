import {spawnSync} from 'node:child_process';
import {readFile,writeFile,mkdir,unlink,open,stat} from 'node:fs/promises';
import {homedir} from 'node:os';
import {join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import net from 'node:net';
import {setTimeout as delay} from 'node:timers/promises';
import {parseListeners,verifyListenerOwners} from './listener-policy.mjs';

const root=dirname(dirname(fileURLToPath(import.meta.url)));
const nativeUI=process.argv.includes('--native-ui');
const focusOnly=process.argv.includes('--focus');
const restartApproved=process.argv.includes('--restart-approved');
const runtime=join(root,'.runtime'),lock=join(runtime,'mac.pid'),stop=join(runtime,'background-stop.request');
const run=(file,args,timeout=15000)=>{
  const r=spawnSync(file,args,{encoding:'utf8',timeout,maxBuffer:1024*1024});
  if(r.error || r.status!==0)throw new Error(`Local command failed: ${file}`);
  return r.stdout.trim();
};
const plist=(app,key)=>run('/usr/libexec/PlistBuddy',['-c',`Print :${key}`,join(app,'Contents/Info.plist')]);
let ownsLock=false;
try {
  if(process.platform!=='darwin' || !['arm64','x64'].includes(process.arch))throw new Error('This package requires Intel or Apple Silicon macOS.');
  await mkdir(runtime,{recursive:true});
  if(process.argv.includes('--stop')){await writeFile(stop,'stop');process.exit(0);}
  if(!focusOnly){try{
    const pid=Number((await readFile(lock,'utf8')).trim());
    if(Number.isSafeInteger(pid)&&pid>1){try{process.kill(pid,0);process.exit(0);}catch(e){if(e.code!=='ESRCH')throw e;}}
    await unlink(lock);
  }catch(e){if(e.code!=='ENOENT')throw e;}
  const fd=await open(lock,'wx');await fd.writeFile(String(process.pid));await fd.close();ownsLock=true;
  await unlink(stop).catch(e=>{if(e.code!=='ENOENT')throw e;});
  }
  let app;
  for(const candidate of ['/Applications/Codex.app','/Applications/ChatGPT.app',join(homedir(),'Applications/Codex.app'),join(homedir(),'Applications/ChatGPT.app')]){
    if(await stat(candidate).catch(()=>null)){
      try{if(plist(candidate,'CFBundleIdentifier')==='com.openai.codex'){app=candidate;break;}}catch{}
    }
  }
  if(!app)throw new Error('Install the official Codex.app in /Applications first.');
  if(plist(app,'CFBundleIdentifier')!=='com.openai.codex')throw new Error('Unexpected Codex bundle identifier; no application was launched.');
  const trust=JSON.parse(await readFile(new URL('./trust.json',import.meta.url),'utf8'));
  if(!/^[A-Z0-9]{10}$/.test(trust.teamIdentifier||''))throw new Error('Mac acceptance is pending: verify the official signing Team ID before enabling this experimental launcher.');
  run('/usr/bin/codesign',['--verify','--deep','--strict','-R',`=anchor apple generic and identifier "com.openai.codex" and certificate leaf[subject.OU] = "${trust.teamIdentifier}"`,app],60000);
  if(focusOnly){run('/usr/bin/open',['-a',app]);process.exit(0);}
  const executable=plist(app,'CFBundleExecutable');
  if(!/^[\w .-]+$/.test(executable))throw new Error('Invalid app executable.');
  const main=join(app,'Contents/MacOS',executable);
  let cli;
  for(const path of ['Contents/Resources/codex','Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex']){
    const candidate=join(app,path);
    if((await stat(candidate).catch(()=>null))?.isFile()){cli=candidate;break;}
  }
  if(!cli)throw new Error('Bundled Codex CLI not found.');
  const processes=()=>run('/bin/ps',['-ww','-axo','pid=,command=']).split('\n').map(line=>{
    const match=line.trim().match(/^(\d+)\s+(.+)$/);return match?{pid:Number(match[1]),cmd:match[2]}:null;
  }).filter(p=>p&&(p.cmd===main || p.cmd.startsWith(main+' ')));
  let running=processes(),port;
  if(running.length){
    const existing=[...new Set(running.map(p=>Number(p.cmd.match(/--remote-debugging-port(?:=|\s+)(\d+)/)?.[1])).filter(Boolean))];
    if(existing.length!==1){
      if(!restartApproved)throw new Error('E_RESTART_REQUIRED');
      // Ask the verified app to quit normally; cancellation and unsaved work are never overridden.
      try{run('/usr/bin/osascript',['-e','on run argv','-e','tell application (item 1 of argv) to quit','-e','end run',app],90000);}
      catch{throw new Error('E_QUIT_CANCELLED');}
      for(let i=0;i<30&&processes().length;i++)await delay(1000);
      running=processes();
      if(running.length)throw new Error('E_QUIT_CANCELLED');
    }
  }
  if(running.length){
    const ports=[...new Set(running.map(p=>Number(p.cmd.match(/--remote-debugging-port(?:=|\s+)(\d+)/)?.[1])).filter(Boolean))];
    if(ports.length!==1)throw new Error('E_RESTART_REQUIRED');
    port=ports[0];
  }else{
    const server=net.createServer();await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
    port=server.address().port;await new Promise(resolve=>server.close(resolve));
    run('/usr/bin/open',['-a',app,'--args','--remote-debugging-address=127.0.0.1',`--remote-debugging-port=${port}`]);
  }
  if(!Number.isInteger(port)||port<1024||port>65535)throw new Error('Invalid debug port.');
  const helperApp=join(homedir(),'.codex/computer-use/Codex Computer Use.app');
  const helperExecutable=join(helperApp,'Contents/MacOS/SkyComputerUseService');
  const inspectProcess=pid=>{
    const value=run('/bin/ps',['-ww','-p',String(pid),'-o','ppid=,comm=']);
    const match=value.match(/^\s*(\d+)\s+(.+)$/);
    return match?{parentPid:Number(match[1]),executable:match[2]}:null;
  };
  const verifyHelper=()=>{
    if(plist(helperApp,'CFBundleIdentifier')!=='com.openai.sky.CUAService' || plist(helperApp,'CFBundleExecutable')!=='SkyComputerUseService')return false;
    run('/usr/bin/codesign',['--verify','--deep','--strict','-R',`=anchor apple generic and identifier "com.openai.sky.CUAService" and certificate leaf[subject.OU] = "${trust.teamIdentifier}"`,helperApp],60000);
    return true;
  };
  let verified=false;
  for(let i=0;i<30;i++){
    const listeners=spawnSync('/usr/sbin/lsof',['-nP',`-iTCP:${port}`,'-sTCP:LISTEN','-Fpnc'],{encoding:'utf8',timeout:5000});
    if(listeners.error || ![0,1].includes(listeners.status))throw new Error('E_CDP_QUERY');
    const owners=parseListeners(listeners.stdout||'');
    running=processes();
    if(owners.length){
      const checked=await verifyListenerOwners({owners,mainPids:running.map(p=>p.pid),port,helperExecutable,inspectProcess,verifyHelper});
      if(!checked.ok)throw new Error(checked.code);
      verified=true;break;
    }
    await delay(1000);
  }
  if(!verified)throw new Error('Codex debug listener was not found.');
  process.argv=[process.execPath,join(root,'src/cli.mjs'),'attach','--port',String(port),'--codex',cli,'--stop-file',stop];
  await import('../src/cli.mjs');
}catch(e){
  console.error(e.message);process.exitCode=1;
  await writeFile(join(runtime,'mac-error.txt'),e.message).catch(()=>{});
  if(!nativeUI)spawnSync('/usr/bin/osascript',['-e','on run argv','-e','display alert "AI Quota Board" message (item 1 of argv)','-e','end run',e.message],{timeout:120000});
}finally{if(ownsLock)await unlink(lock).catch(()=>{});}
