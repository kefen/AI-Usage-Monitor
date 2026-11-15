import test from 'node:test';
import assert from 'node:assert/strict';
import { listTargets, evaluate } from '../src/cdp.mjs';
const target = { type: 'page', url:'codex://app/index.html', webSocketDebuggerUrl:'ws://127.0.0.1:9222/devtools/page/1' };

test('target discovery requests loopback only, forbids redirects and filters pages', async () => {
  const result = await listTargets(9222, async (url, options) => {
    assert.equal(url, 'http://127.0.0.1:9222/json/list');
    assert.equal(options.redirect, 'error');
    return { ok:true, json:async () => [target, { ...target, url:'https://evil.example' }] };
  });
  assert.deepEqual(result, [target]);
});
test('invalid port and malformed discovery payload fail closed', async () => {
  await assert.rejects(listTargets(80), /Invalid/);
  await assert.rejects(listTargets(9222, async () => ({ok:true, json:async () => ({})})), /Invalid/);
});
class FakeSocket extends EventTarget {
  readyState = 0;
  constructor() { super(); queueMicrotask(() => { this.readyState = 1; this.dispatchEvent(new Event('open')); }); }
  send(data) {
    const request = JSON.parse(data);
    assert.equal(request.method,'Runtime.evaluate');
    assert.equal(request.params.returnByValue,true);
    queueMicrotask(() => this.dispatchEvent(new MessageEvent('message', {data:JSON.stringify({id:request.id,result:{result:{value:true}}})})));
  }
  close() { this.readyState=3; this.dispatchEvent(new Event('close')); }
}
test('CDP evaluation returns a value and closes its socket', async () => {
  assert.equal(await evaluate(target,9222,'true',1000,FakeSocket),true);
});
test('untrusted pages are rejected before opening a socket', async () => {
  await assert.rejects(evaluate({...target,url:'https://evil.example'},9222,'true',1000,FakeSocket),/untrusted/);
});
test('CDP timeouts are bounded', async () => {
  class StalledSocket extends FakeSocket { send() {} }
  await assert.rejects(evaluate(target,9222,'true',25,StalledSocket),/timed out/);
});
