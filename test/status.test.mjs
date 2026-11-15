import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { recordStatus } from '../src/status.mjs';
test('diagnostics persist only allow-listed metadata, never account payloads', async () => {
  const dir=await mkdtemp(join(process.cwd(),'.status-test-'));
  try {
    const path=join(dir,'status.json');
    await recordStatus(path,'sidebar-missing',{port:9222,mountedCount:0,quotaAvailable:false,secret:'never-write',buckets:[{id:'private'}]});
    const raw=await readFile(path,'utf8'), value=JSON.parse(raw);
    assert.equal(value.stage,'sidebar-missing');
    assert.equal(value.port,9222);
    assert.equal(raw.includes('never-write'),false);
    assert.equal(raw.includes('private'),false);
  } finally { await rm(dir,{recursive:true,force:true}); }
});
