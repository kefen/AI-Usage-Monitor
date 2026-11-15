import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm, cp } from 'node:fs/promises';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
test('background stop request exits monitor without starting an account process',async()=>{
  const root=await mkdtemp(join(process.cwd(),'.stop-test-'));
  let child;
  try {
    await cp(new URL('../src',import.meta.url),join(root,'src'),{recursive:true});
    await cp(new URL('../versions.json',import.meta.url),join(root,'versions.json'));
    const stopFile=join(root,'stop.request');await writeFile(stopFile,'stop');
    const result=await new Promise((resolve,reject)=>{
      child=spawn(process.execPath,[join(root,'src/cli.mjs'),'attach','--port','65533','--stop-file',stopFile,'--codex','must-not-be-launched'],{windowsHide:true});
      let output='';child.stdout.on('data',d=>output+=d);child.stderr.resume();
      const timeout=setTimeout(()=>{child.kill();reject(new Error('Background stop request was ignored'));},6000);
      child.on('error',reject);child.on('close',code=>{clearTimeout(timeout);resolve({code,output});});
    });
    assert.equal(result.code,0);assert.ok(result.output.includes('Meter stopped'));
    assert.equal(result.output.includes('Quota unavailable'),false);
  } finally {if(child && child.exitCode===null)child.kill();await rm(root,{recursive:true,force:true});}
});
