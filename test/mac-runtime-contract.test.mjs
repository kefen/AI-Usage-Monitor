import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL('../'+p,import.meta.url),'utf8');
test('Mac packaging preserves upstream runtime bytes and bundles offline help',async()=>{
 const build=await read('mac/Build.command');
 assert.doesNotMatch(build,/codesign --force --sign - .*runtime\/node/);
 assert.match(build,/cmp .*bin\/node/);
 assert.match(build,/READ-ME-FIRST\.html/);
});
test('Mac runtime failure is separate from official client failure',async()=>{
 const ui=await read('mac/QuotaSidebar.swift');
 assert.match(ui,/RuntimeProbe/);
 assert.match(ui,/E_RUNTIME_START/);
 assert.match(ui,/openSecuritySettings/);
 assert.match(ui,/openInstallGuide/);
 const guide=await read('mac/READ-ME-FIRST.html');
 for(const text of ['简体中文','繁體中文','English','Privacy &amp; Security','node','102445'])assert.ok(guide.includes(text),text);
});
test('Mac signature rules use inline requirement syntax, not a file path',async()=>{
 const launcher=await read('mac/launch.mjs'),build=await read('mac/Build.command');
 assert.ok(launcher.includes('`=anchor apple generic'),'The launcher must prefix inline requirements with =');
 assert.ok(build.includes("-R '=anchor apple generic"),'The runtime publisher check must use inline requirements');
});
