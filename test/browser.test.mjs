import test from 'node:test';import assert from 'node:assert/strict';
import {decodeRequest,safeSnapshot,readBrowserState} from '../browser/native-host.mjs';import {browserSnapshot} from '../src/browser-snapshot.mjs';
import {mkdtemp,mkdir,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';

test('bridge projects only twelve shared choices and safe plan metadata, even when stale',()=>{
 const now=Date.now(),input={schema:1,generatedAt:now,visible:{short:false,plan:true,secret:'SECRET'},planBadge:'Pro',renewalDate:'2026-12-13',planSource:'manual',secret:'SECRET'};
 const result=safeSnapshot(input,now);
 assert.equal(result.visible.short,false);assert.equal(Object.keys(result.visible).length,12);
 assert.equal(result.planBadge,'Pro');assert.equal(result.renewalDate,'2026-12-13');assert.equal(result.planSource,'manual');
 assert.ok(!JSON.stringify(result).includes('SECRET'));
 assert.equal(safeSnapshot({...input,generatedAt:0},now).visible.short,false);
 assert.equal(safeSnapshot({...input,renewalDate:'2026-02-30',planBadge:'SECRET',planSource:'SECRET'},now).renewalDate,null);
});

test('native reads current local settings from app root without waiting for a snapshot rewrite',async()=>{
 const root=await mkdtemp(join(tmpdir(),'cqs-browser-')),runtime=join(root,'.runtime');
 try{
  await mkdir(runtime);await writeFile(join(runtime,'browser-state.json'),JSON.stringify({schema:1,generatedAt:Date.now(),visible:{short:true},planBadge:'Free'}));
  await writeFile(join(runtime,'display.json'),JSON.stringify({short:false,credits:false}));
  await writeFile(join(runtime,'membership.json'),JSON.stringify({plan:'pro',planSource:'manual',enabled:true,kind:'renewal',date:'2026-12-13'}));
  const first=await readBrowserState(root);assert.equal(first.visible.short,false);assert.equal(first.visible.credits,false);assert.equal(first.planBadge,'Pro');assert.equal(first.renewalDate,'2026-12-13');
  await writeFile(join(runtime,'display.json'),JSON.stringify({short:true}));
  await writeFile(join(runtime,'membership.json'),JSON.stringify({plan:'plus',enabled:false,kind:'renewal',date:'2026-12-13'}));
  const second=await readBrowserState(root);assert.equal(second.visible.short,true);assert.equal(second.planBadge,'Plus');assert.equal(second.renewalDate,null);
  await writeFile(join(runtime,'membership.json'),JSON.stringify({plan:'plus',kind:'renewal',date:'2026-12-13'}));
  assert.equal((await readBrowserState(root)).planSource,'manual','Legacy manual records match desktop provenance');
  await rm(join(runtime,'browser-state.json'));
  const unavailable=await readBrowserState(root);assert.equal(unavailable.code,'UNAVAILABLE');assert.equal(unavailable.visible.short,true);assert.equal(unavailable.planBadge,'Plus');
 }finally{await rm(root,{recursive:true,force:true});}
});

test('stale quota and usage are null, genuine zero stays zero and commands stay read-only',()=>{
 const now=Date.now(),raw={schema:1,generatedAt:now,quotaAt:now,usageAt:now,creditBalance:'0',resetCredits:0,week:0,windows:[{minutes:300,remaining:0}]};
 assert.equal(safeSnapshot(raw,now).windows[0].remaining,0);assert.equal(safeSnapshot(raw,now).week,0);
 const stale=safeSnapshot({...raw,quotaAt:now-180000,usageAt:now-5400000},now);
 assert.deepEqual(stale.windows,[]);assert.equal(stale.week,null);assert.equal(stale.resetCredits,null);
 for(const request of [{op:'settings'},{op:'read',command:'open'},{op:'exec',args:[]}]){const data=Buffer.from(JSON.stringify(request)),head=Buffer.alloc(4);head.writeUInt32LE(data.length);assert.throws(()=>decodeRequest(Buffer.concat([head,data])));}
});
test('monthly average, credits and reset count cross the read-only bridge without coercion',()=>{
 const now=Date.parse('2026-11-16T12:00:00Z'),state={fetchedAt:now,buckets:[{windows:[],credits:{balance:'163'}}],resetCredits:2};
 const usage={fetchedAt:now,month:{average:30,start:'2026-11-01'}};
 const safe=safeSnapshot(browserSnapshot(state,usage,now),now);
 assert.equal(safe.monthAverage,30);assert.equal(safe.creditBalance,'163');assert.equal(safe.resetCredits,2);
 const missing=safeSnapshot(browserSnapshot({...state,resetCredits:null},{fetchedAt:now},now),now);
 assert.equal(missing.monthAverage,null);assert.equal(missing.resetCredits,null);
});
test('native messaging accepts only bounded read frames',()=>{const data=Buffer.from('{"op":"read"}'),head=Buffer.alloc(4);head.writeUInt32LE(data.length);assert.equal(decodeRequest(head),null);assert.deepEqual(decodeRequest(Buffer.concat([head,data])),{op:'read'});const big=Buffer.alloc(4);big.writeUInt32LE(99999);assert.throws(()=>decodeRequest(big));const bad=Buffer.from('{"op":"exec"}');assert.throws(()=>decodeRequest(Buffer.concat([head,bad])));});
test('browser projection strips secrets and expires stale data',()=>{const now=1000000;const raw=browserSnapshot({fetchedAt:now,buckets:[{id:'SECRET',windows:[{minutes:300,remaining:80,resetsAt:1500}]}],token:'SECRET'},{fetchedAt:now,lifetime:10,week:{value:4},dailySelected:{date:'2026-11-15',value:2}},now);assert.ok(!JSON.stringify(raw).includes('SECRET'));const safe=safeSnapshot({...raw,auth:'SECRET'},now);assert.equal(safe.windows[0].remaining,80);assert.equal(safe.lifetime,10);assert.ok(!JSON.stringify(safe).includes('SECRET'));assert.equal(safeSnapshot(raw,now+100000).code,'STALE');assert.equal(safeSnapshot({...raw,generatedAt:now+99999},now).code,'STALE');});
test('missing counts remain null, not fabricated zero',()=>{const now=Date.now();const result=browserSnapshot({fetchedAt:now,buckets:[]},{error:'private internal detail'},now);assert.equal(result.lifetime,null);assert.equal(result.daily,null);assert.equal(result.windows.length,0);});
