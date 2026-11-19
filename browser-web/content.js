(() => {
  'use strict';
  if(location.origin!=='https://chatgpt.com'||window!==window.top||!globalThis.CQSWebSource)return;
  const M=globalThis.CQSWebSource,id='cqs-web-usage-preview',keys=['week','plan','credits','resets','reset','monthly'];
  const text={
    title:['Codex Quota by KEFEN','Codex Quota by KEFEN','Codex Quota by KEFEN'],shared:['Codex / Work shared allowance','Codex / Work 共享额度','Codex / Work 共用額度'],
    week:['Weekly remaining','本周剩余','本週剩餘'],credits:['Credits','额度','額度'],resets:['Available resets','可用重置次数','可用重設次數'],reset:['Reset time','重置时间','重設時間'],plan:['Plan','套餐','方案'],
    refresh:['Read again','重新读取','重新讀取'],reading:['Reading…','正在读取…','正在讀取…'],settings:['Display choices','展示内容','顯示內容'],back:['Back','返回','返回'],
    source:['Read full usage','读取完整用量','讀取完整用量'],missing:['See full usage','见完整用量','見完整用量'],unsupported:['Not provided by this page','此网页未提供','此網頁未提供'],
    expired:['Readout expired','读数已过期','讀數已過期'],notReturned:['Not shown','未显示','未顯示'],history:['Token history','历史 Token','歷史 Token'],
    details:['Source: current web account','来源：当前网页账户','來源：目前網頁帳戶'],
    token:['Daily / average / weekly / lifetime Tokens','昨日 / 日均 / 本周 / 累计 Token','昨日 / 日均 / 本週 / 累計 Token'],short:['5-hour remaining','5 小时剩余','5 小時剩餘'],renewal:['Purchase / renewal dates','购买 / 续费日期','購買 / 續費日期'],
    saved:['Saved','已保存','已儲存'],saveFailed:['Could not save. Try again.','保存失败，请重试。','儲存失敗，請重試。'],
    empty:['No metrics selected','尚未选择展示项','尚未選取顯示項目'],blocked:['Account context changed. Read again.','账户上下文已变化，请重新读取。','帳戶情境已變更，請重新讀取。'],
    waiting:['Close other menus, then retry.','请关闭其他菜单后重试。','請關閉其他選單後重試。'],read:['Page readout','页面读数','頁面讀數'],
    stamp:['Read at','读取于','讀取於'],choose:['Language','语言','語言'],unavailable:['Usage menu unavailable','暂未找到官方用量菜单','暫未找到官方用量選單']
  };
  let language=navigator.language.startsWith('zh')?(navigator.language.includes('TW')||navigator.language.includes('Hant')?'zh-TW':'zh-CN'):'en';
  let choices=Object.fromEntries(keys.map(k=>[k,true])),host,shadow,body,form,status,refreshButton,settingsButton,details,observer,shell;
  let cells={},blocked=false,busy=false,editing=false,attempted=false,lastPath=location.href,timer,rendered='',stopped=false;
  let pending=null,returnRoute=false,updateVersion='',expiry;
  text.update=['Update available','发现新版','發現新版'];
  text.monthly=['Monthly tokens','本月 Token','本月 Token'];
  const overviewURL='https://chatgpt.com/settings/usage?tab=overview';
  text.bring=['Same account: bring readings back','确认同账号，带回读数','確認同帳號，帶回讀數'];
  text.retryFull=['Return to the chat and open full usage again.','请回到原聊天页，再点「读取完整用量」。','請回到原聊天頁，再點「讀取完整用量」。'];
  const t=k=>text[k]?.[language==='en'?0:language==='zh-CN'?1:2]||k;
  const E=(tag,value,cls)=>{const el=document.createElement(tag);if(value!==undefined)el.textContent=value;if(cls)el.className=cls;return el;};
  const nowValues=()=>Object.fromEntries(keys.map(k=>[k,!blocked&&cells[k]&&Date.now()-cells[k].at<(cells[k].confirmed?300000:60000)?cells[k].value:null]));
  const visible=el=>el&&el.getClientRects().length&&!el.closest('[hidden],[aria-hidden="true"]');
  function invalidate(){pending=null;cells={};blocked=true;rendered='';render();}
  function read(){
    if(stopped||!host?.isConnected)return;
    if(lastPath!==location.href){lastPath=location.href;pending=null;cells={};}
    if(blocked){render();return;}
    const input=M.collect(document,location.pathname,location.search),x=M.parse(input);
    for(const key of keys){
      if(x[key]!==null)cells[key]={value:x[key],at:x.at};
      else if(key==='week'&&input.description||key==='monthly'&&(input.overview||input.menu.length)&&!cells[key]?.confirmed)delete cells[key];
    }
    armExpiry();
    render();
  }
  function armExpiry(){
    clearTimeout(expiry);
    const now=Date.now(),next=Math.min(...Object.values(cells).map(c=>c.at+(c.confirmed?300000:60000)).filter(n=>n>now));
    if(Number.isFinite(next)&&!document.hidden)expiry=setTimeout(()=>{if(!document.hidden){render();armExpiry();}},next-now+1);
  }
  async function probe(){
    if(busy||document.hidden)return;
    const button=M.trigger(document);
    if(!button){status.textContent=t('unavailable');return;}
    const open=[...document.querySelectorAll('[role="menu"],[role="dialog"]')].filter(visible);
    if(button.getAttribute('aria-expanded')!=='true'&&open.length){status.textContent=t('waiting');return;}
    blocked=false;busy=true;rendered='';render();
    const owned=button.getAttribute('aria-expanded')!=='true',focused=document.activeElement;
    let interrupted=false;const userInteracted=()=>{interrupted=true;};
    if(owned){
      button.click();
      if(button.getAttribute('aria-expanded')!=='true')button.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowDown',bubbles:true,cancelable:true}));
      document.addEventListener('pointerdown',userInteracted,true);document.addEventListener('keydown',userInteracted,true);
    }
    try{
      for(let i=0;i<40;i++){
        if(blocked||stopped||interrupted||!button.isConnected)break;
        const input=M.collect(document,location.pathname,location.search);
        if(input.menu.length){
          read();const partial=M.parse({menu:input.menu});
          if(!owned||(partial.credits!==null&&partial.plan!==null))break;
        }
        await new Promise(resolve=>setTimeout(resolve,75));
      }
    }finally{
      document.removeEventListener('pointerdown',userInteracted,true);document.removeEventListener('keydown',userInteracted,true);
      if(owned&&!interrupted&&!blocked&&button.isConnected&&button.getAttribute('aria-expanded')==='true'&&M.collect(document,location.pathname,location.search).menu.length){
        button.click();
        if(button.getAttribute('aria-expanded')==='true'&&document.activeElement?.closest('[role="menu"]'))document.activeElement.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true}));
        if(focused?.isConnected&&focused!==document.body)focused.focus({preventScroll:true});
      }
      busy=false;rendered='';read();
    }
  }
  function command(label,action){const b=E('button',label);b.type='button';b.addEventListener('click',action);return b;}
  async function save(){
    try{await chrome.storage.local.set({cqsWebPreferences:{language,choices}});status.textContent=t('saved');}
    catch{status.textContent=t('saveFailed');}
  }
  function renderSettings(){
    form.replaceChildren();const row=E('div',undefined,'tools'),heading=E('h2',t('settings'));
    row.append(heading,command(t('back'),()=>{editing=false;rendered='';render();settingsButton.focus();}));form.append(row);
    for(const key of keys){const label=E('label',undefined,'check'),input=E('input');input.type='checkbox';input.checked=choices[key];input.dataset.field=key;input.addEventListener('change',()=>{choices[key]=input.checked;save();rendered='';render();});label.append(input,E('span',t(key)));form.append(label);}
    const unsupported=E('fieldset');unsupported.disabled=true;unsupported.append(E('legend',t('unsupported')));
    for(const key of ['short','token','renewal']){const label=E('label',undefined,'check'),input=E('input');input.type='checkbox';label.append(input,E('span',t(key)));unsupported.append(label);}form.append(unsupported);
    const label=E('label',undefined,'language');label.append(E('span',t('choose')));const select=E('select');select.setAttribute('aria-label',t('choose'));
    for(const [value,title] of [['en','English'],['zh-CN','简体中文'],['zh-TW','繁體中文']]){const o=E('option',title);o.value=value;select.append(o);}select.value=language;
    select.addEventListener('change',()=>{language=select.value;rendered='';render();save();renderSettings();});label.append(select);form.append(label);
  }
  function render(){
    if(!shadow)return;const values=nowValues(),signature=JSON.stringify({values,language,choices,editing,busy,blocked});
    if(signature===rendered)return;rendered=signature;
    shadow.querySelector('.title').textContent=t('title');shadow.querySelector('.shared').textContent=t('shared');
    settingsButton.textContent=t('settings');refreshButton.textContent=t(busy?'reading':'refresh');refreshButton.disabled=busy;
    body.hidden=editing;form.hidden=!editing;settingsButton.hidden=editing;
    status.textContent=blocked||busy?t(blocked?'blocked':'reading'):'';
    if(editing){if(!form.children.length)renderSettings();return;}
    form.replaceChildren();body.replaceChildren();
    if(!keys.some(k=>choices[k]))body.append(E('p',t('empty'),'hint'));
    const grid=E('dl',undefined,'metrics');
    for(const key of keys.filter(k=>choices[k])){
      const row=E('div',undefined,'metric '+key);row.dataset.metric=key;
      const missing= cells[key] ? t('expired') : key==='monthly'?t('unsupported'):['credits','reset','resets'].includes(key)?t('missing'):t('notReturned');
      row.append(E('dt',t(key)),E('dd',values[key]===null?(key==='week'?'--':missing):key==='week'?values[key]+'%':key==='monthly'?values[key].toLocaleString(language):String(values[key])));
      if(key==='week'){
        const progress=E('div',undefined,'track');progress.setAttribute('role','progressbar');progress.setAttribute('aria-label',t('week'));progress.setAttribute('aria-valuemin','0');progress.setAttribute('aria-valuemax','100');
        if(values[key]!==null){progress.setAttribute('aria-valuenow',String(values[key]));const fill=E('i');fill.style.width=values[key]+'%';progress.append(fill);}else progress.setAttribute('aria-valuetext',t('missing'));row.append(progress);
      }
      if(values[key]===null)row.classList.add('unknown');grid.append(row);
    }
    body.append(grid);
    const history=E('div',undefined,'history');history.append(E('span',t('history')),E('span',t('unsupported'),'hint'));body.append(history);
    const footer=E('div',undefined,'foot'),link=E('a',t('source'));link.href=overviewURL;
    if(location.href!==overviewURL)link.addEventListener('click',async event=>{
      if(event.ctrlKey||event.metaKey||event.shiftKey||event.altKey)return;
      event.preventDefault();const request=crypto.randomUUID();pending=request;blocked=false;
      try{if((await chrome.runtime.sendMessage({type:'CQS_FULL_OPEN',request}))?.ok)return;}catch{}
      pending=null;location.assign(overviewURL);
    });
    if(returnRoute&&location.href===overviewURL){
      const bring=command(t('bring'),async()=>{
        const input=M.collect(document,location.pathname,location.search);
        if(!input.overview||blocked)return;
        const x=M.parse({overview:input.overview});
        const values=Object.fromEntries(keys.filter(k=>x[k]!==null).map(k=>[k,x[k]]));
        try{if((await chrome.runtime.sendMessage({type:'CQS_FULL_RETURN',values}))?.ok){returnRoute=false;rendered='';render();return;}}catch{}
        status.textContent=t('retryFull');
      });
      bring.disabled=blocked||!Object.values(values).some(v=>v!==null)||!M.collect(document,location.pathname,location.search).overview;
      body.append(bring);
    }
    const note=E('span',t('details'),'hint');footer.append(link,note);body.append(footer);
    const times=Object.entries(cells).filter(([key])=>choices[key]&&values[key]!==null).map(([,x])=>x.at);
    if(times.length&&!blocked){const stamp=E('div',t('stamp')+' '+new Date(Math.min(...times)).toLocaleTimeString(language,{hour:'2-digit',minute:'2-digit'}),'hint');body.append(stamp);}
    shadow.querySelector('.version').textContent='Web '+chrome.runtime.getManifest().version;
    const update=shadow.querySelector('.update');update.hidden=!updateVersion;
    if(updateVersion){update.textContent=t('update')+' '+updateVersion;update.href='https://github.com/kefen/codex-quota-sidebar/releases/tag/chrome/v'+updateVersion;}
  }
  function mount(){
    const currentShell=document.getElementById('app-shell-sidebar');
    if(shell&&shell!==currentShell){pending=null;cells={};attempted=false;rendered='';}
    const nav=document.querySelector('#app-shell-sidebar nav[data-app-navigation-rail="true"]'),parent=nav?.nextElementSibling;
    if(!nav||!parent||!M.trigger(document)){
      if(host?.isConnected){host.remove();cells={};}return;
    }
    if(host?.isConnected&&host.parentElement===parent){startProbe();return;}
    host?.remove();host=E('aside');host.id=id;host.style.cssText='display:block;flex:0 0 auto;min-width:0;width:100%;position:relative;order:999;margin-top:auto;';
    shadow=host.attachShadow({mode:'open'});const style=E('style');style.textContent=STYLE;shadow.append(style);
    details=E('details');details.open=true;const summary=E('summary'),image=E('img');image.src=chrome.runtime.getURL('icon-32.png');image.alt='';image.width=image.height=16;
    summary.append(image,E('span',t('title'),'title'));details.append(summary,E('p',t('shared'),'shared'));
    body=E('section');body.setAttribute('aria-label',t('title'));form=E('section');form.hidden=true;details.append(body,form);
    const tools=E('div',undefined,'tools');refreshButton=command(t('refresh'),probe);settingsButton=command(t('settings'),()=>{editing=true;rendered='';render();renderSettings();form.querySelector('input')?.focus();});tools.append(refreshButton,settingsButton);
    status=E('div',undefined,'status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
    const meta=E('div',undefined,'meta'),update=E('a','','update');update.hidden=true;update.target='_blank';update.rel='noopener noreferrer';
    meta.append(E('span','Web '+chrome.runtime.getManifest().version,'version'),update);
    details.append(tools,status,meta);shadow.append(details);parent.append(host);rendered='';read();
    startProbe();
  }
  function startProbe(){if(location.pathname!=='/settings/usage'&&!attempted&&!blocked&&!document.hidden&&!busy&&details?.open){attempted=true;setTimeout(probe,250);}}
  const STYLE=`
    :host{color-scheme:light dark;--ink:#252b35;--muted:#566274;--line:#dce1e8;--surface:#fff;--blue:#255adc;--green:#187e68;font:12px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif;color:var(--ink)}
    *{box-sizing:border-box;letter-spacing:0}details{background:var(--surface);padding:10px 12px;border-bottom:1px solid var(--line);max-height:min(48dvh,440px);overflow:auto;scrollbar-width:thin}
    summary{display:flex;align-items:center;gap:7px;cursor:pointer;font-size:13px;font-weight:600;min-height:28px;list-style:none}summary::after{content:'▾';margin-left:auto}details:not([open]) summary::after{content:'▸'}summary::-webkit-details-marker{display:none}img{flex:0 0 16px}.shared{color:var(--muted);font-size:11px;margin:3px 0 10px}
    .metrics{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px 14px;margin:0 0 10px}.metric{min-width:0}.week{grid-column:1/-1}dt{color:var(--muted);font-size:11px}dd{margin:1px 0 0;font-size:14px;font-weight:500;overflow-wrap:anywhere;font-variant-numeric:tabular-nums}.week dd{font-size:24px;line-height:30px}.plan dd,.reset dd{font-size:12px;font-weight:400}.unknown dd{font-size:11px;color:var(--muted);font-weight:400}.week.unknown dd{font-size:24px}
    .track{height:5px;background:var(--line);border-radius:2px;overflow:hidden;margin-top:5px}.track i{display:block;height:100%;background:var(--green)}.foot{border-top:1px solid var(--line);padding-top:7px;display:flex;align-items:flex-start;gap:8px;flex-wrap:wrap}.hint{color:var(--muted);font-size:11px}.foot .hint{flex:1 1 130px}a{color:var(--blue);text-decoration:none}a:hover{text-decoration:underline}
    .tools{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-top:8px}button,select{font:inherit;color:var(--ink);background:var(--surface);border:1px solid var(--line);border-radius:4px;min-height:28px;padding:3px 8px;cursor:pointer;max-width:100%}button:hover{background:color-mix(in srgb,var(--blue) 7%,var(--surface))}button:disabled{opacity:.65;cursor:wait}button:focus-visible,a:focus-visible,summary:focus-visible,input:focus-visible,select:focus-visible{outline:2px solid var(--blue);outline-offset:2px}.status,.version{font-size:10px;color:var(--muted);display:block;overflow-wrap:anywhere}.status{margin-top:6px;min-height:15px}.version{margin-top:3px}
    h2{font-size:13px;font-weight:600;margin:0;flex:1}.check{display:flex;gap:7px;align-items:center;min-height:28px;cursor:pointer}.check input{accent-color:var(--blue);flex:0 0 14px;width:14px;height:14px;margin:0}fieldset{border:0;border-top:1px solid var(--line);padding:8px 0 0;margin:9px 0;color:var(--muted);min-width:0}fieldset .check{cursor:default}legend{font-size:11px;padding:0 5px 0 0}.language{display:flex;align-items:center;justify-content:space-between;gap:8px}.language select{max-width:110px}[hidden]{display:none!important}
    @media(prefers-color-scheme:dark){:host{--ink:#e5e9f0;--muted:#aeb8c8;--line:#3b4350;--surface:#20242b;--blue:#91b5ff;--green:#50b89b}}
    details{padding:6px 12px}.shared{margin:0 0 5px}.metrics{gap:5px 12px;margin:0 0 6px}.week{display:grid;grid-template-columns:1fr auto;align-items:center;gap:2px 8px}.week dd{font-size:20px;line-height:24px}.week .track{grid-column:1/-1;margin-top:0}.history{display:flex;justify-content:space-between;gap:6px;padding:4px 0}.foot{padding-top:4px}.tools{margin-top:5px}.status:empty{display:none}
    details{border:1px solid var(--line);border-radius:8px;margin:4px 6px 6px;padding:8px 10px;max-height:min(52dvh,440px)}
    summary{font:600 14px/1.4 -apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif;min-height:28px}
    .shared{margin:2px 0 7px}.metrics{padding:7px 9px;background:color-mix(in srgb,var(--muted) 6%,var(--surface));border-radius:5px;gap:6px 12px}
    .week{padding-bottom:5px}.track{position:relative;height:7px}.track:after{content:'';position:absolute;inset:0;background:repeating-linear-gradient(90deg,transparent 0,transparent calc(10% - 2px),var(--surface) calc(10% - 2px),var(--surface) 10%)}
    dd{font-variant-numeric:tabular-nums}.history,.foot,.meta{align-items:baseline}.foot{margin-top:3px}.tools button{border-radius:5px;min-height:30px}.meta{display:flex;justify-content:space-between;gap:6px;font-size:11px}.version{font-size:11px}.update{font-weight:600}
  `;
  function tick(){if(stopped||document.hidden)return;mount();if(host?.isConnected)read();const nextShell=document.getElementById('app-shell-sidebar');if(nextShell!==shell){observer?.disconnect();shell=nextShell;if(shell){observer=new MutationObserver(records=>{if(records.every(r=>r.target===host||host?.contains(r.target)))return;schedule();});observer.observe(shell,{childList:true,subtree:true,characterData:true,attributes:true,attributeFilter:['aria-description','aria-expanded','value','aria-valuenow','hidden']});}}}
  document.addEventListener('click',event=>{
    if(event.composedPath().includes(host))return;
    const button=event.target.closest?.('button');
    if(button&&['Open profile menu','打开个人资料菜单','開啟個人資料選單'].includes(button.getAttribute('aria-label')))invalidate();
  },true);
  document.addEventListener('visibilitychange',()=>{if(!document.hidden)tick();});
  document.addEventListener('keydown',event=>{if(event.key==='Escape'&&editing){editing=false;rendered='';render();settingsButton?.focus();}});
  window.addEventListener('popstate',tick);
  window.navigation?.addEventListener('currententrychange',schedule);
  chrome.runtime.onMessage.addListener((message,sender,reply)=>{
    if(sender.id!==chrome.runtime.id)return;
    if(message?.type==='CQS_FULL_RESULT'){
      if(!pending||pending!==message.request||blocked||stopped||lastPath!==location.href||!host?.isConnected||shell!==document.getElementById('app-shell-sidebar')){reply({ok:false});return;}
      pending=null;const at=Date.now();for(const k of keys){
        if(Object.hasOwn(message.values,k))cells[k]={value:message.values[k],at,confirmed:true};
        else if(cells[k]?.confirmed)delete cells[k];
      }
      armExpiry();rendered='';render();reply({ok:true});return;
    }
    if(message?.type!=='CQS_WEB_TOGGLE')return;tick();if(details){details.open=!details.open;reply({mounted:true});}else reply({mounted:false});
  });
  if(location.href===overviewURL)chrome.runtime.sendMessage({type:'CQS_FULL_ROUTE'}).then(r=>{returnRoute=!!r?.ok;rendered='';render();}).catch(()=>{});
  chrome.storage.local.get('cqsWebPreferences').then(result=>{
    const prefs=result.cqsWebPreferences;if(['en','zh-CN','zh-TW'].includes(prefs?.language))language=prefs.language;
    for(const key of keys)if(typeof prefs?.choices?.[key]==='boolean')choices[key]=prefs.choices[key];tick();
  }).catch(tick);
  const structural=new MutationObserver(records=>{
    if(document.hidden||stopped)return;
    if(shell?.isConnected&&!records.some(r=>r.target.parentElement?.closest('[role=menu]')||r.target.closest?.('[role=menu]')||location.pathname==='/settings/usage'||
      (!host?.isConnected&&shell.contains(r.target))))return;
    schedule();
  });
  function schedule(){if(stopped||document.hidden||timer)return;timer=setTimeout(()=>{timer=null;if(!document.hidden)tick();},120);}
  structural.observe(document.documentElement,{childList:true,subtree:true});
  function newVersion(v){updateVersion=typeof v==='string'&&/^\d+\.\d+\.\d+$/.test(v)?v:'';rendered='';render();}
  chrome.storage.local.get('cqsNewVersion').then(r=>newVersion(r.cqsNewVersion)).catch(()=>{});
  chrome.storage.onChanged?.addListener((c,area)=>{if(area==='local'&&c.cqsNewVersion)newVersion(c.cqsNewVersion.newValue);});
  window.addEventListener('pagehide',()=>{stopped=true;observer?.disconnect();structural.disconnect();clearTimeout(expiry);clearTimeout(timer);timer=null;cells={};});
  window.addEventListener('pageshow',event=>{if(event.persisted){stopped=false;blocked=true;shell=null;cells={};structural.observe(document.documentElement,{childList:true,subtree:true});tick();}});
})();
