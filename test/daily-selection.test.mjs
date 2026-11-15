import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeUsage,selectDailyUsage,observeAvailability} from '../src/usage.mjs';
const now=Date.parse('2026-11-15T12:00:00Z');
const usage=rows=>normalizeUsage({dailyUsageBuckets:rows.map(([startDate,tokens])=>({startDate,tokens}))},now);
test('automatic daily selection uses explicit zero today, yesterday, then latest dated record',()=>{
  assert.deepEqual(selectDailyUsage(usage([['2026-11-15',0],['2026-11-14',42]]),now),{date:'2026-11-15',value:0,relation:'today'});
  assert.equal(selectDailyUsage(usage([['2026-11-14',42]]),now).relation,'yesterday');
  assert.deepEqual(selectDailyUsage(usage([['2026-11-10',42],['2026-11-13',8]]),now),{date:'2026-11-13',value:8,relation:'latest'});
  assert.equal(selectDailyUsage(usage([]),now),null);
});
test('conflicting or invalid daily rows never win over a known historical value',()=>{
  assert.equal(selectDailyUsage(usage([['2026-11-15',4],['2026-11-15',9],['2026-11-14',0]]),now).date,'2026-11-14');
});
test('a retained daily snapshot is relabeled after midnight, not called today forever',()=>{
  const data=usage([['2026-11-15',7]]);
  assert.equal(selectDailyUsage(data,now+86400000).relation,'yesterday');
});
test('availability observes intervals without storing token totals or inventing publication time',()=>{
  const empty=observeAvailability({},usage([]),now);
  const seen=observeAvailability(empty,usage([['2026-11-15',42]]),now+3600000);
  const row=seen.records.find(r=>r.date==='2026-11-15');
  assert.equal(row.lastAbsentAt,now);assert.equal(row.firstSeenAt,now+3600000);
  assert.equal(JSON.stringify(seen).includes('tokens'),false);
  assert.equal(observeAvailability(seen,usage([['2026-11-15',60]]),now+7200000).records.find(r=>r.date==='2026-11-15').firstSeenAt,row.firstSeenAt);
});
