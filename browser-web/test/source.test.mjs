import test from 'node:test';
import assert from 'node:assert/strict';
import '../source.js';
const {parse,visible}=globalThis.CQSWebSource;
test('reads only explicitly labeled current values and preserves zero',()=>{
 const x=parse({description:'每周用量：剩余 0%',menu:['Usage source: Your Pro plan','Weekly limit 0% left','Credits 162.811 credits']},1000);
 assert.equal(x.week,0);assert.equal(x.credits,'162');assert.equal(x.plan,'Pro');
 assert.equal(x.short,null);assert.equal(x.tokens,null);
});
test('reads the current overview without converting historical usage',()=>{
 const x=parse({overview:{plans:['ChatGPT Pro 100'],weeks:[{value:'30',max:'100',label:'剩余用量'}],credits:['剩余额度：163'],resets:['可用 3'],resetTimes:['3天0小时 后重置']}},1000);
 assert.equal(x.plan,'Pro 100');assert.equal(x.week,30);assert.equal(x.resets,3);assert.equal(x.reset,'3天0小时 后重置');
 assert.equal(parse({overview:{weeks:[{value:'63.4',max:'100',label:'已使用限额百分比'}]}}).week,null);
});
test('conflicts, invalid numbers, unrelated text and malformed balances fail closed',()=>{
 assert.equal(parse({description:'Weekly usage: 30% left',menu:['Weekly limit 29% left']}).week,null);
 assert.equal(parse({menu:['Credits 100 credits','Credits 101 credits']}).credits,null);
 assert.equal(parse({menu:['Usage source: Your Pro plan','Usage source: Your Plus plan']}).plan,null);
 for(const text of ['Credits -1 credits','Credits 9007199254740992 credits','Credits 1,2 credits','USD 163'])assert.equal(parse({menu:[text]}).credits,null);
 assert.equal(parse({description:'Weekly usage: 130% left'}).week,null);
 assert.equal(parse({overview:{resets:['可用 -3'],credits:['充值 100'],resetTimes:['历史重置时间']}}).resets,null);
});
test('three locales accept exact official labels, never infer billing tiers',()=>{
 assert.equal(parse({description:'每週用量：剩餘 42%',menu:['額度 1,000.99 額度']}).week,42);
 assert.equal(parse({menu:['Usage source: Your Business plan']}).plan,'Business');
 assert.equal(parse({menu:['My Pro account has 100 credits']}).plan,null);
 assert.equal(parse({overview:{plans:['ChatGPT Education']}}).plan,null);
});
test('official menu supports colon-form credit balances and explicit zero',()=>{
 for(const label of ['额度：824.75','額度：824.75','Credits: 824.75','Credits: 824.75 credits','Remaining credits: 824.75']){
  assert.equal(parse({menu:[label]}).credits,'824',label);
 }
 assert.equal(parse({menu:['额度：0']}).credits,'0');
 assert.equal(parse({menu:['购买额度：824']}).credits,null);
});
test('overview tier refines matching menu family; conflicts stay unknown',()=>{
 const overview={plans:['ChatGPT Pro 100'],resets:['可用0']};
 assert.equal(parse({overview,menu:['额度来源：你的 Pro 套餐']}).plan,'Pro 100');
 assert.equal(parse({overview,menu:['Usage source: Your Plus plan']}).plan,null);
 assert.equal(parse({overview}).resets,0);
});
test('all snapshots expire and blocked account contexts reveal no previous data',()=>{
 const x=parse({description:'Weekly usage: 30% left'},1000);
 assert.equal(visible(x,61000).week,null);
 assert.equal(visible(x,999).week,null);
 assert.equal(visible(x,2000,true).week,null);
 assert.equal(visible(x,2000).week,30);
});
