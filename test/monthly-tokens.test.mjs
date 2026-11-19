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
