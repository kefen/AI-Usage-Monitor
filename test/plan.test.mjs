import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {planExpression, runPlan} from '../src/plan.mjs';
import {canonicalEntry} from '../src/update-transaction.mjs';

const target={id:'main',type:'page',url:'app://-/index.html',webSocketDebuggerUrl:'ws://127.0.0.1:9222/devtools/page/main'};
function fixture(t, member) {
  const root=mkdtempSync(join(tmpdir(),'cqs-plan-'));
  t.after(()=>rmSync(root,{recursive:true,force:true}));
  mkdirSync(join(root,'.runtime'));
  writeFileSync(join(root,'.runtime/status.json'),JSON.stringify({port:9222}));
  const path=join(root,'.runtime/membership.json');
  if(member!==undefined)writeFileSync(path,JSON.stringify(member));
  return {root,path,read:()=>JSON.parse(readFileSync(path,'utf8'))};
}
function node(label, {own=false, attribute=null}={}) {
  return {textContent:label,getAttribute:key=>key==='data-plan-type'?attribute:null,
    closest:selector=>selector.includes('local-codex-sidebar-meter')&&own?{}:null,
    getRootNode:()=>({nodeType:9})};
}
function dom(labels, {protocol='app:',shell=true,own=false}={}) {
  const controls=labels.map(label=>({ ...node('',{own}),
    querySelectorAll:()=>[node(label,{own})] }));
  const rail={querySelectorAll:()=>controls};
  return {location:{protocol},window:{},document:{querySelector:selector=>
    shell&&selector.includes('sidebar-navigation')?{}:null,
    querySelectorAll:selector=>shell&&selector.includes('data-app-navigation-rail')?[rail]:[]}};
}
const io=(plan='pro')=>({listTargets:async()=>[target],evaluate:async()=>({trusted:true,plan})});

test('structured account plan labels pass the existing main renderer gate',()=>{
  const result=vm.runInNewContext(planExpression(),dom(['ChatGPT Pro']));
  assert.equal(result.plan,'pro');assert.equal(result.trusted,true);
});
test('dedicated account metadata works without reading a profile name',()=>{
  const context=dom([]);
  const control={...node('',{attribute:'plus'}),querySelectorAll:()=>[]};
  Object.defineProperty(control,'textContent',{get(){throw Error('profile name must not be read');}});
  context.document.querySelectorAll=()=>[{querySelectorAll:()=>[control]}];
  assert.equal(vm.runInNewContext(planExpression(),context).plan,'plus');
});
test('semantic-only profile controls have an explicit unknown fallback, without reading ARIA text or React props',()=>{
  const controls=[0,1].map(index=>({
    ...node(''),
    getAttribute:key=>{
      if(key==='aria-description')throw Error('unverified description read');
      return {'aria-haspopup':'menu','aria-label':'Account',id:'profile-'+index}[key]??null;
    },
    querySelectorAll:()=>[]
  }));
  for(const control of controls) {
    Object.defineProperty(control,'textContent',{get(){throw Error('generic rail text read');}});
    Object.defineProperty(control,'__reactProps$fixture',{enumerable:true,get(){throw Error('unverified React props read');}});
  }
  const context=dom([]);
  context.document.querySelectorAll=()=>[{querySelectorAll:selector=>
    selector.includes('data-testid')?[]:controls}];
  const result=vm.runInNewContext(planExpression(),context);
  assert.equal(result.trusted,true);assert.equal(result.plan,undefined);
});
test('own badges, ambiguous labels and unrecognized renderers stay unknown',()=>{
  for(const context of [dom(['Pro'],{own:true}),dom(['Pro','Plus']),dom(['Pro','Pro $200']),dom(['Pro $200']),dom(['Pro'],{protocol:'https:'}),dom(['Pro'],{shell:false})]) {
    assert.equal(vm.runInNewContext(planExpression(),context).plan,undefined);
  }
});
test('no body text, storage, account RPC or injected widget is read',()=>{
  const expression=planExpression();
  assert.doesNotMatch(expression,/document\.body|innerHTML|localStorage|sessionStorage|fetch\(|\.click\(|shadowRoot/);
  const context=dom([]);Object.defineProperty(context.document,'body',{get(){throw Error('chat read');}});
  assert.equal(vm.runInNewContext(expression,context).plan,undefined);
  const retained=dom(['Pro'],{shell:false});
  retained.window.__localCodexMeter={controllerId:'local-codex-sidebar-meter-v1'};
  assert.equal(vm.runInNewContext(expression,retained).plan,undefined);
});
test('auto detects once and persists desktop provenance',async t=>{
  const f=fixture(t);assert.deepEqual(await runPlan('auto',f.root,io()),{detected:true,plan:'pro'});
  assert.equal(f.read().planSource,'desktop');assert.equal(f.read().manualOverride,false);
  assert.ok(f.read().detectedAt);
  assert.deepEqual(await runPlan('auto',f.root,{listTargets:()=>{throw Error('must not run');}}),{detected:false,error:'E_ALREADY_ATTEMPTED'});
});
test('unknown first attempt is persistent and leaves membership untouched',async t=>{
  const f=fixture(t);
  assert.deepEqual(await runPlan('auto',f.root,io(null)),{detected:false,error:'E_PLAN_UNKNOWN'});
  assert.equal(existsSync(f.path),false);
  assert.equal((await runPlan('auto',f.root,io())).error,'E_ALREADY_ATTEMPTED');
});
test('unavailable infrastructure leaves auto retryable until a trusted main renderer responds',async t=>{
  const cases=[
    f=>{rmSync(join(f.root,'.runtime/status.json'));return io();},
    f=>{writeFileSync(join(f.root,'.runtime/status.json'),JSON.stringify({port:0}));return io();},
    f=>{writeFileSync(join(f.root,'.runtime/status.json'),'{');return io();},
    ()=>({...io(),listTargets:async()=>{throw Error('starting');}}),
    ()=>({...io(),listTargets:async()=>[]}),
    ()=>({...io(),listTargets:async()=>[{...target,url:'https://chatgpt.com/'}]}),
    ()=>({...io(),evaluate:async()=>({mounted:false,reason:'not-main-shell'})}),
    ()=>({...io(),evaluate:async()=>{throw Error('renderer starting');}})
  ];
  for(const setup of cases) {
    const f=fixture(t),marker=join(f.root,'.runtime/plan-auto-attempted.json');
    assert.deepEqual(await runPlan('auto',f.root,setup(f)),{detected:false,error:'E_DESKTOP_UNAVAILABLE'});
    assert.equal(existsSync(marker),false);assert.equal(existsSync(f.path),false);
    assert.equal(existsSync(f.path+'.lock'),false);
    writeFileSync(join(f.root,'.runtime/status.json'),JSON.stringify({port:9222}));
    assert.deepEqual(await runPlan('auto',f.root,io()),{detected:true,plan:'pro'});
    assert.equal(existsSync(marker),true);
  }
});
test('lock spans desktop awaits but the attempt marker waits for a legitimate unknown response',async t=>{
  const f=fixture(t),marker=join(f.root,'.runtime/plan-auto-attempted.json');
  const result=await runPlan('auto',f.root,{...io(),evaluate:async()=>{
    assert.equal(existsSync(f.path+'.lock'),true);assert.equal(existsSync(marker),false);
    assert.equal((await runPlan('auto',f.root,io())).error,'E_BUSY');
    return {trusted:true};
  }});
  assert.deepEqual(result,{detected:false,error:'E_PLAN_UNKNOWN'});
  assert.equal(existsSync(marker),true);
  assert.equal((await runPlan('auto',f.root,io())).error,'E_ALREADY_ATTEMPTED');
});
test('manual changes during auto evaluation prevent both persistence and attempt consumption',async t=>{
  const f=fixture(t),manual={plan:'plus',planSource:'manual',manualOverride:true};
  assert.equal((await runPlan('auto',f.root,{...io(),evaluate:async()=>{
    writeFileSync(f.path,JSON.stringify(manual));return {trusted:true};
  }})).error,'E_CONFIG_CHANGED');
  assert.deepEqual(f.read(),manual);
  assert.equal(existsSync(join(f.root,'.runtime/plan-auto-attempted.json')),false);
});
test('legacy and manual records cannot be replaced by auto',async t=>{
  for(const member of [{plan:'plus'},{tier:'200'},{date:'2027-01-01'},{}, {plan:'plus',planSource:'manual'}, {planSource:'desktop',manualOverride:true}, {plan:'pro',planSource:'desktop'}]) {
    const f=fixture(t,member);
    assert.deepEqual(await runPlan('auto',f.root,{listTargets:()=>{throw Error('must not run');}}),{detected:false,error:'E_MANUAL_LOCK'});
    assert.deepEqual(f.read(),member);
  }
});
test('explicit detection replaces only family and provenance, never dates or price tier',async t=>{
  const member={plan:'plus',planSource:'manual',manualOverride:true,date:'2027-02-03',purchaseDate:'2026-11-03',tier:'200',enabled:true,custom:{x:1}};
  const f=fixture(t,member);
  assert.deepEqual(await runPlan('detect',f.root,io()),{detected:true,plan:'pro'});
  const saved=f.read();for(const key of ['date','purchaseDate','tier','enabled','custom'])assert.deepEqual(saved[key],member[key]);
  assert.equal(saved.manualOverride,false);assert.equal(saved.planSource,'desktop');
});
test('conflicting targets and untrusted targets are rejected',async t=>{
  const f=fixture(t,{date:'2027-01-01'});
  assert.equal((await runPlan('detect',f.root,{listTargets:async()=>[target,{...target,id:'other'}],evaluate:async t=>({trusted:true,plan:t.id==='main'?'pro':'plus'})})).error,'E_PLAN_UNKNOWN');
  assert.equal((await runPlan('detect',f.root,{listTargets:async()=>[{...target,url:'https://evil.example'}],evaluate:()=>{throw Error('must not run');}})).error,'E_DESKTOP_UNAVAILABLE');
  assert.deepEqual(f.read(),{date:'2027-01-01'});
  for(const url of ['https://chatgpt.com/','file:///webview/index.html','codex://account']) {
    assert.equal((await runPlan('detect',f.root,{listTargets:async()=>[{...target,url}],evaluate:()=>{throw Error('must not run');}})).error,'E_DESKTOP_UNAVAILABLE');
  }
});
test('corrupt, oversized and non-object config fails closed',async t=>{
  const f=fixture(t);
  for(const contents of ['{','[]','null',' '.repeat(65537)]) {
    writeFileSync(f.path,contents);
    assert.deepEqual(await runPlan('detect',f.root,io()),{detected:false,error:'E_CONFIG_INVALID'});
    assert.equal(readFileSync(f.path,'utf8'),contents);
  }
});
test('a manual change during desktop evaluation wins, including explicit detect',async t=>{
  const f=fixture(t,{plan:'plus'});const manual={plan:'free',planSource:'manual',manualOverride:true,tier:'100'};
  assert.deepEqual(await runPlan('detect',f.root,{...io(),evaluate:async()=>{writeFileSync(f.path,JSON.stringify(manual));return {trusted:true,plan:'pro'};}}),{detected:false,error:'E_CONFIG_CHANGED'});
  assert.deepEqual(f.read(),manual);assert.equal(existsSync(f.path+'.lock'),false);
});
test('errors are sanitized and invalid ports never reach CDP',async t=>{
  const f=fixture(t);writeFileSync(join(f.root,'.runtime/status.json'),JSON.stringify({port:'9222'}));
  assert.deepEqual(await runPlan('detect',f.root,io()),{detected:false,error:'E_DESKTOP_UNAVAILABLE'});
  writeFileSync(join(f.root,'.runtime/status.json'),JSON.stringify({port:9222}));
  assert.deepEqual(await runPlan('detect',f.root,{listTargets:async()=>{throw Error('secret-account-token');}}),{detected:false,error:'E_DESKTOP_UNAVAILABLE'});
});
test('a concurrent detector cannot commit while the membership lock is held',async t=>{
  const f=fixture(t);writeFileSync(f.path+'.lock','{}');
  assert.deepEqual(await runPlan('detect',f.root,io()),{detected:false,error:'E_BUSY'});
  assert.equal(existsSync(f.path),false);assert.equal(readFileSync(f.path+'.lock','utf8'),'{}');
});
test('invalid provenance, UTF-8 and attempt records fail closed',async t=>{
  const f=fixture(t);
  for(const contents of [JSON.stringify({manualOverride:'false'}),JSON.stringify({planSource:'CLI'}),JSON.stringify({detectedAt:'yesterday'}),Buffer.from([0x7b,0x22,0x78,0x22,0x3a,0x22,0xff,0x22,0x7d])]) {
    writeFileSync(f.path,contents);
    assert.equal((await runPlan('detect',f.root,io())).error,'E_CONFIG_INVALID');
  }
  rmSync(f.path);writeFileSync(join(f.root,'.runtime/plan-auto-attempted.json'),'{');
  assert.equal((await runPlan('auto',f.root,io())).error,'E_CONFIG_INVALID');
});
test('CLI accepts appdir and prints exactly one sanitized JSON result',t=>{
  const f=fixture(t,{plan:'plus'});
  const script=fileURLToPath(new URL('../src/plan.mjs',import.meta.url));
  const output=spawnSync(process.execPath,[script,'auto',f.root],{encoding:'utf8'});
  assert.equal(output.status,0);assert.equal(output.stderr,'');
  assert.deepEqual(JSON.parse(output.stdout),{detected:false,error:'E_MANUAL_LOCK'});
  assert.equal(spawnSync(process.execPath,[script,'unsupported',f.root],{encoding:'utf8'}).stdout.trim(),'{"detected":false,"error":"E_USAGE"}');
});
test('CLI entry guard uses the existing fail-closed canonical path helper',()=>{
  const url=new URL('../src/plan.mjs',import.meta.url),script=fileURLToPath(url);
  assert.match(readFileSync(url,'utf8'),/if\(canonicalEntry\(process\.argv\[1\],import\.meta\.url\)\)/);
  assert.equal(canonicalEntry('alias',url,path=>path==='alias'?script:path),true);
  assert.equal(canonicalEntry('other',url,path=>path),false);
  assert.equal(canonicalEntry('missing',url,()=>{throw Error('ENOENT');}),false);
});
