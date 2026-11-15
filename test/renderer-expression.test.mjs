import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { rendererExpression } from '../src/renderer-expression.mjs';
const widget = 'window.__localCodexMeter={receive(value){window.received=value;},mounted(){return true;}};';
test('quota payload enters only the recognized app main shell', () => {
  const context = {location:{protocol:'app:'},document:{querySelector:()=>({})},window:{}};
  const result = vm.runInNewContext(rendererExpression(widget,{buckets:[]}),context);
  assert.equal(result.mounted,true);
  assert.equal(context.window.received.buckets.length,0);
});
test('auxiliary renderers do not receive quota or injected code', () => {
  for (const protocol of ['https:','file:','app:']) {
    const context={location:{protocol},document:{querySelector:()=>null},window:{}};
    const result=vm.runInNewContext(rendererExpression(widget,{buckets:[]}),context);
    assert.equal(result.reason,'not-main-shell');
    assert.equal(context.window.received,undefined);
    assert.equal(context.window.__localCodexMeter,undefined);
  }
});
test('current sidebar-navigation shell works without legacy main/composer markers', () => {
  const context={location:{protocol:'app:'},document:{querySelector:selector=>
    selector.includes('aside.app-shell-left-panel [data-slate-sidebar-content]') ? {} : null
  },window:{}};
  const result=vm.runInNewContext(rendererExpression(widget,{buckets:[]}),context);
  assert.equal(result.mounted,true);
});
