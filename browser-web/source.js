(() => {
  'use strict';
  const fields=['plan','week','credits','resets','reset','short','tokens','monthly'];
  const blank=()=>Object.fromEntries(fields.map(key=>[key,null]));
  const clean=value=>typeof value==='string'?value.replace(/\s+/g,' ').trim():'';
  const one=values=>{const found=[...new Set(values.filter(x=>x!==null&&x!==undefined))];return found.length===1?found[0]:null;};
  const percent=value=>{if(typeof value!=='number'&&typeof value!=='string')return null;const n=Number(value);return /^\d+(?:\.\d+)?$/.test(String(value))&&Number.isFinite(n)&&n>=0&&n<=100?n:null;};
  function weekly(text){
    const m=clean(text).match(/^(?:Weekly (?:usage|limit)\s*:\s*(\d+(?:\.\d+)?)% left|Weekly limit (\d+(?:\.\d+)?)% left|每[周週](?:用量|限[额額])\s*[：:]?\s*剩[余餘]\s*(\d+(?:\.\d+)?)%)$/i);
    return m?percent(m[1]||m[2]||m[3]):null;
  }
  function credit(text){
    const number='((?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?:\\.[0-9]+)?)';
    const m=clean(text).match(new RegExp('^(?:(?:Credits\\s+)?'+number+'\\s+credits|(?:Credits|Remaining credits|Credit balance)\\s*:\\s*'+number+'(?:\\s+credits)?|(?:剩[余餘][额額]度[：:]|[额額]度\\s*[：:]?)\\s*'+number+'(?:\\s*[额額]度)?)$','i'));
    if(!m)return null;const n=BigInt((m[1]||m[2]||m[3]).split('.')[0].replaceAll(',',''));
    return n<=BigInt(Number.MAX_SAFE_INTEGER)?String(n):null;
  }
  function plan(text){
    const m=clean(text).match(/^(?:ChatGPT (Free|Go|Plus|Pro(?: (?:100|200|500))?|Business|Enterprise|Edu)|Usage source: Your (Free|Go|Plus|Pro|Business|Enterprise|Edu) plan|[额額]度来源[：:]\s*你的 (Free|Go|Plus|Pro|Business|Enterprise|Edu) 套餐)$/);
    return m?(m[1]||m[2]||m[3]):null;
  }
  function monthly(text){
    const m=clean(text).match(/^(?:Tokens (?:used )?this month|This month(?:'s)? tokens|本月(?:已用|消耗)?\s*Token(?:s)?)\s*[:：]\s*(\d{1,3}(?:,\d{3})+|\d+)$/i);
    const value=m?Number(m[1].replaceAll(',','')):null;
    return Number.isSafeInteger(value)?value:null;
  }
  function parse(input={},now=Date.now()){
    const x={...blank(),at:now},menu=Array.isArray(input.menu)?input.menu:[],o=input.overview||{};
    const overviewWeeks=(o.weeks||[]).map(w=>/^剩[余餘]用量$|^Remaining usage$/i.test(clean(w.label))&&Number(w.max)===100?percent(w.value):null);
    x.week=one([weekly(input.description),...menu.map(weekly),...overviewWeeks]);
    x.monthly=one([...menu,...(o.monthly||[])].map(monthly));
    x.credits=one([...menu,...(o.credits||[])].map(credit));
    const plans=[...menu,...(o.plans||[])].map(plan).filter(Boolean);
    x.plan=one(plans.filter(p=>p!=='Pro'||!plans.some(v=>/^Pro \d+$/.test(v))));
    x.resets=one((o.resets||[]).map(label=>{const m=clean(label).match(/^(?:Available\s+|可用\s*)(\d+)$/i);const n=m?Number(m[1]):null;return Number.isSafeInteger(n)?n:null;}));
    x.reset=one((o.resetTimes||[]).map(clean).filter(t=>t.length<=90&&(/^[0-9].*(?:后重置|後重置|後重設)$/.test(t)||/^Resets? in [0-9].*$/i.test(t))));
    return x;
  }
  const visible=(x,now=Date.now(),blocked=false)=>!x||blocked||!Number.isFinite(x.at)||x.at>now||now-x.at>=60000?blank():Object.fromEntries(fields.map(key=>[key,x[key]??null]));
  const shown=el=>el&&el.getClientRects().length>0&&!el.closest('[hidden],[aria-hidden="true"]');
  function trigger(doc){
    const buttons=[...doc.querySelectorAll('nav[data-app-navigation-rail="true"] button[aria-label]')].filter(el=>(shown(el)||(el.getClientRects().length&&el.getAttribute('aria-expanded')==='true'))&&['Usage','用量','使用量'].includes(el.getAttribute('aria-label')));
    return buttons.length===1?buttons[0]:null;
  }
  function collect(doc,path,search){
    const button=trigger(doc),input={description:button?.getAttribute('aria-description')||'',menu:[]};
    if(button?.getAttribute('aria-expanded')==='true'){
      const menus=[...doc.querySelectorAll('[role="menu"]')].filter(el=>shown(el)&&((button.id&&el.getAttribute('aria-labelledby')===button.id)||(el.id&&button.getAttribute('aria-controls')===el.id)||['Usage','用量','使用量'].includes(el.getAttribute('aria-label'))));
      if(menus.length===1){
        const menu=menus[0];
        const items=[...menu.querySelectorAll('[role="menuitem"]')].filter(shown);
        input.menu=[...new Set([...(menu.innerText||'').split(/\r?\n/),...items.map(el=>el.innerText)].map(clean).filter(t=>t&&t.length<160))];
      }
    }
    if(path==='/settings/usage'&&(!new URLSearchParams(search).get('tab')||new URLSearchParams(search).get('tab')==='overview')){
      const resets=doc.getElementById('usage-limit-resets');
      // The account's credit balance is in a sibling section, outside the limit/reset widget.
      const anchor=resets||doc.querySelector('progress[aria-label="Remaining usage"],progress[aria-label="剩余用量"],[role="progressbar"][aria-label="剩余用量"]');
      const section=anchor?.closest('section');
      const sections=section?[...section.parentElement.children].filter(n=>n.tagName==='SECTION'):[];
      let fallback=resets;
      while(fallback&&fallback!==doc.body&&!fallback.querySelector('progress,[role="progressbar"]'))fallback=fallback.parentElement;
      const roots=sections.length?sections:fallback&&fallback!==doc.body?[fallback]:[];
      for(const root of roots.filter(shown)){
        const leaves=[...root.querySelectorAll('div,span')].filter(el=>shown(el)&&!el.children.length).map(el=>clean(el.textContent)).filter(t=>t.length<160);
        const weeks=[...root.querySelectorAll('progress,[role="progressbar"]')].filter(shown).filter(el=>{
          let p=el;for(let i=0;p&&p!==root&&i<5;i++,p=p.parentElement){if([...p.querySelectorAll('div,span')].some(n=>!n.children.length&&/^(?:Weekly limit|每[周週]限[额額])$/.test(clean(n.textContent))))return true;}return false;
        }).map(el=>({value:el.getAttribute('value')??el.getAttribute('aria-valuenow'),max:el.getAttribute('max')??el.getAttribute('aria-valuemax'),label:el.getAttribute('aria-label')}));
        const o=input.overview||={weeks:[],plans:[],credits:[],resets:[],resetTimes:[],monthly:[]};
        o.weeks.push(...weeks);o.plans.push(...leaves.filter(t=>t.startsWith('ChatGPT ')));
        o.credits.push(...leaves.filter(t=>credit(t)!==null&&!/^\d/.test(t)));
        o.resets.push(...[...root.querySelectorAll('[role="tab"]')].filter(shown).map(el=>clean(el.textContent)));
        o.resetTimes.push(...leaves.filter(t=>/后重置$|後重置$|後重設$|^Resets? in /i.test(t)));
        o.monthly.push(...leaves.filter(t=>monthly(t)!==null));
      }
    }
    return input;
  }
  globalThis.CQSWebSource=Object.freeze({parse,visible,collect,trigger});
})();
