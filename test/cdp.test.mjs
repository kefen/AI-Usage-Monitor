import test from 'node:test';
import assert from 'node:assert/strict';
import { listTargets, evaluate, watchOverview } from '../src/cdp.mjs';
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

test('overview channel accepts only a fixed action and closes cleanly',async()=>{
  let socket,opens=0;
  class BindingSocket extends FakeSocket {
    constructor(){super();socket=this;}
    send(data){const q=JSON.parse(data);assert.ok(['Runtime.enable','Runtime.addBinding'].includes(q.method));}
    emit(name,payload){this.dispatchEvent(new MessageEvent('message',{data:JSON.stringify({method:'Runtime.bindingCalled',params:{name,payload}})}));}
  }
  const channel=watchOverview(target,9222,()=>opens++,BindingSocket);
  await new Promise(resolve=>setTimeout(resolve,0));
  socket.emit('__cqsOpenOverview','run-command');socket.emit('other','open-overview');
  assert.equal(opens,0);
  socket.emit('__cqsOpenOverview','open-overview');socket.emit('__cqsOpenOverview','open-overview');
  await Promise.resolve();
  assert.equal(opens,1,'duplicate clicks are throttled');
  channel.close();assert.equal(channel.active(),false);
  socket.emit('__cqsOpenOverview','open-overview');assert.equal(opens,1);
  assert.throws(()=>watchOverview({...target,url:'https://evil.example'},9222,()=>{}),/untrusted/);
});
