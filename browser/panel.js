const status=document.querySelector('#status'),list=document.querySelector('#metrics'),button=document.querySelector('#refresh'),stamp=document.querySelector('#stamp');
document.querySelector('#extension-id').textContent=chrome.runtime.id;
let busy=false,last=0;
function row(label,value){const dt=document.createElement('dt'),dd=document.createElement('dd');dt.textContent=label;dd.textContent=value;list.append(dt,dd);}
const count=n=>Number.isSafeInteger(n)&&n>=0?n.toLocaleString():'--';
async function refresh(){
  if(busy||document.hidden||Date.now()-last<60000)return;busy=true;last=Date.now();button.disabled=true;
  try{
    const data=await chrome.runtime.sendNativeMessage('org.chung.codex_quota_sidebar',{op:'read'});list.replaceChildren();
    if(!data.ok){status.textContent=data.code==='STALE'?'数据已过期':'本地数据不可用';stamp.textContent='请检查桌面监控是否运行，以及辅助程序是否已注册。';return;}
    status.textContent='已读取本机快照';
    for(const w of data.windows||[])row(w.minutes===300?'5 小时剩余':w.minutes===10080?'本周剩余':w.minutes+' 分钟窗口',w.remaining+'%');
    if(!data.windows?.length)row('额度','暂不可用');
    if(data.daily)row(data.daily.date+' Token',count(data.daily.value));
    row('本周 Token',count(data.week));row('累计 Token',count(data.lifetime));
    stamp.textContent='额度同步：'+(data.quotaAt?new Date(data.quotaAt).toLocaleString():'--')+'；Token 同步：'+(data.usageAt?new Date(data.usageAt).toLocaleString():'--');
  }catch{list.replaceChildren();status.textContent='尚未连接本地辅助程序';stamp.textContent='需要按扩展 ID 注册本机连接；此扩展不会读取网页 Cookie。';}
  finally{busy=false;setTimeout(()=>button.disabled=false,Math.max(0,60000-(Date.now()-last)));}
}
button.addEventListener('click',refresh);document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh();});setInterval(refresh,60000);refresh();
