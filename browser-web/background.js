chrome.action.onClicked.addListener(async tab=>{
  if(!tab.id)return;
  try{const reply=await chrome.tabs.sendMessage(tab.id,{type:'CQS_WEB_TOGGLE'});if(!reply?.mounted)await chrome.tabs.create({url:chrome.runtime.getURL('guide.html')});}
  catch{await chrome.tabs.create({url:chrome.runtime.getURL('guide.html')});}
});
chrome.runtime.onInstalled.addListener(event=>{if(event.reason==='install')chrome.tabs.create({url:chrome.runtime.getURL('guide.html')});});

const day=86400000,alarm='cqs-web-release',feed='https://raw.githubusercontent.com/kefen/AI-Quota-Board/main/browser-web/updates.json';
function newer(a,b){
  if(typeof a!=='string'||!/^\d{1,5}\.\d{1,5}\.\d{1,5}$/.test(a))return false;
  const current=b.split('.').map(Number),d=a.split('.').map((n,i)=>Number(n)-current[i]);
  return (d.find(n=>n!==0)||0)>0;
}
let checking;
async function checkVersion(){
  if(checking)return checking;
  checking=(async()=>{
    const {cqsCheckedAt=0}=await chrome.storage.local.get('cqsCheckedAt');
    if(Date.now()-cqsCheckedAt<day)return;
    await chrome.storage.local.set({cqsCheckedAt:Date.now()});
    const response=await fetch(feed,{credentials:'omit',referrerPolicy:'no-referrer',redirect:'error',signal:AbortSignal.timeout(8000)});
    if(!response.ok)return;
    const value=await response.json();
    if(value.product!=='codex-quota-web')return;
    const version=newer(value.version,chrome.runtime.getManifest().version)?value.version:'';
    await chrome.storage.local.set({cqsNewVersion:version});
    await chrome.action.setBadgeText({text:version?'↑':''});
  })().catch(()=>{}).finally(()=>{checking=null;});
  return checking;
}
async function startChecks(){if(!await chrome.alarms.get(alarm))await chrome.alarms.create(alarm,{periodInMinutes:1440});await checkVersion();}
chrome.runtime.onStartup.addListener(startChecks);
chrome.runtime.onInstalled.addListener(startChecks);
chrome.alarms.onAlarm.addListener(a=>{if(a.name===alarm)checkVersion();});

const overview='https://chatgpt.com/settings/usage?tab=overview';
const routeKey=id=>'usageRoute:'+id;
chrome.tabs.onRemoved.addListener(id=>chrome.storage.session.remove(routeKey(id)));
chrome.runtime.onMessage.addListener((msg,sender,reply)=>{
  if(sender.id!==chrome.runtime.id||sender.frameId!==0||!sender.tab?.id||!sender.documentId||!sender.url?.startsWith('https://chatgpt.com/'))return;
  if(!['CQS_FULL_OPEN','CQS_FULL_ROUTE','CQS_FULL_RETURN'].includes(msg?.type))return;
  (async()=>{
    if(msg.type==='CQS_FULL_OPEN'){
      // Register routing before loading the official page. Never persist usage or chat URLs.
      const tab=await chrome.tabs.create({url:'about:blank',openerTabId:sender.tab.id});
      await chrome.storage.session.set({[routeKey(tab.id)]:{tab:sender.tab.id,doc:sender.documentId,request:msg.request,until:Date.now()+300000}});
      await chrome.tabs.update(tab.id,{url:overview});return {ok:true};
    }
    if(sender.url!==overview)return {ok:false};
    const key=routeKey(sender.tab.id),route=(await chrome.storage.session.get(key))[key];
    if(!route||route.until<Date.now()){await chrome.storage.session.remove(key);return {ok:false};}
    if(msg.type==='CQS_FULL_ROUTE')return {ok:true};
    const accepted=await chrome.tabs.sendMessage(route.tab,{type:'CQS_FULL_RESULT',request:route.request,values:msg.values},{documentId:route.doc});
    if(!accepted?.ok)return {ok:false};
    await chrome.storage.session.remove(key);await chrome.tabs.update(route.tab,{active:true});
    return {ok:true};
  })().then(reply,()=>reply({ok:false}));return true;
});
