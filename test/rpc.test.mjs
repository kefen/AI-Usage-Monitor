import test from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { readLimits, readUsage, readSnapshot } from '../src/rpc.mjs';
const fixture = fileURLToPath(new URL('./fake-server.mjs', import.meta.url));
test('combined quota and token read uses exactly one initialized CLI process',async()=>{
  const result=await readSnapshot({command:process.execPath,args:[fixture],timeoutMs:5000});
  assert.equal(result.limits.sessionPid,result.usage.sessionPid);
  assert.equal(result.limits.rateLimits.primary.usedPercent,27);
  assert.equal(result.usage.summary.lifetimeTokens,1234567);
});
test('usage reader only calls the read-only account usage endpoint', async()=>{
  const result=await readUsage({command:process.execPath,args:[fixture],timeoutMs:5000});
  assert.equal(result.summary.lifetimeTokens,1234567);
});

test('combined read preserves quota when usage rejects or times out',async()=>{
  for(const mode of ['usage-error','usage-timeout']){
    const result=await readSnapshot({command:process.execPath,args:[fixture,mode],timeoutMs:500});
    assert.equal(result.limits.rateLimits.primary.usedPercent,27);
    assert.match(result.usageError,/unavailable|timed out/);
    assert.equal(JSON.stringify(result).includes('private server details'),false);
  }
});

test('combined read can return usage even when quota is unavailable',async()=>{
  const result=await readSnapshot({command:process.execPath,args:[fixture,'quota-error'],timeoutMs:5000});
  assert.equal(result.usage.summary.lifetimeTokens,1234567);
  assert.equal(result.limitsError,'Quota read unavailable');
});
test('handshakes and reads the read-only endpoint with chunked JSON lines', async () => {
  const result = await readLimits({ command: process.execPath, args: [fixture], timeoutMs: 5000 });
  assert.equal(result.rateLimits.primary.usedPercent, 27);
});
test('a stalled server times out and is stopped', async () => {
  await assert.rejects(readLimits({ command: process.execPath, args: [fixture, 'timeout'], timeoutMs: 250 }), /timed out/);
});
test('a missing CLI fails without leaking its process environment', async () => {
  await assert.rejects(readLimits({ command: 'nonexistent-codex-test-command', args: [], timeoutMs: 1000 }), /could not start/);
});
