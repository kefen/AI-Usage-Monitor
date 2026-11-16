import test from 'node:test';import assert from 'node:assert/strict';
import {decodeRequest,safeSnapshot} from '../browser/native-host.mjs';import {browserSnapshot} from '../src/browser-snapshot.mjs';
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
