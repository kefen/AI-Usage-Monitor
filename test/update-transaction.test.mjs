import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,writeFile,readFile,mkdir} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {backupSettings,verifySettings,localizedNotes,canonicalEntry} from '../src/update-transaction.mjs';

test('upgrade backup preserves every user-authored setting without credentials',async()=>{
 const root=await mkdtemp(join(tmpdir(),'cqs-preserve-test-'));await mkdir(join(root,'.runtime'));
 const member={plan:'pro',tier:'100',purchaseDate:'2026-09-06',date:'2026-12-06',planSource:'manual',manualOverride:true};
 await writeFile(join(root,'.runtime','membership.json'),JSON.stringify(member));
 await writeFile(join(root,'.runtime','language.json'),'"en"');
 await writeFile(join(root,'.runtime','auth.json'),'DO NOT COPY');
 const backup=await backupSettings(root,join(root,'backup'));
 assert.deepEqual(backup.files.sort(),['language.json','membership.json']);
 assert.deepEqual(JSON.parse(await readFile(join(root,'backup','membership.json'))),member);
 await verifySettings(root,join(root,'backup'));
 await writeFile(join(root,'.runtime','membership.json'),JSON.stringify({...member,purchaseDate:'2026-11-17'}));
 await assert.rejects(()=>verifySettings(root,join(root,'backup')),/Settings changed/);
});
test('unreadable prior settings never become a new default record',async()=>{
 const root=await mkdtemp(join(tmpdir(),'cqs-invalid-test-'));await mkdir(join(root,'.runtime'));await writeFile(join(root,'.runtime','membership.json'),'{bad');
 await assert.rejects(()=>backupSettings(root,join(root,'backup')),/Invalid saved settings/);
});
test('release notes select a language and render separate numbered lines',()=>{
 const notes={'zh-CN':['优化界面','保留设置'], 'zh-TW':['改善介面','保留設定'], en:['Refine UI','Keep settings']};
 assert.equal(localizedNotes(notes,'zh-CN'),'1. 优化界面\n2. 保留设置');
 assert.equal(localizedNotes(notes,'en'),'1. Refine UI\n2. Keep settings');
 assert.equal(localizedNotes({},'zh-CN'),'');
 assert.equal(localizedNotes('Legacy notes','en'),'1. Legacy notes');
});
test('updater entry detection accepts aliases only when they resolve to the same file',()=>{
 const actual=join(tmpdir(),'real','update.mjs'),alias=join(tmpdir(),'alias','update.mjs');
 const real=p=>p===alias?actual:p;
 assert.equal(canonicalEntry(alias,pathToFileURL(actual),real),true);
 assert.equal(canonicalEntry(join(tmpdir(),'other.mjs'),pathToFileURL(actual),real),false);
});
