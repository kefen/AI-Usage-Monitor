const status=document.querySelector('#status'),list=document.querySelector('#metrics'),button=document.querySelector('#refresh'),stamp=document.querySelector('#stamp'),language=document.querySelector('#language');
const allowed=['en','zh-CN','zh-TW'];
let locale='en';try{locale=localStorage.getItem('cqs-language')||navigator.language;}catch{}
locale=allowed.includes(locale)?locale:locale.startsWith('zh')?(locale.includes('Hant')||locale.includes('HK')?'zh-TW':'zh-CN'):'en';
const t=key=>locale==='en'?key:(CQS_STRINGS[key]?.[locale==='zh-TW'?1:0]||key);
document.querySelector('#extension-id').textContent=chrome.runtime.id;
document.querySelector('#version').textContent=' / '+(chrome.runtime.getManifest?.().version||'0.2.1');
let busy=false,last=0,data=null,error=false;
function row(label,value){const dt=document.createElement('dt'),dd=document.createElement('dd');dt.textContent=label;dd.textContent=value;list.append(dt,dd);}
const count=n=>Number.isSafeInteger(n)&&n>=0?n.toLocaleString(locale):'--';
function render(){
 document.documentElement.lang=locale;language.value=locale;
 document.querySelectorAll('[data-i18n]').forEach(el=>el.textContent=t(el.dataset.i18n));list.replaceChildren();
 if(error){status.textContent=t('Local helper not connected');stamp.textContent=t('Check the desktop monitor and native host registration.');return;}
 if(!data||!data.ok){status.textContent=t(data?.code==='STALE'?'Snapshot expired':'Local snapshot unavailable');stamp.textContent=t('Check the desktop monitor and native host registration.');return;}
 status.textContent=t('Quota snapshot read');
 for(const w of data.windows||[])row(t(w.minutes===300?'5-hour remaining':w.minutes===10080?'Weekly remaining':'Remaining quota'),w.remaining+'%');
 if(!data.windows?.length)row(t('Remaining quota'),t('Unavailable'));
 if(data.daily)row(data.daily.date+' · '+t('Daily tokens'),count(data.daily.value));
 row(t('Weekly tokens'),count(data.week));row(t('Lifetime tokens'),count(data.lifetime));
 stamp.textContent=t('Quota synced')+': '+(data.quotaAt?new Date(data.quotaAt).toLocaleString(locale):'--')+' / '+t('Tokens synced')+': '+(data.usageAt?new Date(data.usageAt).toLocaleString(locale):'--');
}
async function refresh(){
 if(busy||document.hidden||Date.now()-last<60000)return;busy=true;last=Date.now();button.disabled=true;
 try{data=await chrome.runtime.sendNativeMessage('org.kefen.codex_quota_sidebar',{op:'read'});error=false;}
 catch{data=null;error=true;}
 finally{busy=false;render();setTimeout(()=>button.disabled=false,Math.max(0,60000-(Date.now()-last)));}
}
language.addEventListener('change',()=>{locale=language.value;try{localStorage.setItem('cqs-language',locale);}catch{}render();});
button.addEventListener('click',refresh);document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh();});setInterval(refresh,60000);render();refresh();
