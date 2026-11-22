import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {inventory,inspectStatusline} from '../tools/claude-data-probe.mjs';
const now=1800000000000;
test('documented quota contract accepts zero and keeps two windows separate',()=>{
  const r=inspectStatusline({rate_limits:{five_hour:{used_percentage:0,resets_at:now/1000+900},seven_day:{used_percentage:80,resets_at:now/1000+5000}}},now);
  assert.equal(r.limits.five_hour.remainingPercentage,100);assert.equal(r.limits.seven_day.remainingPercentage,20);
  assert.equal(r.notificationEligible,false);assert.equal(r.providerObservedAt,null);
});
test('missing API/subscription fields are unknown, not zero or unlimited',()=>{
  const r=inspectStatusline({model:{id:'example'},context_window:{current_usage:null}},now);
  assert.equal(r.limits.seven_day.state,'not-provided');assert.equal(r.limits.seven_day.remainingPercentage,null);
  assert.equal(r.context.inputTokens,null);assert.equal(r.historyTotalTokens,null);
});
test('bad, expired, null and string quota values fail closed',()=>{
  for(const used of [null,'20',-1,101,Infinity])assert.equal(inspectStatusline({rate_limits:{seven_day:{used_percentage:used,resets_at:now/1000+10}}},now).limits.seven_day.state,'invalid');
  assert.equal(inspectStatusline({rate_limits:{seven_day:{used_percentage:20,resets_at:now/1000}}},now).limits.seven_day.state,'expired');
});
test('cost and context are not claimed as actual subscription billing or history',()=>{
  const r=inspectStatusline({cost:{total_cost_usd:0},context_window:{used_percentage:15,current_usage:{input_tokens:0,output_tokens:10}}},now);
  assert.equal(r.sessionCostEstimateUsd,0);assert.equal(r.context.inputTokens,0);assert.equal(r.billingVerified,false);assert.equal(r.historyTotalTokens,null);
});
test('output drops secrets, conversations, paths, identity and arbitrary labels',()=>{
  const r=inspectStatusline({version:'2.1.90',apiKey:'SECRET',session_id:'SECRET',model:{id:'SECRET'},cwd:'SECRET',workspace:{project_dir:'SECRET'},messages:[{content:'SECRET'}],email:'SECRET',rate_limits:{spend_limit:{used_usd:90,limit_usd:100}}},now);
  assert(!JSON.stringify(r).includes('SECRET'));assert.equal(r.version,'2.1.90');assert.equal(r.accountIdentity,'unverified');assert.equal(r.notificationEligible,false);
});
test('inventory only checks metadata and never reads credentials or transcript content',async()=>{
  const home=await mkdtemp(join(tmpdir(),'claude-probe-'));
  try{
    let r=await inventory({home,env:{PATH:''}});assert.equal(r.configDirectory,'absent');
    await mkdir(join(home,'.claude','projects'),{recursive:true});
    await writeFile(join(home,'.claude','.credentials.json'),'INVALID SECRET DATA');
    await writeFile(join(home,'.claude','settings.json'),'INVALID SECRET DATA');
    r=await inventory({home,env:{PATH:''}});assert.equal(r.entries.projects,'directory');assert.equal(r.entries['settings.json'],'file');
    assert.equal(r.credentialsRead,false);assert.equal(r.transcriptsRead,false);assert(!JSON.stringify(r).includes(home));
  }finally{await rm(home,{recursive:true,force:true});}
});
