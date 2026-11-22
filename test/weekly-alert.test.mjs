import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,writeFile,rm,readFile,unlink} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {execFileSync} from 'node:child_process';
import {join} from 'node:path';
import {weekPace} from '../src/core.mjs';
import {queueWeeklyAlert} from '../src/settings.mjs';
test('weekly pace and reliable window boundaries',()=>{
  const now=Date.UTC(2026,10,22),w={minutes:10080,resetsAt:now/1000+302400,remaining:45};
  for(const [left,expected] of [[45,'steady'],[55,'steady'],[44,'fast'],[56,'slow']])
    assert.equal(weekPace({...w,remaining:left},now),expected);
  for(const patch of [{resetsAt:null},{resetsAt:now/1000},{minutes:300},{remaining:null},{resetsAt:now/1000+604801}])
    assert.equal(weekPace({...w,...patch},now),null);
});
test('restart and concurrent samples cannot duplicate a claimed weekly window',async()=>{
  const dir=await mkdtemp(join(tmpdir(),'weekly-test-'));
  try {
    const now=Date.now(), w={minutes:10080,resetsAt:Math.floor(now/1000)+86400,remaining:20};
    const state={fetchedAt:now,buckets:[{id:'codex',windows:[w]}]};
    const sample=()=>queueWeeklyAlert(dir,state,now);
    assert.equal(await sample(),false);
    await writeFile(join(dir,'weekly-alert.json'),JSON.stringify({enabled:true,threshold:20}));
    assert.equal(await queueWeeklyAlert(dir,{...state,error:'unavailable'},now),false);
    assert.equal(await queueWeeklyAlert(dir,state,now+180001),false);
    assert.equal((await Promise.all([sample(),sample()])).filter(Boolean).length,1);
    assert.equal(JSON.parse(await readFile(join(dir,'weekly-notice.json'))).remaining,20);
    await unlink(join(dir,'weekly-notice.json'));
    const restart="import {queueWeeklyAlert} from "+JSON.stringify(new URL('../src/settings.mjs',import.meta.url).href)+";console.log(await queueWeeklyAlert(process.argv[1],JSON.parse(process.argv[2]),Number(process.argv[3])))";
    assert.equal(execFileSync(process.execPath,['--input-type=module','-e',restart,dir,JSON.stringify(state),String(now)],{encoding:'utf8'}).trim(),'false');
    w.remaining=75;assert.equal(await sample(),false);
    w.remaining=3;assert.equal(await sample(),false);
    w.resetsAt+=86400;assert.equal(await sample(),true);
  } finally {await rm(dir,{recursive:true,force:true})}
});
