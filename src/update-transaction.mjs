import {readFile,writeFile,mkdir,lstat,copyFile,rename} from 'node:fs/promises';
import {realpathSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';

const settings=['membership.json','display.json','language.json','preferences.json','daily-availability.json'];
const canonical=value=>JSON.stringify(value,(_key,v)=>v&&typeof v==='object'&&!Array.isArray(v)?Object.fromEntries(Object.keys(v).sort().map(k=>[k,v[k]])):v);
const retained=(before,after)=>before&&typeof before==='object'&&!Array.isArray(before)?after&&typeof after==='object'&&Object.keys(before).every(k=>Object.hasOwn(after,k)&&retained(before[k],after[k])):canonical(before)===canonical(after);
async function setting(path,name){
 const info=await lstat(path);if(!info.isFile()||info.isSymbolicLink()||info.size>131072)throw Error('Invalid saved settings: '+name);
 const raw=await readFile(path);let value;try{value=JSON.parse(raw);}catch{throw Error('Invalid saved settings: '+name);}
 if(name==='language.json'? !['en','zh-CN','zh-TW'].includes(value):!value||Array.isArray(value)||typeof value!=='object')throw Error('Invalid saved settings: '+name);
 return {raw,value};
}
export async function backupSettings(root,folder){
 await mkdir(folder,{recursive:true,mode:0o700});const files=[];
 for(const name of settings){let data;try{data=await setting(join(root,'.runtime',name),name);}catch(e){if(e.code==='ENOENT')continue;throw e;}await writeFile(join(folder,name),data.raw,{mode:0o600});files.push(name);}
 await writeFile(join(folder,'manifest.json'),JSON.stringify({schema:1,files}),{mode:0o600});return {files};
}
export async function verifySettings(root,folder){
 const manifest=JSON.parse(await readFile(join(folder,'manifest.json'),'utf8'));
 if(manifest.schema!==1||!Array.isArray(manifest.files)||manifest.files.some(n=>!settings.includes(n)))throw Error('Invalid settings backup');
 for(const name of manifest.files){const before=await setting(join(folder,name),name),after=await setting(join(root,'.runtime',name),name);if(!retained(before.value,after.value))throw Error('Settings changed: '+name);}
}
export async function restoreSettings(root,folder){
 const manifest=JSON.parse(await readFile(join(folder,'manifest.json'),'utf8'));
 if(manifest.schema!==1||!Array.isArray(manifest.files)||manifest.files.some(n=>!settings.includes(n)))throw Error('Invalid settings backup');
 for(const name of manifest.files){await setting(join(folder,name),name);const path=join(root,'.runtime',name);await copyFile(join(folder,name),path+'.restore');await rename(path+'.restore',path);}
}
export function localizedNotes(notes,language='en'){
 const selected=typeof notes==='string'?(language==='en'?[notes]:[]):notes?.[language];
 if(!Array.isArray(selected))return '';
 return selected.slice(0,12).filter(v=>typeof v==='string'&&v.trim()).map((v,i)=>(i+1)+'. '+v.replace(/[\r\n]+/g,' ').slice(0,240)).join('\n');
}
export function canonicalEntry(argument,url,real=realpathSync){try{return !!argument&&real(argument)===real(fileURLToPath(url));}catch{return false;}}
export async function transactionState(path,stage,fields={}){
 const value={schema:1,stage,updatedAt:Date.now(),...fields};await writeFile(path+'.tmp',JSON.stringify(value),{mode:0o600});await rename(path+'.tmp',path);return value;
}
export async function waitForRecord(path,predicate,timeout=10000){
 const deadline=Date.now()+timeout;
 while(Date.now()<deadline){try{const record=JSON.parse(await readFile(path,'utf8'));if(predicate(record))return record;}catch{}await new Promise(r=>setTimeout(r,100));}
 throw Error('E_UPDATE_HANDSHAKE_TIMEOUT');
}
