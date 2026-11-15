import { spawn } from 'node:child_process';

export function readLimits({ command = 'codex', args = ['app-server'], timeoutMs = 15000 } = {}) {
  return readAccount({command,args,timeoutMs,method:'account/rateLimits/read'});
}

export function readUsage({ command = 'codex', args = ['app-server'], timeoutMs = 12000 } = {}) {
  return readAccount({command,args,timeoutMs,method:'account/usage/read'});
}

export function readSnapshot({ command = 'codex', args = ['app-server'], timeoutMs = 15000 } = {}) {
  return readAccount({command,args,timeoutMs,method:'account/rateLimits/read',combined:true});
}

function readAccount({command,args,timeoutMs,method,combined=false}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'], shell: false });
    let buffer = '', total = 0, settled = false, outcome, failure, expectedId=1;
    const snapshot={};
    const finish = (error, value) => {
      if (settled) return;
      settled = true;
      failure = error;
      outcome = value;
      clearTimeout(timer);
      child.stdin.end();
      child.kill();
    };
    let timer;
    const timeout=()=>{
      if(combined && expectedId===3) finish(null,{...snapshot,usageError:'Token activity timed out'});
      else finish(new Error('Quota read timed out'));
    };
    const arm=()=>{clearTimeout(timer);timer=setTimeout(timeout,timeoutMs);};
    arm();
    const send = data => { if (!child.stdin.destroyed) child.stdin.write(JSON.stringify(data) + '\n'); };
    child.once('spawn', () => send({ id: 1, method: 'initialize', params: {
      clientInfo: { name: 'local_sidebar_meter', title: 'Local Sidebar Meter', version: '0.1.0' }
    } }));
    child.stdin.on('error', () => finish(new Error('Quota process input unavailable')));
    child.on('error', () => finish(new Error('Codex CLI could not start')));
    // stderr can contain paths and authentication details: drain it, never log it.
    child.stderr.resume();
    child.stdout.setEncoding('utf8');
    child.stdout.on('data', chunk => {
      total += Buffer.byteLength(chunk);
      if (total > 1_000_000) return finish(new Error('Quota response exceeded size limit'));
      buffer += chunk.toString('utf8');
      let end;
      while ((end = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, end); buffer = buffer.slice(end + 1);
        let message;
        try { message = JSON.parse(line); } catch { continue; }
        if (settled || message.id !== expectedId) continue;
        if (message.error && (message.id===1 || !combined)) return finish(new Error(`Quota RPC rejected request ${message.id}`));
        if (message.id === 1) {
          expectedId=2;arm();
          send({ method: 'initialized' });
          send({ id: 2, method });
        } else if(combined && message.id===2) {
          if(message.error) snapshot.limitsError='Quota read unavailable';else snapshot.limits=message.result;
          expectedId=3;arm();send({id:3,method:'account/usage/read'});
        } else if(combined) {
          if(message.error) snapshot.usageError='Token activity unavailable';else snapshot.usage=message.result;
          finish(null,snapshot);
        } else { finish(null, message.result); }
      }
    });
    child.once('close', () => {
      clearTimeout(timer);
      if (!settled) {
        if(combined && expectedId===3){outcome={...snapshot,usageError:'Token activity process exited'};}
        else failure = new Error('Quota process exited before returning data');
        settled = true;
      }
      if (failure) reject(failure); else resolve(outcome);
    });
  });
}
