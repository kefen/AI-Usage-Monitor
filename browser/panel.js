const $=selector=>document.querySelector(selector);
const locales=['en','zh-CN','zh-TW'];
let locale='en';try{locale=localStorage.getItem('cqs-language')||navigator.language;}catch{}
locale=locales.includes(locale)?locale:locale.startsWith('zh')?(locale.includes('Hant')||locale.includes('HK')?'zh-TW':'zh-CN'):'en';
const strings={
 'Quota and resets':['额度与重置','額度與重設'],
 'Plan and dates':['套餐与日期','方案與日期'],
 'Quota reset date':['额度重置日','額度重設日'],
 'Reset count':['重置次数','重設次數'],
 'Yesterday tokens':['昨日 Token','昨日 Token'],
 'Today tokens':['今日 Token','今日 Token'],
 'Renewal date':['续费日期','續費日期'],
 'Metric':['统计项','統計項目'],'Usage':['用量','用量'],'Status':['状态','狀態'],
 'Connected':['已连接','已連線'],'Synced':['已同步','已同步'],
 'Display choices':['调整展示内容','調整顯示內容'],
 'Uses desktop display choices':['跟随桌面展示选择','跟隨桌面顯示選擇'],
 'No metrics selected':['尚未选择展示项','尚未選取顯示項目'],
 'Usage: local CLI account. Plan: desktop detection or manual record.':['用量：本机 CLI 账户；套餐：Codex 桌面识别或手动记录。','用量：本機 CLI 帳戶；方案：Codex 桌面辨識或手動記錄。'],
 'Cannot open desktop settings from this read-only panel. Open the desktop companion and choose Display choices.':['此只读面板无法打开桌面设置。请打开桌面工具，选择“展示内容”。','此唯讀面板無法開啟桌面設定。請開啟桌面工具，選擇「顯示內容」。'],
 'Manually recorded; not verified against billing.':['手动记录，未核验账单。','手動記錄，未核驗帳單。'],
 'Plan family detected from Codex desktop; dates are manually recorded.':['套餐大类来自 Codex 桌面识别；日期由你手动记录。','方案大類來自 Codex 桌面辨識；日期由你手動記錄。'],
 'Plan source unknown; not verified against billing.':['套餐来源未知，未核验账单。','方案來源未知，未核驗帳單。'],
 'Localized release notes are unavailable.':['暂无此语言的更新说明。','暫無此語言的更新說明。'],
 'Release notes':['更新说明','更新說明']
};
const t=key=>locale==='en'?key:((strings[key]||globalThis.CQS_STRINGS?.[key])?.[locale==='zh-TW'?1:0]||key);
const keys=['plan','short','week','reset','renewal','daily','average','weekly','lifetime','credits','resetCredits'];
const labels={plan:'Plan badge',renewal:'Renewal date',short:'5-hour remaining',week:'Weekly remaining',reset:'Quota reset date',resetCredits:'Reset count',credits:'Credits',daily:'Yesterday tokens',average:'Monthly daily average',weekly:'Weekly tokens',lifetime:'Lifetime tokens'};
let data=null,metadata={},offline=false,busy=false,lastRefresh=0,updateState=null;
const node=(tag,text,className)=>{const el=document.createElement(tag);if(text!==undefined)el.textContent=text;if(className)el.className=className;return el;};
const validCount=n=>Number.isSafeInteger(n)&&n>=0;
const tokens=n=>{if(!validCount(n))return null;for(const [scale,unit] of [[1e9,'B'],[1e6,'M'],[1e3,'K']])if(n>=scale)return (n/scale).toFixed(2).replace(/\.?0+$/,'')+unit;return String(n);};
const fresh=(at,age)=>typeof at==='number'&&Number.isFinite(at)&&at<=Date.now()+5000&&Date.now()-at<age;
const shown=key=>metadata.visible?.[key]!==false;
function dailyLabel(){
 const localDay=date=>[date.getFullYear(),String(date.getMonth()+1).padStart(2,'0'),String(date.getDate()).padStart(2,'0')].join('-');
 const today=new Date(),yesterday=new Date();yesterday.setDate(yesterday.getDate()-1);
 return data?.daily?.date===localDay(today)?'Today tokens':data?.daily?.date===localDay(yesterday)?'Yesterday tokens':'Daily tokens';
}
function section(title){const el=node('section');const heading=node('div',undefined,'group-title');heading.append(node('h2',t(title)));el.append(heading);$('#metrics').append(el);return el;}
function reason(quota){if(offline)return t('Local helper not connected');if(data?.code==='STALE'||data?.ok&&(!fresh(data.generatedAt,90000)||!fresh(quota?data.quotaAt:data.usageAt,quota?180000:5400000)))return t('Data expired');return t('Not returned');}
function dateTime(stamp){if(typeof stamp!=='number'||!Number.isFinite(stamp)||stamp<=0)return null;const date=new Date(stamp<1e12?stamp*1000:stamp);return Number.isFinite(date.getTime())?new Intl.DateTimeFormat(locale,{month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false}).format(date):null;}
function datum(key,value,reasonText){const el=node('div',undefined,'datum');el.dataset.metric=key;el.append(node('dt',t(labels[key])),node('dd',value??'--'));if(value===null){el.lastChild.append(node('small',' · '+reasonText));}return el;}
function render(){
 document.documentElement.lang=locale;$('#language').value=locale;
 document.querySelectorAll('[data-i18n]').forEach(el=>el.textContent=t(el.dataset.i18n));
 const connected=!offline&&data?.ok&&fresh(data.generatedAt,90000);
 $('#status').textContent=t(offline?'Local helper not connected':!connected?(data?.code==='STALE'?'Snapshot expired':'Local snapshot unavailable'):'Connected');$('#status').className=connected?'':'warn';
 const quota=connected&&fresh(data.quotaAt,180000),usage=connected&&fresh(data.usageAt,5400000);
 const windows=quota&&Array.isArray(data.windows)?data.windows:[];
 const windowFor=minutes=>{const matches=windows.filter(w=>w.minutes===minutes);return matches.length===1?matches[0]:null;};
 $('#metrics').replaceChildren();
 const selected=keys.filter(shown);$('#selection').textContent=t('Uses desktop display choices')+' · '+selected.length+' / 11';
 if(!selected.length){const el=node('div',t('No metrics selected'),'empty-selection');el.id='empty-selection';$('#metrics').append(el);}
 if(['short','week','reset','resetCredits','credits'].some(shown)){
  const group=section('Quota and resets'),pair=node('div',undefined,'quota-pair');
  for(const [key,minutes] of [['short',300],['week',10080]])if(shown(key)){
   const match=windowFor(minutes),value=match&&Number.isFinite(match.remaining)&&match.remaining>=0&&match.remaining<=100?match.remaining:null;
   const el=node('div',undefined,'quota-unit');el.dataset.metric=key;
   const track=node('div',undefined,'track');track.setAttribute('role','progressbar');track.setAttribute('aria-label',t(labels[key]));track.setAttribute('aria-valuemin','0');track.setAttribute('aria-valuemax','100');
   if(value!==null){track.setAttribute('aria-valuenow',String(value));const fill=node('i');fill.style.width=value+'%';track.append(fill);}else track.setAttribute('aria-valuetext',reason(true));
   el.append(node('div',t(labels[key]),'quota-label'),node('div',value===null?'--':value+'%','quota-value'+(value===null?' unknown':'')),track,node('div',value===null?reason(true):t('Synced'),'quota-caption'));pair.append(el);
  }
  if(pair.children.length)group.append(pair);
  const details=node('dl',undefined,'quota-details');
  const balance=quota&&typeof data.creditBalance==='string'&&/^\d+(\.\d+)?$/.test(data.creditBalance)&&Number.isSafeInteger(Math.floor(Number(data.creditBalance)))?Math.floor(Number(data.creditBalance)).toLocaleString(locale):null;
  for(const [key,value] of [['reset',dateTime(windowFor(10080)?.resetsAt)],['resetCredits',quota&&validCount(data.resetCredits)?data.resetCredits.toLocaleString(locale):null],['credits',balance]])if(shown(key))details.append(datum(key,value,reason(true)));
  if(details.children.length)group.append(details);
 }
 if(['daily','average','weekly','lifetime'].some(shown)){
  const group=section('Token usage'),table=node('table',undefined,'usage-table'),head=node('thead'),tr=node('tr'),body=node('tbody');
  for(const label of ['Metric','Usage','Status']){const th=node('th',t(label));th.scope='col';tr.append(th);}head.append(tr);table.append(head,body);
  for(const [key,n] of [['daily',data?.daily?.value],['average',data?.monthAverage],['weekly',data?.week],['lifetime',data?.lifetime]])if(shown(key)){
   const value=usage?tokens(n):null,row=node('tr');row.dataset.metric=key;row.append(node('td',t(key==='daily'?dailyLabel():labels[key])),node('td',value??'--','table-value'),node('td',value===null?reason(false):t('Synced'),value===null?'':'available'));
   if(key==='daily'&&data?.daily?.date){row.title=data.daily.date;if(dailyLabel()==='Daily tokens')row.firstChild.append(node('small',data.daily.date,'data-date'));}body.append(row);
  }group.append(table);
 }
 if(['plan','renewal'].some(shown)){
  const group=node('section'),strip=node('dl',undefined,'account-strip');
  if(shown('plan'))strip.append(datum('plan',metadata.planBadge||null,t('Not returned')));
  if(shown('renewal')){
   const date=metadata.renewalDate?new Date(metadata.renewalDate+'T00:00:00'):null;
   const el=datum('renewal',date&&Number.isFinite(date.getTime())?new Intl.DateTimeFormat(locale,{month:'2-digit',day:'2-digit'}).format(date):null,t('Not returned'));
   if(metadata.renewalDate)el.title=metadata.renewalDate;strip.append(el);
  }
  strip.title=t(metadata.planSource==='manual'?'Manually recorded; not verified against billing.':metadata.planSource==='desktop'?'Plan family detected from Codex desktop; dates are manually recorded.':'Plan source unknown; not verified against billing.');
  group.append(strip);$('#metrics').append(group);
 }
 $('#stamp').textContent=t('Quota synced')+': '+(data?.quotaAt?new Date(data.quotaAt).toLocaleString(locale):'--')+'\n'+t('Tokens synced')+': '+(data?.usageAt?new Date(data.usageAt).toLocaleString(locale):'--');
 if(!$('#settings-feedback').hidden)$('#settings-feedback').textContent=t('Cannot open desktop settings from this read-only panel. Open the desktop companion and choose Display choices.');
 renderUpdate();
}
async function read(){
 if(busy||document.hidden)return;busy=true;
 try{data=await chrome.runtime.sendNativeMessage('org.kefen.codex_quota_sidebar',{op:'read'});offline=false;for(const key of ['visible','planBadge','renewalDate','planSource'])if(Object.hasOwn(data||{},key))metadata[key]=data[key];}
 catch{data=null;offline=true;}finally{busy=false;render();}
}
async function refresh(){if(Date.now()-lastRefresh<60000){$('#help-feedback').textContent=t('Please wait for the next refresh.');return;}lastRefresh=Date.now();$('#refresh').disabled=true;await read();setTimeout(()=>$('#refresh').disabled=false,60000);}
function releaseNotes(body){
 const headings={en:/^(English|en(?:-US)?)$/i,'zh-CN':/^(简体中文|簡體中文|zh-CN)$/i,'zh-TW':/^(繁體中文|繁体中文|zh-TW)$/i};
 let active=false,found=false,lines=[];
 for(const line of String(body||'').split(/\r?\n/)){
  const heading=line.match(/^#{1,6}\s+(.+?)\s*$/);
  if(heading){active=headings[locale].test(heading[1]);if(active)found=true;continue;}
  if(active){const item=line.match(/^\s*(?:\d+[.)]|[-*])\s+(.+)/);if(item)lines.push(item[1]);}
 }
 return found&&lines.length?lines.map((line,i)=>(i+1)+'. '+line).join('\n'):t('Localized release notes are unavailable.');
}
function renderUpdate(){
 const message=$('#update-status');message.replaceChildren();message.hidden=!updateState;
 if(!updateState)return;
 if(updateState.key){message.textContent=t(updateState.key);return;}
 const link=node('a',t('Update available')+' '+updateState.version);link.href='https://github.com/kefen/codex-quota-sidebar/releases/tag/'+encodeURIComponent(updateState.tag);link.target='_blank';link.rel='noopener noreferrer';
 message.append(link,node('p',t('Download, unpack and reload the extension in chrome://extensions.')),node('p',t('Release notes')+'\n'+releaseNotes(updateState.body)));
}
async function checkUpdates(manual=false){
 const control=$('#check-updates');if(control.disabled)return;
 let last=0;try{last=Number(localStorage.getItem('cqs-update-check')||0);}catch{}
 if(!manual&&Date.now()-last<86400000)return;
 control.disabled=true;updateState={key:'Checking for updates...'};renderUpdate();
 try{
  const response=await fetch('https://api.github.com/repos/kefen/codex-quota-sidebar/releases?per_page=30',{credentials:'omit',signal:AbortSignal.timeout(15000)});if(!response.ok)throw Error('Network error');
  const releases=await response.json(),current=chrome.runtime.getManifest().version.split('.').map(Number);
  const compare=(a,b)=>{for(let i=0;i<3;i++)if(a[i]!==b[i])return a[i]-b[i];return 0;};
  const candidates=releases.filter(r=>!r.draft&&!r.prerelease&&/^chrome\/v\d+\.\d+\.\d+$/.test(r.tag_name)).map(r=>({...r,parts:r.tag_name.slice(8).split('.').map(Number)})).sort((a,b)=>compare(b.parts,a.parts));
  const latest=candidates[0];updateState=latest&&compare(latest.parts,current)>0?{tag:latest.tag_name,version:latest.tag_name.slice(8),body:latest.body}:manual?{key:'You are up to date.'}:null;
  try{localStorage.setItem('cqs-update-check',String(Date.now()));}catch{}
 }catch{updateState=manual?{key:'Update check failed. Please try again later.'}:null;}finally{control.disabled=false;renderUpdate();}
}
$('#extension-id').textContent=chrome.runtime.id;$('#version').textContent='Chrome '+chrome.runtime.getManifest().version;
$('#language').addEventListener('change',()=>{locale=$('#language').value;try{localStorage.setItem('cqs-language',locale);}catch{}render();});
$('#display-settings').addEventListener('click',()=>{$('#settings-feedback').hidden=false;render();$('#settings-feedback').scrollIntoView({block:'nearest'});});
$('#check-updates').addEventListener('click',()=>checkUpdates(true));
$('#refresh').addEventListener('click',refresh);
$('#export').addEventListener('click',()=>{
 const report={tool:'Codex Quota Sidebar by KEFEN',version:chrome.runtime.getManifest().version,connection:offline?'helper-unavailable':data?.ok?'snapshot-read':'snapshot-unavailable',exportedAt:new Date().toISOString()};
 const url=URL.createObjectURL(new Blob([JSON.stringify(report,null,2)],{type:'application/json'})),link=node('a');link.href=url;link.download='Codex-Quota-Sidebar-browser-diagnostics.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);$('#help-feedback').textContent=t('Review diagnostics before attaching them to a GitHub issue. No files are uploaded automatically.');
});
document.addEventListener('visibilitychange',()=>{if(!document.hidden)read();});
setInterval(read,5000);setTimeout(()=>checkUpdates(),5000);render();read();
