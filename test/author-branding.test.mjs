import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const root=new URL('../',import.meta.url);
test('first-party metadata uses KEFEN attribution',async()=>{
 for(const path of ['package.json','browser/manifest.json']){
  const data=JSON.parse(await readFile(new URL(path,root),'utf8'));
  assert.equal(data.author,'KEFEN',path);
 }
 const readme=await readFile(new URL('README.md',root),'utf8');
 assert.ok(readme.replace(/\r\n/g,'\n').startsWith('# AI Usage Monitor\n\nby KEFEN'));
});
test('browser registration and client agree on the KEFEN native host',async()=>{
 const expected='org.kefen.codex_quota_sidebar';
 for(const path of ['browser/panel.js','browser/Register-Windows.ps1','browser/Register-Mac.mjs','test/browser-ui.mjs']){
  const text=await readFile(new URL(path,root),'utf8');
  const names=text.match(/org\.[a-z]+\.codex_quota_sidebar/g)||[];
  assert.ok(names.length>0,path);
  assert.ok(names.every(name=>name===expected),path+' contains a mismatched native-host name');
 }
});
