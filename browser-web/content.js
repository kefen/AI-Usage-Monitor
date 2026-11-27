(() => {
  'use strict';
  if(location.origin!=='https://chatgpt.com'||window!==window.top||!globalThis.CQSWebSource)return;
  const M=globalThis.CQSWebSource,id='cqs-web-usage-preview',keys=['week','plan','credits','resets','reset','monthly'];
  const text={
    title:['AI Usage Monitor','AI Usage Monitor','AI Usage Monitor'],shared:['Codex / Work shared allowance','Codex / Work 共享额度','Codex / Work 共用額度'],
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
  const systemLanguage=()=>/^zh/i.test(navigator.language)?(/Hant|TW|HK|MO/i.test(navigator.language)?'zh-TW':'zh-CN'):'en';
  let languageMode='system',language=systemLanguage(),appearance='system';
  Object.assign(text,{system:['Follow system','跟随系统','跟隨系統'],appearance:['Appearance','外观','外觀'],light:['Light','浅色','淺色'],dark:['Dark','深色','深色'],all:['Select all','全选','全選'],none:['Select none','全不选','全不選']});
  let choices=Object.fromEntries(keys.map(k=>[k,true])),host,shadow,body,form,status,refreshButton,settingsButton,details,observer,shell;
  let cells={},blocked=false,busy=false,editing=false,attempted=false,lastPath=location.href,timer,rendered='',stopped=false;
  let pending=null,returnRoute=false,updateVersion='',expiry,collapsed=false;
  text.glance=['Week','周余','週餘'];text.previous=['Last read','上次读数','上次讀數'];
  text.refresh=['Refresh usage','刷新读数','重新整理讀數'];
  text.update=['Update available','发现新版','發現新版'];
  text.monthly=['Monthly tokens','本月 Token','本月 Token'];
  const overviewURL='https://chatgpt.com/settings/usage?tab=overview';
  text.bring=['Same account: bring readings back','确认同账号，带回读数','確認同帳號，帶回讀數'];
  text.retryFull=['Return to the chat and open full usage again.','请回到原聊天页，再点「读取完整用量」。','請回到原聊天頁，再點「讀取完整用量」。'];
  const t=k=>text[k]?.[language==='en'?0:language==='zh-CN'?1:2]||k;
  const E=(tag,value,cls)=>{const el=document.createElement(tag);if(value!==undefined)el.textContent=value;if(cls)el.className=cls;return el;};
  const visible=el=>el&&el.getClientRects().length&&!el.closest('[hidden],[aria-hidden="true"]');
  function invalidate(){pending=null;cells={};blocked=true;rendered='';render();}
  function read(){
    if(stopped||!host?.isConnected)return;
    if(lastPath!==location.href){lastPath=location.href;pending=null;cells={};}
    if(blocked){render();return;}
    const input=M.collect(document,location.pathname,location.search),x=M.parse(input);
    for(const key of keys){
      if(x[key]!==null)cells[key]={value:x[key],at:x.at};
      else if(x.conflicts.includes(key))delete cells[key];
      else if(cells[key])cells[key].cached=true;
    }
    armExpiry();
    render();
  }
  function armExpiry(){
    clearTimeout(expiry);
    const now=Date.now(),next=Math.min(...Object.values(cells).map(c=>c.at+M.lifetime(c)).filter(n=>n>now));
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
    let interrupted=false;const userInteracted=event=>{
      if(!event.composedPath().includes(host))interrupted=true;
    };
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
      if(owned&&!interrupted&&!blocked&&button.isConnected&&button.getAttribute('aria-expanded')==='true'){
        button.click();
        if(button.getAttribute('aria-expanded')==='true'&&document.activeElement?.closest('[role="menu"]'))document.activeElement.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true}));
        if(focused?.isConnected&&focused!==document.body&&document.activeElement!==host)focused.focus({preventScroll:true});
      }
      busy=false;rendered='';read();
    }
  }
  function command(label,action){const b=E('button',label);b.type='button';b.addEventListener('click',action);return b;}
  async function save(announce=true){
    try{await chrome.storage.local.set({cqsWebPreferences:{language:languageMode,choices,appearance,collapsed}});if(announce)status.textContent=t('saved');}
    catch{status.textContent=t('saveFailed');}
  }
  function renderSettings(){
    form.replaceChildren();const row=E('div',undefined,'tools'),heading=E('h2',t('settings'));
    row.append(heading,command(t('back'),()=>{editing=false;rendered='';render();settingsButton.focus();}));form.append(row);
    for(const key of keys){const label=E('label',undefined,'check'),input=E('input');input.type='checkbox';input.checked=choices[key];input.dataset.field=key;input.addEventListener('change',()=>{choices[key]=input.checked;bulk.textContent=t(keys.every(k=>choices[k])?'none':'all');save();rendered='';render();});label.append(input,E('span',t(key)));form.append(label);}
    const bulk=command(t(keys.every(k=>choices[k])?'none':'all'),()=>{
      const on=!keys.every(k=>choices[k]);for(const k of keys){choices[k]=on;form.querySelector('[data-field="'+k+'"]').checked=on;}
      bulk.textContent=t(on?'none':'all');save();
    });bulk.className='soft';form.append(bulk);
    const unsupported=E('fieldset');unsupported.disabled=true;unsupported.append(E('legend',t('unsupported')));
    for(const key of ['short','token','renewal']){const label=E('label',undefined,'check'),input=E('input');input.type='checkbox';label.append(input,E('span',t(key)));unsupported.append(label);}form.append(unsupported);
    const label=E('label',undefined,'language');label.append(E('span',t('choose')));const select=E('select');select.setAttribute('aria-label',t('choose'));
    for(const [value,title] of [['system',t('system')],['en','English'],['zh-CN','简体中文'],['zh-TW','繁體中文']]){const o=E('option',title);o.value=value;select.append(o);}select.value=languageMode;
    select.addEventListener('change',()=>{languageMode=select.value;language=languageMode==='system'?systemLanguage():languageMode;rendered='';render();save();renderSettings();});label.append(select);form.append(label);
    const theme=E('label',undefined,'language'),picker=E('select');theme.append(E('span',t('appearance')),picker);
    for(const mode of ['system','light','dark']){const option=E('option',t(mode));option.value=mode;picker.append(option);}
    picker.value=appearance;picker.onchange=()=>{appearance=picker.value;host.dataset.appearance=appearance;save();};form.append(theme);
  }
  function render(){
    if(!shadow)return;
    const now=Date.now(),states=Object.fromEntries(keys.map(k=>[k,M.readingState(blocked?null:cells[k],now)]));
    const values=Object.fromEntries(keys.map(k=>[k,['current','previous'].includes(states[k])?cells[k].value:null]));
    const times=keys.filter(k=>choices[k]&&values[k]!==null).map(k=>cells[k].at);
    const stamp=times.length?new Date(Math.min(...times)).toLocaleTimeString(language,{hour:'2-digit',minute:'2-digit'}):'';
    const signature=JSON.stringify({states,values,stamp,language,choices,editing,busy,blocked});
    if(signature===rendered)return;rendered=signature;
    shadow.querySelector('.title').textContent=t('title');shadow.querySelector('.shared').textContent=t('shared');
    const glance=shadow.querySelector('.glance');
    glance.hidden=!choices.week||values.week===null;
    glance.textContent=glance.hidden?'':(states.week==='previous'?t('previous')+' · ':'')+t('glance')+' '+values.week+'%';
    settingsButton.textContent=t('settings');refreshButton.textContent=t(busy?'reading':'refresh');refreshButton.disabled=busy;
    body.hidden=editing;form.hidden=!editing;settingsButton.hidden=editing;
    status.textContent=blocked||busy?t(blocked?'blocked':'reading'):'';
    if(editing){if(!form.children.length)renderSettings();return;}
    form.replaceChildren();body.replaceChildren();
    if(!keys.some(k=>choices[k]))body.append(E('p',t('empty'),'hint'));
    const grid=E('dl',undefined,'metrics');
    for(const key of keys.filter(k=>choices[k])){
      const row=E('div',undefined,'metric '+key);row.dataset.metric=key;
      row.dataset.state=states[key];
      const missing=states[key]==='expired'?t('expired'):t('unsupported'),label=E('dt',t(key));
      if(states[key]==='previous')label.append(E('small',t('previous'),'prior'));
      row.append(label,E('dd',values[key]===null?(blocked&&key==='week'?'--':missing):key==='week'?values[key]+'%':key==='monthly'?values[key].toLocaleString(language):String(values[key])));
      if(key==='week'){
        const progress=E('div',undefined,'track');progress.setAttribute('role','progressbar');progress.setAttribute('aria-label',t('week'));progress.setAttribute('aria-valuemin','0');progress.setAttribute('aria-valuemax','100');
        if(values[key]!==null){progress.setAttribute('aria-valuenow',String(values[key]));const fill=E('i');fill.style.width=values[key]+'%';progress.append(fill);}else progress.setAttribute('aria-valuetext',t('missing'));row.append(progress);
      }
      if(values[key]===null)row.classList.add('unknown');grid.append(row);
    }
    body.append(grid);
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
      bring.className='primary';bring.disabled=blocked||!Object.values(values).some(v=>v!==null)||!M.collect(document,location.pathname,location.search).overview;
      body.append(bring);
    }
    const note=E('span',t('details'),'hint');footer.append(link,note);body.append(footer);
    if(stamp)footer.append(E('span',t('stamp')+' '+stamp,'stamp hint'));
    shadow.querySelector('.version').textContent='Web '+chrome.runtime.getManifest().version;
    const update=shadow.querySelector('.update');update.hidden=!updateVersion;
    if(updateVersion){update.textContent=t('update')+' '+updateVersion;update.href='https://github.com/kefen/AI-Usage-Monitor/releases/tag/chrome/v'+updateVersion;}
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
    host.dataset.appearance=appearance;shadow=host.attachShadow({mode:'open'});const style=E('style');style.textContent=STYLE;shadow.append(style);
    details=E('details');details.open=!collapsed;const summary=E('summary'),image=E('img');image.src=chrome.runtime.getURL('icon-32.png');image.alt='';image.width=image.height=16;
    details.addEventListener('toggle',event=>{
      if(event.currentTarget!==details||!details.isConnected)return;
      if(collapsed===details.open){collapsed=!details.open;save(false);}
      if(details.open)startProbe();
    });
    summary.append(image,E('span',t('title'),'title'),E('span','','glance'));details.append(summary,E('p',t('shared'),'shared'));
    body=E('section');body.setAttribute('aria-label',t('title'));form=E('section');form.hidden=true;details.append(body,form);
    const tools=E('div',undefined,'tools');refreshButton=command(t('refresh'),probe);settingsButton=command(t('settings'),()=>{editing=true;rendered='';render();renderSettings();form.querySelector('input')?.focus();});settingsButton.className='sliders';refreshButton.className='refresh';tools.append(refreshButton,settingsButton);
    status=E('div',undefined,'status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
    const meta=E('div',undefined,'meta'),update=E('a','','update');update.hidden=true;update.target='_blank';update.rel='noopener noreferrer';
    meta.append(E('span','Web '+chrome.runtime.getManifest().version,'version'),update);
    details.append(tools,status,meta);shadow.append(details);parent.append(host);rendered='';read();
    startProbe();
  }
  function startProbe(){
    if(location.pathname==='/settings/usage'||attempted||blocked||document.hidden||busy||!details?.open)return;
    attempted=true;const panel=details,route=location.href;
    setTimeout(()=>{
      if(panel!==details)return;
      if(!panel.isConnected||!panel.open||blocked||document.hidden||stopped||route!==location.href){attempted=false;return;}
      probe();
    },250);
  }
  const STYLE=`
    :host{color-scheme:light;--ink:#252c33;--muted:#546371;--line:#d5dde2;--surface:#f9fbfc;--accent:#315e79;--meter:#397c77;font:12px/1.45 system-ui,-apple-system,"Segoe UI",sans-serif;color:var(--ink)}
    @media(prefers-color-scheme:dark){:host(:not([data-appearance="light"])){color-scheme:dark;--ink:#e9eff1;--muted:#b1c1ca;--line:#435059;--surface:#232b30;--accent:#a6cfe5;--meter:#80c9b9}}
    :host([data-appearance="dark"]){color-scheme:dark;--ink:#e9eff1;--muted:#b1c1ca;--line:#435059;--surface:#232b30;--accent:#a6cfe5;--meter:#80c9b9}
    *{box-sizing:border-box;letter-spacing:0}[hidden]{display:none!important}
    details{background:var(--surface);padding:7px 10px;margin:4px 6px 6px;border:1px solid var(--line);border-radius:7px;max-height:min(52dvh,440px);overflow:auto;scrollbar-width:thin}
    summary{display:flex;align-items:center;gap:6px;min-height:26px;list-style:none;cursor:pointer;font-size:13px;font-weight:650}summary::-webkit-details-marker{display:none}
    summary::after{content:'';flex:none;width:6px;height:6px;border:solid var(--muted);border-width:0 1.5px 1.5px 0;transform:rotate(-135deg);margin:3px 2px 0 auto}details:not([open]) summary::after{transform:rotate(45deg);margin-top:-3px}
    img{flex:none}.title,.glance{min-width:0;overflow-wrap:anywhere}.glance{color:var(--accent);margin-left:auto;text-align:end;font-size:11px;font-variant-numeric:tabular-nums}details[open] .glance{display:none}
    .shared,.hint,.status,.version,.stamp,dt{font-size:11px;color:var(--muted)}.shared{margin:1px 0 7px}
    .metrics{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px 10px;margin:0 0 8px}.metric{min-width:0}dt{display:flex;align-items:baseline;gap:4px;flex-wrap:wrap}.prior{font-size:10px;color:var(--muted);font-weight:400}.prior::before{content:'· '}
    dd{font-size:14px;line-height:1.35;font-weight:600;font-variant-numeric:tabular-nums;margin:1px 0 0;overflow-wrap:anywhere}.unknown dd{font-size:11px;color:var(--muted);font-weight:400}
    .week{grid-column:1/-1;display:grid;grid-template-columns:1fr auto;align-items:baseline;gap:3px 8px;padding:6px 0 8px;border-block:1px solid var(--line)}.week:not(.unknown) dd{font-size:22px;line-height:1.1}
    .track{grid-column:1/-1;position:relative;background:var(--line);height:5px;border-radius:1px;overflow:hidden}.track i{display:block;height:100%;background:var(--meter)}.track::after{content:'';position:absolute;inset:0;background:repeating-linear-gradient(90deg,transparent 0,transparent calc(10% - 1.5px),var(--surface) calc(10% - 1.5px),var(--surface) 10%)}
    .foot,.tools,.meta,.language{display:flex;align-items:center;flex-wrap:wrap;gap:4px 8px}.foot{border-top:1px solid var(--line);padding-top:6px;font-size:11px}.foot .hint{margin-inline-start:auto}.foot .stamp{display:block;width:100%;margin:0}
    .tools{margin-top:7px}.meta{justify-content:space-between;margin-top:5px}.status:empty{display:none}.status{margin-top:4px}a{color:var(--accent);text-underline-offset:2px}
    button,select{font:inherit;color:inherit;border:1px solid var(--line);border-radius:4px;background:var(--surface);min-height:29px;padding:3px 9px;cursor:pointer;max-width:100%}
    button:hover:enabled{border-color:var(--accent)}button:disabled{opacity:.7;cursor:wait}.refresh,button.primary{color:white;background:#244c72;border-color:#244c72}.refresh:hover:enabled{background:#193d60}
    .sliders::before{content:'';display:inline-block;width:13px;height:13px;margin-inline-end:5px;vertical-align:-2px;background:currentColor;mask:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='none' stroke='black' stroke-width='1.5'%3E%3Cpath d='M1 4h3m4 0h7M1 12h7m4 0h3'/%3E%3Ccircle cx='6' cy='4' r='2'/%3E%3Ccircle cx='10' cy='12' r='2'/%3E%3C/svg%3E") center/contain no-repeat}
    :focus-visible{outline:2px solid var(--accent);outline-offset:2px}h2{font-size:13px;margin:0;flex:1}.check{display:flex;gap:7px;align-items:center;min-height:26px}.check input{accent-color:var(--accent);margin:0}
    fieldset{border:0;border-top:1px solid var(--line);margin:8px 0;padding:5px 0;color:var(--muted);min-width:0}legend{font-size:11px}.language{justify-content:space-between;border-top:1px solid var(--line);padding:5px 0}.language select{max-width:125px}
  `;
  function tick(){if(stopped||document.hidden)return;mount();if(host?.isConnected)read();const nextShell=document.getElementById('app-shell-sidebar');if(nextShell!==shell){observer?.disconnect();shell=nextShell;if(shell){observer=new MutationObserver(records=>{if(records.every(r=>r.target===host||host?.contains(r.target)))return;schedule();});observer.observe(shell,{childList:true,subtree:true,characterData:true,attributes:true,attributeFilter:['aria-description','aria-expanded','value','aria-valuenow','hidden']});}}}
  document.addEventListener('click',event=>{
    if(event.composedPath().includes(host))return;
    const button=event.target.closest?.('button');
    if(button&&['Open profile menu','打开个人资料菜单','開啟個人資料選單'].includes(button.getAttribute('aria-label')))invalidate();
  },true);
  document.addEventListener('visibilitychange',()=>{if(!document.hidden)tick();});
  document.addEventListener('keydown',event=>{if(event.key==='Escape'&&editing){editing=false;rendered='';render();settingsButton?.focus();}});
  window.addEventListener('languagechange',()=>{if(languageMode==='system'){language=systemLanguage();rendered='';render();if(editing)renderSettings();}});
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
    const prefs=result.cqsWebPreferences;if(['en','zh-CN','zh-TW'].includes(prefs?.language))language=languageMode=prefs.language;if(['dark','light'].includes(prefs?.appearance))appearance=prefs.appearance;
    collapsed=prefs?.collapsed===true;
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
