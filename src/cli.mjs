import { readFile, writeFile, rename, unlink } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { setTimeout as delay } from 'node:timers/promises';
import { readLimits, readUsage, readSnapshot } from './rpc.mjs';
import { normalizeUsage, observeAvailability } from './usage.mjs';
import {version} from './version.mjs';
import { nextUsageRefresh, readMembership } from './settings.mjs';
import { normalizeLimits } from './core.mjs';
import { listTargets, evaluate, watchOverview } from './cdp.mjs';
import { rendererExpression } from './renderer-expression.mjs';
import { recordStatus } from './status.mjs';
import { browserSnapshot } from './browser-snapshot.mjs';
import { readDisplay, watchDisplay } from './display-settings.mjs';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const option = key => args.includes(key) ? args[args.indexOf(key) + 1] : undefined;
const command = option('--codex') || process.env.CODEX_METER_CLI || 'codex';

if (args[0] === 'usage') {
  try { console.log(JSON.stringify(normalizeUsage(await readUsage({command})),null,2)); }
  catch(e) { console.error(e.message); process.exitCode=1; }
} else if (args[0] === 'probe') {
  try {
    const result = normalizeLimits(await readLimits({ command }));
    console.log(JSON.stringify(result, null, 2));
    if (!result.buckets.length) process.exitCode = 2;
  } catch (e) { console.error(e.message); process.exitCode = 1; }
} else if (args[0] === 'attach') {
  const port = Number(option('--port'));
  if (!Number.isInteger(port) || port < 1024 || port > 65535) {
    console.error('Use Start.cmd, or: node src/cli.mjs attach --port PORT --codex PATH');
    process.exitCode = 1;
  } else {
    const widget = await readFile(new URL('./widget.js', import.meta.url), 'utf8');
    const statusPath = fileURLToPath(new URL('../.runtime/status.json',import.meta.url));
    const membershipPath = fileURLToPath(new URL('../.runtime/membership.json',import.meta.url));
    const observationPath=fileURLToPath(new URL('../.runtime/daily-availability.json',import.meta.url));
    const refreshPath=fileURLToPath(new URL('../.runtime/refresh.request',import.meta.url));
    const clearPath=fileURLToPath(new URL('../.runtime/clear-history.request',import.meta.url));
    let observation={},observedAt=0,lastManual=0;
    try{observation=JSON.parse(await readFile(observationPath,'utf8'));}catch{}
    const report = (stage, fields={}) => recordStatus(statusPath,stage,{port,...fields});
    let state = { buckets: [], error: 'Waiting for first quota read' }, usage={error:'Waiting for usage'};
    let stopping = false, connectedOnce=false, nextRead = 0, nextUsage = 0, nextStatus = 0, lastConnection = Date.now(), mainTargetId=null;
    const stopFile=option('--stop-file');
    const shouldStop=()=>stopping || (stopFile && existsSync(stopFile));
    let cachedTargets=[],paintQueue=Promise.resolve(),closeDisplay=()=>{};
    let actionChannel=null,actionTarget=null,sidebarMode='hidden',sidebarReason='sidebar-unrecognized';
    const paint=()=>{
      const work=async()=>{
        if(shouldStop())return 0;
        const membership=await readMembership(membershipPath);
        const display=await readDisplay(new URL('../.runtime/',import.meta.url));
        try {const path=fileURLToPath(new URL('../.runtime/browser-state.json',import.meta.url));await writeFile(path+'.tmp',JSON.stringify(browserSnapshot(state,usage,Date.now(),display)),{mode:0o600});await rename(path+'.tmp',path);}catch{}
        const expression=rendererExpression(widget,{...state,...display,usage:{...usage,observations:observation.records||[]},membership});
        const known=cachedTargets.find(t=>t.id===mainTargetId);
        for(const target of known?[known]:cachedTargets){
          try{
            const result=await evaluate(target,port,expression);
            if(result?.reason==='sidebar-check'){
              sidebarMode=result.layout?.mode||'hidden';sidebarReason=result.layout?.reason||'sidebar-unrecognized';
              if(actionTarget!==target.id||!actionChannel?.active()){
                actionChannel?.close();actionTarget=target.id;
                actionChannel=watchOverview(target,port,()=>{if(!shouldStop())return writeFile(new URL('../.runtime/background-open.request',import.meta.url),'open',{mode:0o600});});
              }
              if(result.mounted===true){mainTargetId=target.id;return 1;}
            }
          }catch{}
        }
        mainTargetId=null;return 0;
      };
      paintQueue=paintQueue.then(work,work);return paintQueue;
    };
    const stop = () => { stopping = true; };
    process.on('SIGINT', stop); process.on('SIGTERM', stop);
    console.log(`AI Quota Board ${version} - Stop from the tray menu, Stop.cmd, or Ctrl+C in console mode.`);
    console.log('Token activity: once at startup, then every 60 minutes.');
    console.log('Source: local Codex CLI account. Verify it matches your desktop account.');
    try {
      await report('waiting-for-renderer');
      closeDisplay=watchDisplay(new URL('../.runtime/',import.meta.url),paint);
      while (!shouldStop()) {
        let targets = [];
        try { targets = await listTargets(port); } catch { /* app may still be starting */ }
        cachedTargets=targets;
        if(actionTarget&&!targets.some(t=>t.id===actionTarget)){actionChannel?.close();actionChannel=null;actionTarget=null;}
        if (targets.length) {
          if(existsSync(clearPath)){await unlink(clearPath).catch(()=>{});observation={};observedAt=0;await unlink(observationPath).catch(()=>{});}
          if(existsSync(refreshPath)){
            await unlink(refreshPath).catch(()=>{});
            if(Date.now()-lastManual>=60000){nextRead=0;nextUsage=0;lastManual=Date.now();}
          }
          connectedOnce=true;
          lastConnection = Date.now();
          if(Date.now()>=nextRead && Date.now()>=nextUsage) {
            try {
              const snapshot=await readSnapshot({command});
              state=snapshot.limits ? normalizeLimits(snapshot.limits) : {...state,error:snapshot.limitsError};
              usage=snapshot.usage ? normalizeUsage(snapshot.usage) : {error:snapshot.usageError};
              console.log('Account snapshot refreshed in one CLI process.');
            } catch {state={...state,error:'Account snapshot unavailable'};usage={error:'Account snapshot unavailable'};}
            nextRead=Date.now()+60000;nextUsage=nextUsageRefresh();usage={...usage,nextRefreshAt:nextUsage};
          } else if (Date.now() >= nextRead) {
            try {
              state = normalizeLimits(await readLimits({ command }));
              console.log(state.buckets.length ? 'Quota refreshed.' : 'Server returned no quota windows.');
            } catch (e) {
              state = { ...state, error: e.message };
              console.log('Quota unavailable; the panel will mark stale data.');
            }
            nextRead = Date.now() + 60000;
          }
          if (shouldStop()) break;
          if(Date.now()>=nextUsage) {
            try {
              usage=normalizeUsage(await readUsage({command}));
              console.log('Account token activity refreshed.');
            } catch {
              usage={error:'Account usage unavailable'};
              console.log('Account token activity unavailable; no totals will be invented.');
            }
            nextUsage=nextUsageRefresh();
            usage={...usage,nextRefreshAt:nextUsage};
          }
          if(shouldStop()) break;
          if(usage.fetchedAt && usage.fetchedAt!==observedAt){
            observation=observeAvailability(observation,usage);observedAt=usage.fetchedAt;
            try{await writeFile(observationPath+'.tmp',JSON.stringify(observation),{mode:0o600});await rename(observationPath+'.tmp',observationPath);}catch{console.log('Availability history could not be saved.');}
          }
          // Only normalized numeric quota metadata crosses into the renderer.
          const mounted=await paint();
          await report(mounted ? (state.error ? 'mounted-quota-unavailable' : 'mounted') : 'sidebar-missing', {
            sidebarMode,sidebarReason,targetCount:targets.length,mountedCount:mounted,quotaAvailable:!state.error && state.buckets.length>0,
            usageAvailable:!usage.error && (usage.lifetime!=null || usage.week?.value!=null || usage.month?.value!=null),nextUsageAt:nextUsage,usageReadAt:usage.fetchedAt
          });
          if (Date.now() >= nextStatus) {
            console.log(mounted ? 'Sidebar panel attached.' : 'Waiting for a recognized expanded sidebar; no floating fallback is used.');
            nextStatus = Date.now() + 60000;
          }
        } else {
          await report('waiting-for-renderer');
          if (Date.now() - lastConnection > 90000) {
            if(connectedOnce) break;
            throw new Error('No trusted Codex debug page found within 90 seconds. No app files were changed.');
          }
        }
        for (let i = 0; i < 20 && !shouldStop(); i++) await delay(1000);
      }
    } catch (e) { console.error(e.message); process.exitCode = 1; await report('attach-failed').catch(()=>{}); }
    finally {
      closeDisplay();await paintQueue.catch(()=>{});actionChannel?.close();
      let targets = [];
      try { targets = await listTargets(port); } catch { /* app already closed */ }
      for (const t of targets) {
        try { await evaluate(t, port, 'window.__localCodexMeter?.dispose();'); } catch { /* lease also removes abandoned widgets */ }
      }
      console.log('Meter stopped. Restart Codex normally to close its debug endpoint.');
      if (!process.exitCode) await report('stopped');
    }
  }
} else {
  console.log('Local Sidebar Meter\n  probe [--codex PATH]\n  attach --port PORT [--codex PATH]\nWindows: use Start.cmd after fully exiting Codex.');
}
