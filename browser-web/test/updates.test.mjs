import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
const source=await readFile(new URL('../background.js',import.meta.url),'utf8');
test('release checks are coalesced, daily and only offer newer browser builds',async()=>{
  let remote='0.6.0',requests=0,badge;
  const state={},event={addListener(){}},chrome={runtime:{onStartup:event,onInstalled:event,onMessage:event,getManifest:()=>({version:'0.5.2'})},action:{onClicked:event,setBadgeText:async x=>{badge=x.text;}},tabs:{onRemoved:event},alarms:{onAlarm:event},storage:{local:{get:async()=>({...state}),set:async x=>Object.assign(state,x)}}};
  const ctx=vm.createContext({chrome,AbortSignal,fetch:async(url,opts)=>{
    assert.equal(new URL(url).hostname,'raw.githubusercontent.com');assert.equal(opts.credentials,'omit');requests++;
    return {ok:true,json:async()=>({product:'codex-quota-web',version:remote})};
  }});
  vm.runInContext(source,ctx);
  const check=()=>vm.runInContext('checkVersion()',ctx);
  await Promise.all([check(),check()]);await check();
  assert.equal(requests,1);assert.equal(state.cqsNewVersion,'0.6.0');assert.ok(badge);
  for(remote of ['0.5.2','0.4.9','javascript:bad']){state.cqsCheckedAt=0;await check();assert.equal(badge,'');assert.equal(state.cqsNewVersion,'');}
});
