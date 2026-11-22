import {test} from 'node:test';
import assert from 'node:assert/strict';
import {previousRelease} from '../tools/native-upgrade-plan.mjs';
const names=v=>[`setup-${v}`];
const release=(v,extra={})=>({tag_name:'windows/v'+v,draft:false,assets:[{name:'setup-'+v,digest:'sha256:'+'a'.repeat(64)}],...extra});
test('selects immediate previous public version, excluding current, newer and drafts',()=>{
  assert.equal(previousRelease([release('0.14.1'),release('0.13.8'),release('0.15.0'),release('0.14.0'),release('0.14.2',{draft:true})],'windows','0.14.1',names),'0.14.0');
});
test('cannot silently fall back past a missing previous package',()=>{
  assert.throws(()=>previousRelease([release('0.14.0',{assets:[]}),release('0.13.8')],'windows','0.14.1',names),/missing/);
});
test('requires actual prior release and verified original assets',()=>{
  assert.throws(()=>previousRelease([release('0.14.1')],'windows','0.14.1',names),/No public previous/);
  assert.throws(()=>previousRelease([release('0.14.0',{assets:[{name:'setup-0.14.0'}]})],'windows','0.14.1',names),/unverifiable/);
});
test('Mac alpha ordering chooses previous release numerically',()=>{
  const rows=['0.5.4-alpha.4','0.5.4-alpha.5','0.6.0-alpha.1'].map(v=>({...release(v),tag_name:'macos/v'+v}));
  assert.equal(previousRelease(rows,'macos','0.6.0-alpha.1',names),'0.5.4-alpha.5');
});
