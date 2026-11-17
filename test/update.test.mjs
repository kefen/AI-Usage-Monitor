import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync,sign} from 'node:crypto';
import {verifyFeed,newer,validateAsset,wholeCredits} from '../src/update.mjs';
test('signed feed rejects tampering, expired metadata and invalid signatures',()=>{
 const {publicKey,privateKey}=generateKeyPairSync('ed25519');
 const payload=Buffer.from(JSON.stringify({schema:1,expiresAt:Date.now()+60000,releases:{}}));
 const envelope={payload:payload.toString('base64'),signature:sign(null,payload,privateKey).toString('base64')};
 assert.equal(verifyFeed(envelope,publicKey).schema,1);
 assert.throws(()=>verifyFeed({...envelope,payload:Buffer.from('{}').toString('base64')},publicKey));
 assert.throws(()=>verifyFeed(envelope,publicKey,Date.now()+70000));
});
test('version comparisons and assets fail closed',()=>{
 assert.equal(newer('1.2.5','1.2.4'),true);assert.equal(newer('1.4.7-alpha.1','1.4.6-alpha.1'),true);
 assert.equal(newer('0.4.7-alpha.1','0.4.7'),false);assert.equal(newer('0.4.7','0.4.7-alpha.1'),true);
 assert.throws(()=>newer('garbage','0.1.0'));
 const asset={version:'0.12.5',url:'https://github.com/kefen/codex-quota-sidebar/releases/download/windows%2Fv0.12.5/app.exe',sha256:'a'.repeat(64),size:123};
 assert.equal(validateAsset(asset).size,123);
 assert.throws(()=>validateAsset({...asset,url:'https://evil.example/app.exe'}));
 assert.throws(()=>validateAsset({...asset,size:900000000}));
 assert.equal(wholeCredits('162.8117935000'),'162');assert.equal(wholeCredits('0.99'),'0');assert.equal(wholeCredits(null),'--');
});
test('cached checks are invalidated by a new installed version or UI language',async()=>{
 const {reusableCheck}=await import('../src/update.mjs');
 const state={current:'0.13.0',language:'en',checkedAt:1000};
 assert.equal(reusableCheck(state,'0.13.0','en',2000),true);
 assert.equal(reusableCheck(state,'0.13.1','en',2000),false);
 assert.equal(reusableCheck(state,'0.13.0','zh-CN',2000),false);
 assert.equal(reusableCheck(state,'0.13.0','en',86401001),false);
 assert.equal(reusableCheck({...state,checkedAt:3000},'0.13.0','en',2000),false);
});
