export function parseListeners(output) {
  let pid=0;
  const owners=[];
  for(const line of output.split('\n')){
    if(line.startsWith('p'))pid=Number(line.slice(1));
    if(line.startsWith('n'))owners.push({pid,address:line.slice(1)});
  }
  return owners;
}

export async function verifyListenerOwners({owners,mainPids,port,helperExecutable,inspectProcess,verifyHelper}) {
  const fail=code=>({ok:false,code});
  const mains=new Set(mainPids);
  if(!owners.length || owners.some(o=>!Number.isSafeInteger(o.pid)||o.pid<=1))return fail('E_CDP_OWNER');
  if(owners.some(o=>!['127.0.0.1:'+port,'[::1]:'+port].includes(o.address)))return fail('E_CDP_NONLOCAL');
  // A signed helper alone cannot establish that this is the verified main app's endpoint.
  if(!owners.some(o=>mains.has(o.pid)))return fail('E_CDP_OWNER');
  for(const pid of new Set(owners.map(o=>o.pid).filter(pid=>!mains.has(pid)))){
    try{
      const before=await inspectProcess(pid);
      if(!before || !mains.has(before.parentPid) || before.executable!==helperExecutable)return fail('E_CDP_OWNER');
      if(!await verifyHelper())return fail('E_CDP_HELPER_SIGNATURE');
      const after=await inspectProcess(pid);
      if(!after || after.parentPid!==before.parentPid || after.executable!==before.executable)return fail('E_CDP_OWNER');
    }catch{return fail('E_CDP_HELPER_SIGNATURE');}
  }
  return {ok:true};
}
