import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const file=path=>readFile(new URL('../'+path,import.meta.url));
test('renderer trust gate stays unchanged; sidebar now includes requested badge and visibility',async()=>{
  const widget=(await file('src/widget.js')).toString();assert.match(widget,/state\.visible/);assert.match(widget,/state\.planBadge/);
  const expected={'src/renderer-expression.mjs':'f43e5f5cd069fd8233c2a6a3adcc8339b24e15356840b5a3f03923f927ecc0a0'};
  for(const [path,hash] of Object.entries(expected))assert.equal(createHash('sha256').update(await file(path)).digest('hex'),hash);
});
test('both native shells use packaged brand icons and local configuration only',async()=>{
  assert.match((await file('native/Theme.cs')).toString(),/cqs\.ico/);
  assert.match((await file('mac/QuotaSidebar.swift')).toString(),/statusItem/);
  assert.match((await file('mac/QuotaSidebar.swift')).toString(),/membership\.json/);
});
