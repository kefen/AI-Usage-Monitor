import {readFile,readdir} from 'node:fs/promises';
const catalog=JSON.parse(await readFile('ui/strings.json','utf8')),known=new Set(Object.values(catalog).flat()),missing=new Set();
for(const path of [...(await readdir('native')).filter(x=>x.endsWith('.cs')).map(x=>'native/'+x),'mac/QuotaSidebar.swift']){
 const source=await readFile(path,'utf8');
 for(const match of source.matchAll(/"(?:[^"\\]|\\.)*"/g)){
  try{const text=JSON.parse(match[0]);if(/[\u4e00-\u9fff]/.test(text)&&!known.has(text)&&!['简体中文','繁體中文'].includes(text))missing.add(text);}catch{}
 }
}
console.log(JSON.stringify([...missing],null,2));
