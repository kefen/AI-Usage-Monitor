import { validateTarget } from './core.mjs';

// A fixed UI action only: no paths, commands or account data are accepted.
export function watchOverview(target,port,onOpen,Socket=WebSocket){
  if(!validateTarget(target,port))throw new Error('Refused untrusted debug target');
  const socket=new Socket(target.webSocketDebuggerUrl);
  let closed=false,lastOpen=0;
  const timer=setTimeout(()=>close(),4000);
  socket.addEventListener('open',()=>{
    socket.send(JSON.stringify({id:1,method:'Runtime.enable'}));
    socket.send(JSON.stringify({id:2,method:'Runtime.addBinding',params:{name:'__cqsOpenOverview'}}));
  });
  socket.addEventListener('message',event=>{
    if(closed)return;
    let message;try{message=JSON.parse(event.data);}catch{return;}
    if(message.error){close();return;}
    if(message.id===2){
      clearTimeout(timer);
      socket.send(JSON.stringify({id:3,method:'Runtime.evaluate',params:{expression:'window.__localCodexMeter?.refreshLayout?.()',returnByValue:true}}));
    }
    if(message.method!=='Runtime.bindingCalled'||message.params?.name!=='__cqsOpenOverview'||message.params?.payload!=='open-overview')return;
    if(Date.now()-lastOpen<1000)return;
    lastOpen=Date.now();Promise.resolve().then(onOpen).catch(()=>{});
  });
  function close(){if(closed)return;closed=true;clearTimeout(timer);if(socket.readyState<2)socket.close();}
  socket.addEventListener('close',()=>{closed=true;clearTimeout(timer);});
  socket.addEventListener('error',close);
  return {close,active:()=>!closed};
}

export async function listTargets(port, fetcher = fetch) {
  if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error('Invalid local debug port');
  const response = await fetcher(`http://127.0.0.1:${port}/json/list`, {
    signal: AbortSignal.timeout(2500), redirect: 'error'
  });
  if (!response.ok) throw new Error('Local debug endpoint unavailable');
  const targets = await response.json();
  if (!Array.isArray(targets)) throw new Error('Invalid local debug endpoint');
  return targets.filter(t => validateTarget(t, port));
}

export function evaluate(target, port, expression, timeoutMs = 4000, Socket = WebSocket) {
  if (!validateTarget(target, port)) return Promise.reject(new Error('Refused untrusted debug target'));
  return new Promise((resolve, reject) => {
    const socket = new Socket(target.webSocketDebuggerUrl);
    let done = false;
    const finish = (error, result) => {
      if (done) return;
      done = true; clearTimeout(timer);
      if (socket.readyState === WebSocket.OPEN) socket.close();
      else if (socket.readyState === WebSocket.CONNECTING) socket.close();
      if (error) reject(error); else resolve(result);
    };
    const timer = setTimeout(() => finish(new Error('Debug request timed out')), timeoutMs);
    socket.addEventListener('open', () => socket.send(JSON.stringify({
      id: 1, method: 'Runtime.evaluate', params: { expression, returnByValue: true }
    })));
    socket.addEventListener('message', event => {
      let message;
      try { message = JSON.parse(event.data); } catch { return; }
      if (message.id !== 1) return;
      if (message.error || message.result?.exceptionDetails) return finish(new Error('Sidebar script rejected by client'));
      finish(null, message.result?.result?.value);
    });
    socket.addEventListener('error', () => finish(new Error('Local debug socket unavailable')));
    socket.addEventListener('close', () => { if (!done) finish(new Error('Local debug socket closed')); });
  });
}
