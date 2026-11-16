const status=document.querySelector('#status'),list=document.querySelector('#metrics'),button=document.querySelector('#refresh'),stamp=document.querySelector('#stamp'),language=document.querySelector('#language');
const allowed=['en','zh-CN','zh-TW'];
let locale='en';try{locale=localStorage.getItem('cqs-language')||navigator.language;}catch{}
locale=allowed.includes(locale)?locale:locale.startsWith('zh')?(locale.includes('Hant')||locale.includes('HK')?'zh-TW':'zh-CN'):'en';
const t=key=>locale==='en'?key:(CQS_STRINGS[key]?.[locale==='zh-TW'?1:0]||key);
document.querySelector('#extension-id').textContent=chrome.runtime.id;
document.querySelector('#help-id').textContent=chrome.runtime.id;
document.querySelector('#version').textContent='v'+(chrome.runtime.getManifest?.().version||'0.3.0');
const choices=['5-hour remaining','Weekly remaining','Daily tokens','Weekly tokens','Lifetime tokens'];
let visible={};try{visible=JSON.parse(localStorage.getItem('cqs-visible')||'{}');if(!visible||typeof visible!=='object')visible={};}catch{}
function switchPage(id){document.querySelectorAll('main>section').forEach(el=>el.hidden=el.id!==id);document.querySelectorAll('[data-page]').forEach(el=>el.setAttribute('aria-current',el.dataset.page===id?'page':'false'));}
document.querySelectorAll('[data-page]').forEach(el=>el.addEventListener('click',()=>switchPage(el.dataset.page)));
switchPage('overview');
let busy=false,last=0,data=null,error=false;
function row(label,value){const dt=document.createElement('dt'),dd=document.createElement('dd');dt.textContent=label;dd.textContent=value;list.append(dt,dd);}
const count=n=>Number.isSafeInteger(n)&&n>=0?n.toLocaleString(locale):'--';
function render(){
 document.documentElement.lang=locale;language.value=locale;
 document.querySelectorAll('[data-i18n]').forEach(el=>el.textContent=t(el.dataset.i18n));list.replaceChildren();
 const controls=document.querySelector('#choices');
 if(!controls.children.length)for(const key of choices){const label=document.createElement('label'),check=document.createElement('input');check.type='checkbox';check.addEventListener('change',()=>{visible[key]=check.checked;try{localStorage.setItem('cqs-visible',JSON.stringify(visible));}catch{}render();});label.append(check,document.createTextNode(''));controls.append(label);}
 choices.forEach((key,index)=>{const label=controls.children[index];label.firstChild.checked=visible[key]!==false;label.lastChild.textContent=t(key);});
 if(error){status.textContent=t('Local helper not connected');stamp.textContent=t('Check the desktop monitor and native host registration.');return;}
 if(!data||!data.ok){status.textContent=t(data?.code==='STALE'?'Snapshot expired':'Local snapshot unavailable');stamp.textContent=t('Check the desktop monitor and native host registration.');return;}
 status.textContent=t('Quota snapshot read');
 for(const w of data.windows||[]){const key=w.minutes===300?'5-hour remaining':w.minutes===10080?'Weekly remaining':'Remaining quota';if(visible[key]!==false)row(t(key),w.remaining+'%');}
 if(!data.windows?.length)row(t('Remaining quota'),t('Unavailable'));
 if(data.daily&&visible['Daily tokens']!==false)row(data.daily.date+' · '+t('Daily tokens'),count(data.daily.value));
 if(visible['Weekly tokens']!==false)row(t('Weekly tokens'),count(data.week));if(visible['Lifetime tokens']!==false)row(t('Lifetime tokens'),count(data.lifetime));
 stamp.textContent=t('Quota synced')+': '+(data.quotaAt?new Date(data.quotaAt).toLocaleString(locale):'--')+' / '+t('Tokens synced')+': '+(data.usageAt?new Date(data.usageAt).toLocaleString(locale):'--');
}
async function refresh(){
 if(busy||document.hidden||Date.now()-last<60000){document.querySelector('#help-feedback').textContent=t('Please wait for the next refresh.');return;}busy=true;last=Date.now();button.disabled=true;
 try{data=await chrome.runtime.sendNativeMessage('org.kefen.codex_quota_sidebar',{op:'read'});error=false;}
 catch{data=null;error=true;}
 finally{busy=false;render();setTimeout(()=>button.disabled=false,Math.max(0,60000-(Date.now()-last)));}
}
language.addEventListener('change',()=>{locale=language.value;try{localStorage.setItem('cqs-language',locale);}catch{}render();});
button.addEventListener('click',refresh);document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh();});setInterval(refresh,60000);render();refresh();
document.querySelector('#retry').addEventListener('click',refresh);
document.querySelector('#export').addEventListener('click',()=>{
 const report={tool:'Codex Quota Sidebar by KEFEN',version:chrome.runtime.getManifest?.().version||'0.3.0',connection:error?'helper-unavailable':data?.ok?'snapshot-read':'snapshot-unavailable',exportedAt:new Date().toISOString()};
 const url=URL.createObjectURL(new Blob([JSON.stringify(report,null,2)],{type:'application/json'}));const link=document.createElement('a');link.href=url;link.download='Codex-Quota-Sidebar-browser-diagnostics.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 document.querySelector('#help-feedback').textContent=t('Review diagnostics before attaching them to a GitHub issue. No files are uploaded automatically.');
});
