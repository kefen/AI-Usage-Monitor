import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
test('separate platform versions and explicit source/runtime manifests stay aligned',async()=>{
  const versions=JSON.parse(await read('versions.json'));
  assert.notEqual(versions.windows,versions.macos);
  assert.equal(JSON.parse(await read('package.json')).version,versions.windows);
  const source=JSON.parse(await read('source-files.json')),runtime=JSON.parse(await read('runtime-files.json'));
  for(const files of [source,runtime]){
    assert.equal(files.length,new Set(files).size);
    assert.ok(files.every(p=>!p.includes('..')&&!p.includes('.runtime')&&!p.includes('\\')&&!p.startsWith('/')));
  }
  assert.ok(source.includes('LICENSE')&&source.includes('SECURITY.md')&&source.includes('native/Preferences.cs'));
  assert.ok(runtime.includes('versions.json')&&runtime.includes('src/version.mjs'));
  assert.ok((await read('native/TrayHost.cs')).includes(versions.windows));
  assert.ok((await read('native/Installer.cs')).includes(versions.windows));
  assert.ok((await read('mac/Install.command')).includes(versions.macos));
  assert.equal(JSON.parse(await read('mac/trust.json')).teamIdentifier,null,'Mac remains gated before acceptance');
});
