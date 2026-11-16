import {readFile} from 'node:fs/promises';
import {watch} from 'node:fs';
export function watchDisplay(root,onChange){
  let timer,closed=false;
  const watcher=watch(root,(_event,file)=>{
    if(!['display.json','membership.json','language.json'].includes(String(file)))return;
    clearTimeout(timer);timer=setTimeout(()=>{if(!closed)Promise.resolve().then(onChange).catch(()=>{});},120);
  });
  watcher.on('error',()=>{});
  return ()=>{closed=true;clearTimeout(timer);watcher.close();};
}
export const displayKeys=['plan','short','week','reset','renewal','daily','average','weekly','lifetime','credits','resetCredits'];
export function normalizeDisplay(value){return Object.fromEntries(displayKeys.map(key=>[key,typeof value?.[key]==='boolean'?value[key]:true]));}
export function planBadge(value){const plan=String(value?.plan||'').toLowerCase();return ({free:'Free',go:'Go',plus:'Plus',pro:'Pro',business:'Biz',enterprise:'Ent',edu:'Edu',other:'Other'})[plan]||'?';}
export async function readDisplay(root){let display={},member={},language='zh-CN';try{display=JSON.parse(await readFile(new URL('display.json',root),'utf8'));}catch{}try{member=JSON.parse(await readFile(new URL('membership.json',root),'utf8'));}catch{}try{const saved=JSON.parse(await readFile(new URL('language.json',root),'utf8'));if(['en','zh-CN','zh-TW'].includes(saved))language=saved;}catch{}return {visible:normalizeDisplay(display),planBadge:planBadge(member),language};}
