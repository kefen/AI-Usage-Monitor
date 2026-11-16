import test from 'node:test';
import assert from 'node:assert/strict';
import {parseListeners, verifyListenerOwners} from '../mac/listener-policy.mjs';

const helper='/Users/test/.codex/computer-use/Codex Computer Use.app/Contents/MacOS/SkyComputerUseService';
const output='p36046\ncChatGPT\nf73\nn127.0.0.1:54200\np36119\ncSkyComputerUseService\nf73\nn127.0.0.1:54200\n';
const defaults=()=>({owners:parseListeners(output),mainPids:[36046],port:54200,helperExecutable:helper,
 inspectProcess:async()=>({parentPid:36046,executable:helper}),verifyHelper:async()=>true});
test('accepts the reported main process and signed direct helper co-owner',async()=>{
 assert.equal(parseListeners(output).length,2);
 assert.deepEqual(await verifyListenerOwners(defaults()),{ok:true});
});
test('accepts a sole main process on IPv4 and IPv6 loopback',async()=>{
 for(const address of ['127.0.0.1:54200','[::1]:54200'])assert.deepEqual(await verifyListenerOwners({...defaults(),owners:[{pid:36046,address}]}),{ok:true});
});
test('rejects helper-only ownership even with a valid signature',async()=>{
 assert.equal((await verifyListenerOwners({...defaults(),owners:[{pid:36119,address:'127.0.0.1:54200'}]})).ok,false);
});
test('rejects wildcard, external and wrong-port listeners',async()=>{
 for(const address of ['*:54200','0.0.0.0:54200','192.168.1.2:54200','127.0.0.1:54201'])assert.equal((await verifyListenerOwners({...defaults(),owners:[{pid:36046,address}]})).ok,false);
});
test('rejects a similarly named executable outside the exact helper path',async()=>{
 assert.equal((await verifyListenerOwners({...defaults(),inspectProcess:async()=>({parentPid:36046,executable:'/tmp/SkyComputerUseService'})})).ok,false);
});
test('rejects an unrelated parent even when the helper path matches',async()=>{
 assert.equal((await verifyListenerOwners({...defaults(),inspectProcess:async()=>({parentPid:1,executable:helper})})).ok,false);
});
test('rejects a failed or unavailable helper signature verification',async()=>{
 for(const verifyHelper of [async()=>false,async()=>{throw Error('verification unavailable');}])assert.equal((await verifyListenerOwners({...defaults(),verifyHelper})).ok,false);
});
test('rechecks helper identity after signature verification',async()=>{
 let calls=0;
 assert.equal((await verifyListenerOwners({...defaults(),inspectProcess:async()=>({parentPid:++calls===1?36046:1,executable:helper})})).ok,false);
});
test('empty and malformed ownership records fail closed',async()=>{
 for(const owners of [[],parseListeners('pbad\nn127.0.0.1:54200')])assert.equal((await verifyListenerOwners({...defaults(),owners})).ok,false);
});
