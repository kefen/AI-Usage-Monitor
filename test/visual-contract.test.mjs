import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const file=path=>readFile(new URL('../'+path,import.meta.url));
test('renderer trust gate stays unchanged; sidebar now includes requested badge and visibility',async()=>{
  const widget=(await file('src/widget.js')).toString();assert.match(widget,/state\.visible/);assert.match(widget,/state\.planBadge/);
  const versions=JSON.parse(await file('versions.json'));assert.ok(widget.includes("version:'"+versions.windows+"'"));
  assert.match(widget,/state\.planSource/);
  const renderer=(await file('src/renderer-expression.mjs')).toString();
  assert.match(renderer,/location.protocol === 'app:'/);
  assert.match(renderer,/if \(!mainShell\) return/);
});
test('both native shells use packaged brand icons and local configuration only',async()=>{
  assert.match((await file('native/Theme.cs')).toString(),/cqs\.ico/);
  assert.match((await file('mac/QuotaSidebar.swift')).toString(),/statusItem/);
  assert.match((await file('mac/QuotaSidebar.swift')).toString(),/membership\.json/);
});
