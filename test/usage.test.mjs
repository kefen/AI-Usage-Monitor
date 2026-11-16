import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeUsage } from '../src/usage.mjs';
const now=Date.parse('2026-11-14T12:00:00Z');
test('monthly average uses returned month days, not week or missing days',()=>{
  const s=normalizeUsage({dailyUsageBuckets:[{startDate:'2026-11-01',tokens:20},{startDate:'2026-11-15',tokens:40},{startDate:'2026-10-31',tokens:1000}]},Date.parse('2026-11-16T12:00:00Z'));
  assert.equal(s.month.value,60);assert.equal(s.month.days,2);assert.equal(s.month.average,30);assert.equal(s.week.value,null);
  assert.equal(normalizeUsage({},now).month.average,null);
});
test('account lifetime remains separate from calendar-week sums',()=>{
  const s=normalizeUsage({summary:{lifetimeTokens:9999},dailyUsageBuckets:[
    ...Array.from({length:6},(_,i)=>({startDate:`2026-11-${9+i<10?'0':''}${9+i}`,tokens:10})),
    {startDate:'2026-11-08',tokens:300},{startDate:'2026-11-15',tokens:700}
  ]},now);
  assert.equal(s.lifetime,9999);assert.equal(s.today.value,10);
  assert.equal(s.week.value,60);assert.equal(s.week.complete,true);
  assert.equal(s.week.start,'2026-11-09');assert.equal(s.weeks[1].value,300);
});
test('missing daily data is unknown, never zero and never lifetime-derived',()=>{
  for(const dailyUsageBuckets of [undefined,null,[]]) {
    const s=normalizeUsage({summary:{lifetimeTokens:800},dailyUsageBuckets},now);
    assert.equal(s.today.value,null);assert.equal(s.week.value,null);assert.equal(s.lifetime,800);
  }
});
test('partial week is explicitly incomplete; repeated dates do not double count',()=>{
  const s=normalizeUsage({dailyUsageBuckets:[{startDate:'2026-11-14',tokens:20},{startDate:'2026-11-14',tokens:20}]},now);
  assert.equal(s.week.value,20);assert.equal(s.week.complete,false);assert.equal(s.week.days,1);
});
test('conflicting duplicates, invalid counts and invalid dates are unavailable',()=>{
  const s=normalizeUsage({summary:{lifetimeTokens:'50'},dailyUsageBuckets:[
    {startDate:'2026-11-14',tokens:10},{startDate:'2026-11-14',tokens:11},
    {startDate:'2026-11-13',tokens:-1},{startDate:'2026-11-12',tokens:'9'},
    {startDate:'2026-02-30',tokens:80},{startDate:'2026-11-11',tokens:Number.MAX_SAFE_INTEGER+1}
  ]},now);
  assert.equal(s.lifetime,null);assert.equal(s.week.value,null);
});
test('explicit zeros are valid; Monday and year boundaries use calendar weeks',()=>{
  const s=normalizeUsage({summary:{lifetimeTokens:0},dailyUsageBuckets:[{startDate:'2026-01-01',tokens:0}]},Date.parse('2026-01-01T00:00:00Z'));
  assert.equal(s.lifetime,0);assert.equal(s.today.value,0);assert.equal(s.week.start,'2025-12-29');
});
