import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeLimits, freshness, countdown, validateTarget } from '../src/core.mjs';
test('additional quota metadata is read-only and absent values stay unknown',()=>{
  const s=normalizeLimits({rateLimits:{primary:{usedPercent:20,windowDurationMins:300},credits:{balance:'12.50',hasCredits:true,unlimited:false}},rateLimitResetCredits:{availableCount:2}});
  assert.equal(s.resetCredits,2);assert.equal(s.buckets[0].credits.balance,'12.50');
  assert.equal(normalizeLimits({}).resetCredits,null);
});

test('uses durations, not primary/secondary positions, to label windows', () => {
  const s = normalizeLimits({ rateLimits: {
    primary: { usedPercent: 25, windowDurationMins: 10080, resetsAt: 2000 },
    secondary: { usedPercent: 60, windowDurationMins: 300, resetsAt: 1500 }
  } }, 1000);
  assert.deepEqual(s.buckets[0].windows.map(w => [w.minutes, w.remaining]), [[300, 40], [10080, 75]]);
});
test('a single weekly window never invents a five-hour window', () => {
  const s = normalizeLimits({ rateLimits: { primary: { usedPercent: 0, windowDurationMins: 10080 } } }, 1000);
  assert.equal(s.buckets[0].windows.length, 1);
  assert.equal(s.buckets[0].windows[0].remaining, 100);
  assert.equal(s.buckets[0].windows[0].resetsAt, null);
});
test('missing, null, string and invalid numbers are unavailable, not zero usage', () => {
  for (const usedPercent of [undefined, null, '20', NaN, -1, 101]) {
    const s = normalizeLimits({ rateLimits: { primary: { usedPercent, windowDurationMins: 300 } } });
    assert.equal(s.buckets.length, 0);
  }
});
test('empty payload is not interpreted as an unlimited account', () => {
  assert.equal(normalizeLimits({}).buckets.length, 0);
  assert.equal(normalizeLimits(null).buckets.length, 0);
});
test('keeps distinct metered buckets without duplicates', () => {
  const quota = { primary: { usedPercent: 10, windowDurationMins: 300 } };
  const s = normalizeLimits({ rateLimits: quota, rateLimitsByLimitId: { codex: quota, other: quota } });
  assert.deepEqual(s.buckets.map(x => x.id), ['codex', 'other']);
});
test('empty map falls back to the legacy bucket', () => {
  assert.equal(normalizeLimits({ rateLimitsByLimitId: {}, rateLimits: {
    primary: { usedPercent: 10, windowDurationMins: 300 }
  } }).buckets.length, 1);
});
test('expires old data and distinguishes errors from fresh data', () => {
  assert.equal(freshness({ fetchedAt: 1000 }, 1100), 'fresh');
  assert.equal(freshness({ fetchedAt: 1000, error: 'timeout' }, 1100), 'stale');
  assert.equal(freshness({ fetchedAt: 1000 }, 181001), 'stale');
  assert.equal(freshness({ fetchedAt: 1000 }, 901001), 'expired');
  assert.equal(freshness({}, 1000), 'unavailable');
});
test('countdowns do not claim an automatic reset happened', () => {
  assert.equal(countdown(100, 101), 'pending');
  assert.equal(countdown(null, 0), null);
  assert.equal(countdown(7200, 0), '2h 0m');
});
test('only loopback ws endpoints and known app pages are accepted', () => {
  const target = { type: 'page', url: 'codex://app/index.html', webSocketDebuggerUrl: 'ws://127.0.0.1:9222/devtools/page/1' };
  assert.equal(validateTarget(target, 9222), true);
  assert.equal(validateTarget({ ...target, url: 'https://example.com' }, 9222), false);
  assert.equal(validateTarget({ ...target, webSocketDebuggerUrl: 'ws://evil.example:9222/devtools/page/1' }, 9222), false);
  assert.equal(validateTarget({ ...target, webSocketDebuggerUrl: 'ws://127.0.0.1:9999/devtools/page/1' }, 9222), false);
  assert.equal(validateTarget({ ...target, url: 'https://chatgpt.com.evil.example/' }, 9222), false);
});
