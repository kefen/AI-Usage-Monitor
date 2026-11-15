import {spawn} from 'node:child_process';
import {mkdtemp,readFile,rm} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const source=fileURLToPath(new URL('../',import.meta.url));
const temp=await mkdtemp(join(source,'.package-test-'));
async function run(command,args){
  const env={...process.env};delete env.PSModulePath;
  const p=spawn(command,args,{env,windowsHide:true,stdio:['ignore','pipe','pipe']});
  let output='';p.stdout.on('data',s=>output+=s);p.stderr.on('data',s=>output+=s);
  const code=await new Promise((resolve,reject)=>{p.once('exit',resolve);p.once('error',reject);});
  assert.equal(code,0,output);return output;
}
try{
  const extracted=join(temp,'extracted');
  const {windows}=JSON.parse(await readFile(join(source,'versions.json'),'utf8'));
  await run(join(source,`dist/Codex-Quota-Sidebar-Windows-${windows}-x64-Setup.exe`),['--extract',extracted]);
  const manifest=JSON.parse(await readFile(join(extracted,'FILE-HASHES.json'),'utf8'));
  for(const [name,expected] of Object.entries(manifest)){
    assert.ok(!name.includes('.runtime')&&!/auth\.json|membership\.json|\.log$/.test(name));
    assert.equal(createHash('sha256').update(await readFile(join(extracted,name))).digest('hex'),expected);
  }
  const ps=join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe');
  await run(ps,['-NoProfile','-ExecutionPolicy','Bypass','-File',join(extracted,'Install.ps1'),'-Destination',join(temp,'installed'),'-ShortcutPath',join(temp,'meter.lnk')]);
  await run(ps,['-NoProfile','-ExecutionPolicy','Bypass','-File',join(temp,'installed/Uninstall.ps1')]);
  console.log(`PASS: actual Setup.exe extraction, ${Object.keys(manifest).length} hashes, install and uninstall; no personal runtime data`);
}finally{await rm(temp,{recursive:true,force:true});}
