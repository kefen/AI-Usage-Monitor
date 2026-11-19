import {readFile,stat} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {resolve,join} from 'node:path';
import {normalizeDisplay,planBadge} from '../src/display-settings.mjs';
import {normalizeMembership} from '../src/settings.mjs';
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
  const date=value?.renewalDate;
  const metadata={visible:normalizeDisplay(value?.visible),planBadge:['Free','Go','Plus','Pro','Biz','Ent','Edu','Other'].includes(value?.planBadge)?value.planBadge:null,renewalDate:typeof date==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(date)&&Number.isFinite(Date.parse(date+'T00:00:00Z'))&&new Date(date+'T00:00:00Z').toISOString().slice(0,10)===date?date:null,planSource:['desktop','manual'].includes(value?.planSource)?value.planSource:'unknown'};
  if(value?.schema!==1||number(value.generatedAt)===null||value.generatedAt>now+5000||now-value.generatedAt>90000)return {...metadata,ok:false,code:'STALE'};
  const fresh=number(value.quotaAt)!==null&&now-value.quotaAt<180000&&value.quotaAt<=now+5000;
  const usageFresh=number(value.usageAt)!==null&&now-value.usageAt<5400000&&value.usageAt<=now+5000;
  const monthTotal=usageFresh&&new Date(value.generatedAt).toISOString().slice(0,7)===new Date(now).toISOString().slice(0,7)?count(value.monthTotal):null;
  return {...metadata,ok:true,generatedAt:value.generatedAt,quotaAt:number(value.quotaAt),usageAt:number(value.usageAt),windows:fresh&&Array.isArray(value.windows)?value.windows.slice(0,32).filter(w=>w&&number(w.minutes)!==null&&number(w.remaining)!==null&&w.remaining<=100).map(w=>({minutes:w.minutes,remaining:w.remaining,resetsAt:number(w.resetsAt)})):[],resetCredits:fresh?count(value.resetCredits):null,creditBalance:fresh&&typeof value.creditBalance==='string'&&/^\d+(\.\d+)?$/.test(value.creditBalance)?value.creditBalance:null,lifetime:usageFresh?count(value.lifetime):null,week:usageFresh?count(value.week):null,monthAverage:usageFresh?count(value.monthAverage):null,monthTotal,monthPartial:monthTotal!==null&&value.monthPartial===true,daily:usageFresh&&/^\d{4}-\d{2}-\d{2}$/.test(value.daily?.date)&&count(value.daily.value)!==null?{date:value.daily.date,value:value.daily.value}:null};
}
async function readJSON(path){
  if((await stat(path)).size>64000)throw new Error('File too large');
  return JSON.parse(await readFile(path,'utf8'));
}
export async function readBrowserState(root,now=Date.now()){
  const runtime=join(resolve(root),'.runtime');
  let value={},unavailable=false;try{value=await readJSON(join(runtime,'browser-state.json'));}catch{unavailable=true;}
  // Local settings take precedence without requiring the quota producer to run.
  try{value={...value,visible:normalizeDisplay(await readJSON(join(runtime,'display.json')))};}catch{}
  try{
    const member=await readJSON(join(runtime,'membership.json'));
    value={...value,planBadge:planBadge(member),renewalDate:normalizeMembership(member)?.date||null,planSource:member?.planSource==='desktop'?'desktop':member?.plan?'manual':'unknown'};
  }catch{}
  const result=safeSnapshot(value,now);
  return unavailable?{...result,ok:false,code:'UNAVAILABLE'}:result;
}
async function main(){
  const send=value=>{const data=Buffer.from(JSON.stringify(value)),head=Buffer.alloc(4);head.writeUInt32LE(data.length);process.stdout.write(Buffer.concat([head,data]));};
  try{
    const config=JSON.parse(await readFile(new URL('../.runtime/browser-host.json',import.meta.url),'utf8'));
    if(!/^[a-p]{32}$/.test(config.extensionId)||process.argv[2]!==`chrome-extension://${config.extensionId}/`)throw new Error('Origin denied');
    let buffer=Buffer.alloc(0);const timer=setTimeout(()=>{process.stdin.destroy();},5000);
    try{for await(const chunk of process.stdin){buffer=Buffer.concat([buffer,chunk]);if(buffer.length>4100)throw new Error('Frame too large');if(decodeRequest(buffer))break;}}finally{clearTimeout(timer);process.stdin.destroy();}
    if(!decodeRequest(buffer))throw new Error('Incomplete request');
    send(await readBrowserState(fileURLToPath(new URL('../',import.meta.url))));
  }catch{send({ok:false,code:'UNAVAILABLE'});}
}
if(process.argv[1]===fileURLToPath(import.meta.url))await main();
