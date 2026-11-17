import {openSync, closeSync, readSync, writeFileSync, fsyncSync, lstatSync, fstatSync, constants, mkdirSync, renameSync, unlinkSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {randomUUID} from 'node:crypto';
import {listTargets, evaluate} from './cdp.mjs';
import {validateTarget} from './core.mjs';
import {rendererExpression} from './renderer-expression.mjs';
import {canonicalEntry} from './update-transaction.mjs';

const MAX_BYTES=65536;
const families=new Set(['free','go','plus','pro','business','enterprise','edu']);
const fail=code=>{throw new Error(code);};
const errors=new Set(['E_USAGE','E_CONFIG_INVALID','E_CONFIG_CHANGED','E_BUSY','E_MANUAL_LOCK','E_ALREADY_ATTEMPTED','E_PLAN_UNKNOWN','E_DESKTOP_UNAVAILABLE','E_WRITE_FAILED']);

// Runs behind the unchanged renderer trust gate, with a stricter rail requirement.
// Never scan generic account names, conversation text, menus elsewhere, or shadows.
function accountPlan() {
  const plans=new Set();
  let invalid=false;
  const excluded=node=>node.closest('#local-codex-sidebar-meter, [data-cqs], [data-codex-meter], .plan-badge') || node.getRootNode().nodeType!==9;
  const accept=value=>{
    if(value===null)return;
    if(typeof value!=='string'||value.length>64){invalid=true;return;}
    const label=value.trim().toLowerCase().replace(/^chatgpt\s+/, '');
    if(['free','go','plus','pro','business','enterprise','edu'].includes(label))plans.add(label);
    else invalid=true;
  };
  const rails=document.querySelectorAll('aside.app-shell-left-panel [data-app-navigation-rail], aside[data-testid="app-shell-floating-left-panel"] [data-app-navigation-rail]');
  if(rails.length!==1)return {trusted:true};
  // Fallback is deliberately unknown: current clients may expose only profile
  // buttons with aria-haspopup/aria-label/id, not dedicated plan metadata.
  // Neither free-form ARIA descriptions nor undocumented React props prove a
  // plan family. Do not broaden this allowlist without verified field evidence.
  const controls=rails[0].querySelectorAll('[data-testid="account-menu-trigger"], [data-testid="profile-menu-trigger"], [data-testid="account-button"]');
  if(controls.length>8)return {trusted:true};
  for(const control of controls) {
    if(excluded(control))continue;
    accept(control.getAttribute('data-plan-type'));
    const labels=control.querySelectorAll('[data-testid="account-plan"], [data-testid="account-plan-label"], [data-testid="subscription-plan"]');
    if(labels.length>8)return {trusted:true};
    for(const label of labels)if(!excluded(label))accept(label.getAttribute('data-plan-type') ?? label.textContent);
  }
  return !invalid&&plans.size===1?{trusted:true,plan:[...plans][0]}:{trusted:true};
}

export function planExpression() {
  // Early return avoids installing a controller or calling its receive method.
  return rendererExpression(`return (${accountPlan.toString()})();`,{});
}

function readRecord(path, optional=false) {
  let fd;
  try {
    const stat=lstatSync(path);
    if(!stat.isFile()||stat.isSymbolicLink()||stat.size>MAX_BYTES)fail('E_CONFIG_INVALID');
    fd=openSync(path,constants.O_RDONLY|(constants.O_NOFOLLOW||0));
    const opened=fstatSync(fd);
    if(!opened.isFile()||opened.dev!==stat.dev||opened.ino!==stat.ino)fail('E_CONFIG_INVALID');
    const bytes=Buffer.alloc(MAX_BYTES+1);
    let size=0,n;
    while(size<bytes.length&&(n=readSync(fd,bytes,size,bytes.length-size,null))>0)size+=n;
    if(size>MAX_BYTES)fail('E_CONFIG_INVALID');
    const raw=new TextDecoder('utf-8',{fatal:true}).decode(bytes.subarray(0,size));
    const value=JSON.parse(raw);
    if(!value||typeof value!=='object'||Array.isArray(value))fail('E_CONFIG_INVALID');
    return {raw,value};
  } catch(error) {
    if(optional&&error.code==='ENOENT')return {raw:null,value:{}};
    fail('E_CONFIG_INVALID');
  } finally {if(fd!==undefined)closeSync(fd);}
}

function validateMember(value) {
  if(('plan' in value&&typeof value.plan!=='string') ||
    ('manualOverride' in value&&typeof value.manualOverride!=='boolean') ||
    ('planSource' in value&&!['desktop','manual'].includes(value.planSource)) ||
    ('detectedAt' in value&&(typeof value.detectedAt!=='string'||!Number.isFinite(Date.parse(value.detectedAt)))))fail('E_CONFIG_INVALID');
}
function manual(value, exists) {
  return value.manualOverride===true || value.planSource==='manual' ||
    (exists&&value.planSource!=='desktop') ||
    ('plan' in value && !(value.planSource==='desktop'&&value.manualOverride===false&&value.detectedAt));
}
function exclusive(path, value) {
  let fd;
  try {fd=openSync(path,'wx',0o600);writeFileSync(fd,JSON.stringify(value));fsyncSync(fd);}
  finally {if(fd!==undefined)closeSync(fd);}
}

export async function runPlan(command, root, api={}) {
  let lock,temp;
  try {
    if(!['auto','detect'].includes(command)||typeof root!=='string'||!root)fail('E_USAGE');
    const directory=resolve(root),runtime=join(directory,'.runtime');
    if(!lstatSync(directory).isDirectory()||lstatSync(directory).isSymbolicLink())fail('E_CONFIG_INVALID');
    mkdirSync(runtime,{recursive:true});
    if(!lstatSync(runtime).isDirectory()||lstatSync(runtime).isSymbolicLink())fail('E_CONFIG_INVALID');
    const path=join(runtime,'membership.json');
    try {exclusive(path+'.lock',{operation:'plan'});lock=path+'.lock';}
    catch(error){fail(error.code==='EEXIST'?'E_BUSY':'E_WRITE_FAILED');}
    const before=readRecord(path,true);validateMember(before.value);
    const attempted=join(runtime,'plan-auto-attempted.json');
    if(command==='auto') {
      if(manual(before.value,before.raw!==null))fail('E_MANUAL_LOCK');
      if(before.value.detectedAt)fail('E_ALREADY_ATTEMPTED');
      const prior=readRecord(attempted,true);
      if(prior.raw!==null) {
        if(typeof prior.value.attemptedAt!=='string'||!Number.isFinite(Date.parse(prior.value.attemptedAt)))fail('E_CONFIG_INVALID');
        fail('E_ALREADY_ATTEMPTED');
      }
    }
    let plan,queried=false;
    try {
      const {port}=readRecord(join(runtime,'status.json')).value;
      if(!Number.isInteger(port)||port<1024||port>65535)fail('E_DESKTOP_UNAVAILABLE');
      const targets=await (api.listTargets||listTargets)(port);
      if(!Array.isArray(targets)||targets.length>64)fail('E_DESKTOP_UNAVAILABLE');
      const found=new Set();let unknown=false;
      for(const target of targets) {
        if(!validateTarget(target,port))continue;
        // HTTPS, CLI views and fixture file frames are not desktop main pages.
        if(new URL(target.url).protocol!=='app:')continue;
        const result=await (api.evaluate||evaluate)(target,port,planExpression());
        if(result?.trusted!==true)continue;
        queried=true;
        if(families.has(result.plan))found.add(result.plan);else unknown=true;
      }
      if(!unknown&&found.size===1)plan=[...found][0];
    } catch {fail('E_DESKTOP_UNAVAILABLE');}
    if(!queried)fail('E_DESKTOP_UNAVAILABLE');
    // Startup transport failures must not consume auto. Commit only after a
    // trusted renderer responds (even unknown), with the membership lock held.
    if(readRecord(path,true).raw!==before.raw)fail('E_CONFIG_CHANGED');
    if(command==='auto') {
      try {exclusive(attempted,{attemptedAt:new Date().toISOString()});}
      catch(error){fail(error.code==='EEXIST'?'E_ALREADY_ATTEMPTED':'E_WRITE_FAILED');}
    }
    if(!plan)fail('E_PLAN_UNKNOWN');
    const next={...before.value,plan,planSource:'desktop',manualOverride:false,detectedAt:new Date().toISOString()};
    const serialized=JSON.stringify(next);
    if(Buffer.byteLength(serialized)>MAX_BYTES)fail('E_CONFIG_INVALID');
    temp=path+'.'+randomUUID()+'.tmp';
    exclusive(temp,next);
    // No await between compare and rename: edits made while CDP was running win.
    // Native writers should honor membership.json.lock for cross-process exclusion.
    if(readRecord(path,true).raw!==before.raw)fail('E_CONFIG_CHANGED');
    renameSync(temp,path);temp=undefined;
    return {detected:true,plan};
  } catch(error) {
    return {detected:false,error:errors.has(error.message)?error.message:'E_WRITE_FAILED'};
  } finally {
    if(temp)try{unlinkSync(temp);}catch{}
    if(lock)try{unlinkSync(lock);}catch{}
  }
}

if(canonicalEntry(process.argv[1],import.meta.url)) {
  const [command,root,...rest]=process.argv.slice(2);
  console.log(JSON.stringify(rest.length?{detected:false,error:'E_USAGE'}:await runPlan(command,root)));
}
