import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeUsage} from '../src/usage.mjs';
import {browserSnapshot} from '../src/browser-snapshot.mjs';

test('monthly snapshot retains zero, marks missing days and expires at month rollover',()=>{
  const now=Date.parse('2026-11-30T23:59:59Z');
  const usage=normalizeUsage({dailyUsageBuckets:[{startDate:'2026-11-30',tokens:0},{startDate:'2026-10-31',tokens:10}]},now);
  assert.equal(browserSnapshot({},usage,now).monthTotal,0);
  assert.equal(browserSnapshot({},usage,now).monthPartial,true);
  assert.equal(browserSnapshot({},usage,now+1000).monthTotal,null);
  assert.equal(browserSnapshot({},normalizeUsage({},now),now).monthTotal,null);
});

test('desktop trend projects a bounded UTC month and preserves missing days separately from zero',()=>{
  const now=Date.parse('2026-11-20T18:00:00Z');
  const usage=normalizeUsage({dailyUsageBuckets:[{startDate:'2026-10-31',tokens:2},{startDate:'2026-11-01',tokens:0},{startDate:'2026-11-03',tokens:8},{startDate:'2026-11-20',tokens:6},{startDate:'2026-11-21',tokens:5}]},now);
  const trend=browserSnapshot({},usage,now).monthTrend;
  assert.equal(trend.month,'2026-11');
  assert.equal(trend.days.length,20);
  assert.deepEqual(trend.days.slice(0,4),[0,null,8,null]);
  assert.equal(trend.days[19],6);
  assert.equal(browserSnapshot({},usage,now+5400000).monthTrend,null);
});
