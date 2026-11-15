import {spawnSync} from 'node:child_process';
import {readFile,writeFile,mkdir,unlink,open,stat} from 'node:fs/promises';
import {homedir} from 'node:os';
import {join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import net from 'node:net';
import {setTimeout as delay} from 'node:timers/promises';

const root=dirname(dirname(fileURLToPath(import.meta.url)));
const nativeUI=process.argv.includes('--native-ui');
const focusOnly=process.argv.includes('--focus');
const runtime=join(root,'.runtime'),lock=join(runtime,'mac.pid'),stop=join(runtime,'background-stop.request');
const run=(file,args)=>{
  const r=spawnSync(file,args,{encoding:'utf8',timeout:15000,maxBuffer:1024*1024});
  if(r.error || r.status!==0)throw new Error(`Local command failed: ${file}`);
  return r.stdout.trim();
};
const plist=(app,key)=>run('/usr/libexec/PlistBuddy',['-c',`Print :${key}`,join(app,'Contents/Info.plist')]);
let ownsLock=false;
try {
  if(process.platform!=='darwin' || process.arch!=='arm64')throw new Error('This package requires Apple Silicon macOS.');
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
  for(const candidate of ['/Applications/Codex.app',join(homedir(),'Applications/Codex.app')]){
    if(await stat(candidate).catch(()=>null)){app=candidate;break;}
  }
  if(!app)throw new Error('Install the official Codex.app in /Applications first.');
  if(plist(app,'CFBundleIdentifier')!=='com.openai.codex')throw new Error('Unexpected Codex bundle identifier; no application was launched.');
  const trust=JSON.parse(await readFile(new URL('./trust.json',import.meta.url),'utf8'));
  if(!/^[A-Z0-9]{10}$/.test(trust.teamIdentifier||''))throw new Error('Mac acceptance is pending: verify the official signing Team ID before enabling this experimental launcher.');
  run('/usr/bin/codesign',['--verify','--deep','--strict','-R',`anchor apple generic and identifier "com.openai.codex" and certificate leaf[subject.OU] = "${trust.teamIdentifier}"`,app]);
  if(focusOnly){run('/usr/bin/open',['-a',app]);process.exit(0);}
  const executable=plist(app,'CFBundleExecutable');
  if(!/^[\w .-]+$/.test(executable))throw new Error('Invalid app executable.');
  const main=join(app,'Contents/MacOS',executable);
  const cli=join(app,'Contents/Resources/codex');
  if(!(await stat(cli).catch(()=>null))?.isFile())throw new Error('Bundled Codex CLI not found.');
  const processes=()=>run('/bin/ps',['-axo','pid=,command=']).split('\n').map(line=>{
    const match=line.trim().match(/^(\d+)\s+(.+)$/);return match?{pid:Number(match[1]),cmd:match[2]}:null;
  }).filter(p=>p&&(p.cmd===main || p.cmd.startsWith(main+' ')));
  let running=processes(),port;
  if(running.length){
    const ports=[...new Set(running.map(p=>Number(p.cmd.match(/--remote-debugging-port(?:=|\s+)(\d+)/)?.[1])).filter(Boolean))];
    if(ports.length!==1)throw new Error('Save your work, fully Quit Codex, then open Codex Meter again. This tool will not close Codex for you.');
    port=ports[0];
  }else{
    const server=net.createServer();await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
    port=server.address().port;await new Promise(resolve=>server.close(resolve));
    run('/usr/bin/open',['-a',app,'--args','--remote-debugging-address=127.0.0.1',`--remote-debugging-port=${port}`]);
  }
  if(!Number.isInteger(port)||port<1024||port>65535)throw new Error('Invalid debug port.');
  let verified=false;
  for(let i=0;i<30;i++){
    running=processes();
    const listeners=spawnSync('/usr/sbin/lsof',['-nP',`-iTCP:${port}`,'-sTCP:LISTEN','-Fpnc'],{encoding:'utf8',timeout:5000});
    let pid=0;const owners=[];
    for(const line of (listeners.stdout||'').split('\n')){if(line.startsWith('p'))pid=Number(line.slice(1));if(line.startsWith('n'))owners.push({pid,address:line.slice(1)});}
    if(owners.length){
      if(owners.some(o=>!running.some(p=>p.pid===o.pid)||!['127.0.0.1:'+port,'[::1]:'+port].includes(o.address)))throw new Error('Debug listener is not owned by the verified Codex process on loopback.');
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
  if(!nativeUI)spawnSync('/usr/bin/osascript',['-e','on run argv','-e','display alert "Codex Quota Sidebar" message (item 1 of argv)','-e','end run',e.message],{timeout:120000});
}finally{if(ownsLock)await unlink(lock).catch(()=>{});}
