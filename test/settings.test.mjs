import test from 'node:test';
import assert from 'node:assert/strict';
import { nextUsageRefresh, normalizeMembership, nextMonthlyDate } from '../src/settings.mjs';

test('purchase dates use calendar months, with leap-year and month-end handling',()=>{
  assert.equal(nextMonthlyDate('2026-01-31'),'2026-02-28');
  assert.equal(nextMonthlyDate('2028-01-31'),'2028-02-29');
  assert.equal(nextMonthlyDate('2026-12-15'),'2027-01-15');
  assert.equal(nextMonthlyDate('2026-02-30'),null);
  assert.equal(normalizeMembership({enabled:false,date:'2026-12-13',kind:'renewal'}),null);
  assert.equal(normalizeMembership({purchaseDate:'2026-01-31',monthlyEstimate:true,plan:'pro',kind:'renewal'}).date,'2026-02-28');
  assert.equal(normalizeMembership({purchaseDate:'2026-01-31',date:'2026-03-03',monthlyEstimate:true,kind:'renewal'}).date,'2026-03-03');
});
test('usage refresh is one hour after each attempt, independent of timezone and date boundary',()=>{
  for(const timestamp of ['2026-11-14T00:59:59Z','2026-11-14T01:00:00Z','2026-11-14T10:32:00Z','2026-12-31T23:30:00Z']) {
    const now=Date.parse(timestamp);
    assert.equal(nextUsageRefresh(now)-now,3600000);
  }
  assert.equal(new Date(nextUsageRefresh(Date.parse('2026-12-31T23:30:00Z'))).toISOString(),'2027-01-01T00:30:00.000Z');
});
test('membership accepts valid manual date and preserves estimated provenance',()=>{
  assert.deepEqual(normalizeMembership({date:'2026-12-13',kind:'renewal',estimated:true,secret:'drop'}),{date:'2026-12-13',kind:'renewal',estimated:true});
  for(const value of [null,{}, {date:'2026-02-30',kind:'renewal'}, {date:'2026-12-13',kind:'quota'}]) assert.equal(normalizeMembership(value),null);
});
