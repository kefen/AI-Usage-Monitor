import {readFile,stat} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
export function decodeRequest(buffer){
  if(buffer.length<4)return null;
  const size=buffer.readUInt32LE(0);if(size<2||size>4096)throw new Error('Invalid frame');
  if(buffer.length<4+size)return null;
  const message=JSON.parse(buffer.subarray(4,4+size).toString('utf8'));
  if(message.op!=='read'||Object.keys(message).length!==1)throw new Error('Unsupported command');
  return message;
}
export function safeSnapshot(value,now=Date.now()){
  const number=n=>Number.isFinite(n)&&n>=0?n:null,count=n=>Number.isSafeInteger(n)&&n>=0?n:null;
  if(value?.schema!==1||number(value.generatedAt)===null||value.generatedAt>now+5000||now-value.generatedAt>90000)return {ok:false,code:'STALE'};
  const fresh=number(value.quotaAt)!==null&&now-value.quotaAt<180000&&value.quotaAt<=now+5000;
  const usageFresh=number(value.usageAt)!==null&&now-value.usageAt<5400000&&value.usageAt<=now+5000;
  return {ok:true,generatedAt:value.generatedAt,quotaAt:number(value.quotaAt),usageAt:number(value.usageAt),windows:fresh&&Array.isArray(value.windows)?value.windows.slice(0,32).filter(w=>number(w.minutes)!==null&&number(w.remaining)!==null&&w.remaining<=100).map(w=>({minutes:w.minutes,remaining:w.remaining,resetsAt:number(w.resetsAt)})):[],resetCredits:fresh?count(value.resetCredits):null,creditBalance:fresh&&typeof value.creditBalance==='string'&&/^\d+(\.\d+)?$/.test(value.creditBalance)?value.creditBalance:null,lifetime:usageFresh?count(value.lifetime):null,week:usageFresh?count(value.week):null,monthAverage:usageFresh?count(value.monthAverage):null,daily:usageFresh&&/^\d{4}-\d{2}-\d{2}$/.test(value.daily?.date)&&count(value.daily.value)!==null?{date:value.daily.date,value:value.daily.value}:null};
}
async function main(){
  const send=value=>{const data=Buffer.from(JSON.stringify(value)),head=Buffer.alloc(4);head.writeUInt32LE(data.length);process.stdout.write(Buffer.concat([head,data]));};
  try{
    const config=JSON.parse(await readFile(new URL('../.runtime/browser-host.json',import.meta.url),'utf8'));
    if(!/^[a-p]{32}$/.test(config.extensionId)||process.argv[2]!==`chrome-extension://${config.extensionId}/`)throw new Error('Origin denied');
    let buffer=Buffer.alloc(0);const timer=setTimeout(()=>{process.stdin.destroy();},5000);
    try{for await(const chunk of process.stdin){buffer=Buffer.concat([buffer,chunk]);if(buffer.length>4100)throw new Error('Frame too large');if(decodeRequest(buffer))break;}}finally{clearTimeout(timer);process.stdin.destroy();}
    if(!decodeRequest(buffer))throw new Error('Incomplete request');
    const path=new URL('../.runtime/browser-state.json',import.meta.url);if((await stat(path)).size>64000)throw new Error('Snapshot too large');
    send(safeSnapshot(JSON.parse(await readFile(path,'utf8'))));
  }catch{send({ok:false,code:'UNAVAILABLE'});}
}
if(process.argv[1]===fileURLToPath(import.meta.url))await main();
