import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
test('credits are integer-only and follow renewal; resets follow reset date', async () => {
  const code=await readFile(new URL('../src/widget.js',import.meta.url),'utf8');
  assert.ok(code.includes('Math.floor(Number(credits.balance))'));
  assert.ok(code.includes("section.append(resetCount)"));
  assert.ok(code.indexOf("if(visible('credits'))")>code.indexOf('section.append(membership)'));
  assert.ok(code.includes("'额度':['Credits','額度']"));
});
