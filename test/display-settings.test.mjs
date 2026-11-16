import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeDisplay,displayKeys,planBadge} from '../src/display-settings.mjs';
import {nextAnnualDate,normalizeMembership} from '../src/settings.mjs';
import * as settings from '../src/display-settings.mjs';
import {mkdtemp,writeFile,rename,rm,realpath} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
for(const file of ['display.json','membership.json'])test(file+' changes notify immediately after atomic replacement, independently of quota polling',async()=>{
  assert.equal(typeof settings.watchDisplay,'function');
  // Windows CI may expose an 8.3 TEMP alias; watch the canonical directory.
  const root=await realpath(await mkdtemp(join(tmpdir(),'cqs-settings-')));let close;
  try{
    let wake;const changed=new Promise(resolve=>wake=resolve);
    close=settings.watchDisplay(pathToFileURL(root+'/'),wake);
    await writeFile(join(root,file+'.tmp'),JSON.stringify(file==='display.json'?{weekly:false}:{plan:'plus'}));
    await rename(join(root,file+'.tmp'),join(root,file));
    let timer;await Promise.race([changed,new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('No live refresh')),1800))]).finally(()=>clearTimeout(timer));
    const result=await settings.readDisplay(pathToFileURL(root+'/'));
    if(file==='display.json')assert.equal(result.visible.weekly,false);else assert.equal(result.planBadge,'Plus');
  }finally{if(close)close();await rm(root,{recursive:true,force:true});}
});
test('display preferences whitelist keys and preserve explicit false',()=>{
  assert.equal(Object.keys(normalizeDisplay({secret:true})).length,9);
  assert.equal(normalizeDisplay({week:false}).week,false);
  assert.ok(Object.values(normalizeDisplay({})).every(Boolean));
  assert.ok(Object.values(normalizeDisplay(Object.fromEntries(displayKeys.map(k=>[k,false])))).every(v=>!v));
});
test('plan badge is a manual family label, not inferred from tier',()=>{
  assert.equal(planBadge({plan:'pro',tier:'500'}),'Pro');
  assert.equal(planBadge({plan:'business'}),'Biz');
  assert.equal(planBadge({tier:'200'}),'?');
});
test('annual estimate clamps leap day and preserves optional/manual dates',()=>{
  assert.equal(nextAnnualDate('2028-02-29'),'2029-02-28');
  assert.equal(nextAnnualDate('2026-02-30'),null);
  assert.equal(normalizeMembership({enabled:false,annualEstimate:true,purchaseDate:'2026-01-01'}),null);
  assert.deepEqual(normalizeMembership({annualEstimate:true,purchaseDate:'2028-02-29',kind:'renewal'}),{date:'2029-02-28',kind:'renewal',estimated:true});
});
