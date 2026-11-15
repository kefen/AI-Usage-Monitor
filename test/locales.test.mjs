import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const root=new URL('../',import.meta.url);
test('shared UI catalog provides three complete languages and stable repository URL',async()=>{
 const catalog=JSON.parse(await readFile(new URL('ui/strings.json',root),'utf8'));
 assert.ok(Object.keys(catalog).length>50);
 for(const [key,values] of Object.entries(catalog)){
  assert.equal(values.length,2,key);
  assert.ok(values.every(x=>typeof x==='string'&&x.length>0),key);
 }
 for(const key of ['Usage overview','Sidebar content','Codex subscription record','Language','GitHub','Version'])assert.ok(catalog[key],key);
});
