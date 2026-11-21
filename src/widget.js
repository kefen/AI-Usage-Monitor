(() => {
  if (window.__localCodexMeter?.version === '0.13.7') return;
  if (window.__localCodexMeter?.controllerId === 'local-codex-sidebar-meter-v1') window.__localCodexMeter.dispose();
  else if (window.__localCodexMeter) return;
  const id = 'local-codex-sidebar-meter';
  const root = document.createElement('div');
  root.id = id;
  root.style.cssText = 'display:block;flex:0 0 auto;min-width:0;width:36px;max-width:100%;margin:4px 0;';
  root.tabIndex = 0;
  const shadow = root.attachShadow({ mode: 'open' });
  const style = document.createElement('style');
  style.textContent = `
    :host{font-family:inherit;color:inherit;font-size:11px;font-weight:400;line-height:1.4;letter-spacing:0}
    :host(:focus-visible){outline:2px solid currentColor;outline-offset:2px;border-radius:4px}
    *{box-sizing:border-box}section{display:flex;flex-direction:column;gap:8px;min-width:0;padding:4px 0;scrollbar-width:thin;overscroll-behavior:contain}section>*{flex-shrink:0}
    .compact{width:32px;height:32px;padding:0;border:1px solid #c7d8f5;border-radius:4px;background:#eaf1ff;color:#285cae;cursor:pointer;font:inherit}
    .window{text-align:center;flex-shrink:0;width:100%}.label{font-size:10px;opacity:.65;white-space:nowrap}
    .percent{font-size:11px;line-height:18px;font-variant-numeric:tabular-nums;font-weight:400;white-space:nowrap}
    .track{height:3px;background:color-mix(in srgb,currentColor 14%,transparent);border-radius:2px;margin:5px auto 0;width:26px}
    .fill{height:3px;border-radius:2px}.empty{font-size:11px;opacity:.6;text-align:center;line-height:18px}
    .stale{opacity:.5}
    .reset{margin-top:10px}.reset-date,.membership-date{font-size:10px;line-height:18px;font-variant-numeric:tabular-nums;white-space:nowrap}.membership{text-align:center;flex-shrink:0}
    .membership .label{font-size:10px}
    .usage{display:flex;flex-direction:column;gap:6px;border-top:1px solid color-mix(in srgb,currentColor 12%,transparent);padding-top:6px;flex-shrink:0}
    .usage-metric{text-align:center;width:100%}.daily-date{font-size:9px;opacity:.65;white-space:nowrap}.value{font-size:10px;font-weight:400;line-height:18px;font-variant-numeric:tabular-nums;white-space:nowrap}.unit{text-align:center;font-size:8px;opacity:.55}
    @media(forced-colors:active){.track{border:1px solid CanvasText}.fill{background:Highlight!important}}
  `;
  shadow.append(style);
  const section = document.createElement('section');
  section.setAttribute('aria-label', '\u672c\u673a CLI \u8d26\u6237\u989d\u5ea6');
  shadow.append(section);
  const compact = document.createElement('button');
  compact.className='compact';compact.textContent='\u25a5';compact.hidden=true;
  compact.addEventListener('click',()=>{
    if(typeof window.__cqsOpenOverview==='function')window.__cqsOpenOverview('open-overview');
  });
  shadow.append(compact);
  let layoutMode='hidden', layoutReason='sidebar-unrecognized', observedTarget=null, disposed=false;
  const schedule=()=>{
    if(scheduled||disposed)return;
    scheduled=true;requestAnimationFrame(()=>{scheduled=false;if(!disposed)mount();});
  };
  const resize=new ResizeObserver(schedule);
  let state = {}, heartbeat = Date.now(), scheduled = false, lastRenderKey;
  const words={
    '服务端日期标签，分桶时区未核实；相对日期按 UTC 比较。周汇总从周一起，不是订阅额度周期。':['Server date labels; bucket timezone unverified. Relative dates use UTC. Weeks start Monday, independently of quota resets.','伺服器日期標籤，分桶時區未核實；相對日期按 UTC 比較。週彙總從週一起，不是訂閱額度週期。'],
    '按用户充值日期和月付假设推算，未核对账单':['Estimated from purchase date and monthly billing; bill not verified','按使用者購買日期和月付假設推算，未核對帳單'],
    '以订阅页面为准。不自动顺延。':['Check your subscription page. Not automatically rolled forward.','以訂閱頁面為準。不自動順延。'],
    '会员日期未设置，不从周额度推测':['Subscription date not set; never inferred from weekly quota','訂閱日期未設定，不從週額度推測'],
    '积分无限制（不代表时段额度无限）':['Unlimited credits (not unlimited quota windows)','點數無限制（不代表時段額度無限）'],
    '次数':['Resets','次數'],'积分余额':['Credits','額度'],'可用额度重置次数':['Available quota resets','可用額度重設次數'],
    '仅展示，不自动使用':['Display only; never used automatically','僅顯示，不自動使用'],
    '暂无可用每日 Token 数据，已隐藏日用量':['No daily Token data; daily metric hidden','暫無可用每日 Token 資料，已隱藏日用量'],
    '本机首次观测':['First observed locally','本機首次觀測'],'上次尚未返回':['Last observed absent','上次尚未回傳'],
    '观测时间不等于官方发布时间；关闭期间不观测':['Observation is not publication time; no observations while stopped','觀測時間不等於官方發布時間；關閉期間不觀測'],
    '本周已返回记录':['Returned weekly records','本週已回傳記錄'],'天，四舍五入；不含缺失日期':['days, rounded; missing dates excluded','天，四捨五入；不含缺失日期'],
    '数据不完整':['Incomplete data','資料不完整'],'天，缺失日期不按 0 计算':['days; missing dates are not zero','天，缺失日期不按 0 計算'],
    '不完整':['Incomplete','不完整'],'官方账号 Token 活动（本机 CLI 登录账号）；不是 API 账单':['Account Token activity (local CLI login); not an API bill','官方帳戶 Token 活動（本機 CLI 登入帳戶）；不是 API 帳單'],
    '启动时读取，之后每 60 分钟刷新':['Read at startup, then every 60 minutes','啟動時讀取，之後每 60 分鐘更新'],
    '本机 CLI 账户额度':['Local CLI account quota','本機 CLI 帳戶額度'],'下次':['Next','下次'],'天':['day','天'],
    '5h余':['5h','5h餘'],'周余':['Week','週餘'],'额度':['Credits','額度'],'重置':['Reset','重設'],'续费':['Renew','續費'],'到期':['Expiry','到期'],
    '今日':['Today','今日'],'昨日':['Yest.','昨日'],'最近':['Latest','最近'],'日均':['Avg','日均'],'本周':['Week','本週'],'本月':['Month','本月'],'累计':['Total','累計'],
    '待刷新':['Pending','待更新'],'已同步':['Synced','已同步'],'可能过期':['May be stale','可能過期'],'数据已过期':['Data expired','資料已過期'],'读取失败':['Read failed','讀取失敗'],
    '北京时间':['Asia/Shanghai','北京時間'],'剩余':['Remaining','剩餘'],'已用':['Used','已用'],'后重置':['until reset','後重設'],'重置时间未返回':['Reset time unavailable','未回傳重設時間'],
    '等待服务端刷新':['Waiting for server','等待伺服器更新'],'服务端未返回重置时间':['No reset time returned','伺服器未回傳重設時間'],
    '用户手动记录，未核验真实账号':['Manual record; account not verified','使用者手動記錄，未驗證真實帳戶'],
    '从已核验桌面识别套餐大类；具体档位和日期未核验':['Plan family detected from verified desktop; tier and dates not verified','從已驗證桌面辨識方案大類；具體級別和日期未驗證'],
    '套餐未识别，可在套餐与日期中手动选择':['Plan unknown; select manually in Plan and dates','方案未辨識，可在方案與日期中手動選擇'],
    '用户手动填写':['Manually recorded','使用者手動填寫'],'预计':['Estimated','預估'],'会员':['Subscription','訂閱'],
    '来源':['Source','來源'],'本机 CLI 账户，请与桌面账户核对':['Local CLI account; verify desktop account','本機 CLI 帳戶，請與桌面帳戶核對'],
    '最后同步':['Last sync','最後同步'],'暂无可用数据':['Data unavailable','暫無可用資料']
  };
  const translated=value=>{
    if(!state.language||state.language==='zh-CN')return value;
    for(const key of Object.keys(words).sort((a,b)=>b.length-a.length))value=value.split(key).join(words[key][state.language==='en'?0:1]);
    return value;
  };
  const text = (tag, value, cls) => {
    const e = document.createElement(tag); e.textContent = value;
    if (cls) e.className = cls;
    return e;
  };
  const beijingTime=value=>new Date(value).toLocaleString(state.language||'zh-CN',{timeZone:'Asia/Shanghai'});
  const status = now => {
    if (!Number.isFinite(state.fetchedAt)) return 'unavailable';
    const age = now - state.fetchedAt;
    return age > 900000 ? 'expired' : state.error || age > 180000 ? 'stale' : 'fresh';
  };
  const resetText = seconds => {
    if (typeof seconds !== 'number') return '\u91cd\u7f6e\u65f6\u95f4\u672a\u8fd4\u56de';
    const minutes = Math.ceil((seconds - Date.now()/1000)/60);
    if (minutes <= 0) return '\u7b49\u5f85\u670d\u52a1\u7aef\u5237\u65b0';
    const duration = minutes < 60 ? `${minutes}m` : minutes < 1440 ? `${Math.floor(minutes/60)}h ${minutes%60}m` : `${Math.floor(minutes/1440)}d ${Math.floor(minutes%1440/60)}h`;
    return `${duration} \u540e\u91cd\u7f6e`;
  };
  function render() {
    const renderKey=JSON.stringify(state)+Math.floor(Date.now()/60000);
    if(renderKey===lastRenderKey) return;
    lastRenderKey=renderKey;
    const freshness = status(Date.now());
    section.replaceChildren();
    const visible=key=>state.visible?.[key]!==false;
    if(visible('plan')){const badge=text('div',['Free','Go','Plus','Pro','Biz','Ent','Edu','Other'].includes(state.planBadge)?state.planBadge:'?','plan-badge');badge.style.cssText='text-align:center;font-size:10px;font-weight:400;border:1px solid #c7d8f5;background:#eaf1ff;color:#285cae;border-radius:4px;padding:3px 0';badge.title=({Biz:'Business',Ent:'Enterprise'})[badge.textContent]||badge.textContent;badge.title+=': '+(badge.textContent==='?'?'套餐未识别，可在套餐与日期中手动选择':state.planSource==='desktop'?'从已核验桌面识别套餐大类；具体档位和日期未核验':'用户手动记录，未核验真实账号');section.append(badge);}
    const statusLabel = {
      fresh:'\u5df2\u540c\u6b65', stale:'\u53ef\u80fd\u8fc7\u671f', expired:'\u6570\u636e\u5df2\u8fc7\u671f', unavailable:'\u8bfb\u53d6\u5931\u8d25'
    }[freshness];
    const hints = ['\u5269\u4f59\u989d\u5ea6: ' + statusLabel];
    const buckets = ['expired','unavailable'].includes(freshness) ? [] : (state.buckets || []);
    const resetCount=text('div','','window');resetCount.dataset.metric='resetCredits';
    if(visible('resetCredits')) {
      const block=resetCount;
      block.append(text('div','\u6b21\u6570','label'),text('div',!['expired','unavailable'].includes(freshness)&&Number.isSafeInteger(state.resetCredits)?String(state.resetCredits):'--','value'));
      block.title='Available quota resets; read-only. No reset is performed.';
    }
    for (const bucket of buckets) {
      for (const w of bucket.windows) {
        const showWindow=visible(w.minutes===10080?'week':'short');
        if(!showWindow && !(w.minutes===10080&&visible('reset')))continue;
        const block = text('div', '', 'window' + (freshness === 'stale' ? ' stale' : ''));
        const label = w.minutes === 300 ? '5h\u4f59' : w.minutes === 10080 ? '\u5468\u4f59' : '\u989d\u5ea6';
        const used=Math.round((100-w.remaining)*10)/10;
        const detail = `${bucket.id} / ${w.minutes} min\n\u5269\u4f59 ${w.remaining}% / \u5df2\u7528 ${used}%\n${resetText(w.resetsAt)}`;
        block.title = detail + (w.resetsAt ? '\n\u5317\u4eac\u65f6\u95f4 ' + beijingTime(w.resetsAt*1000) : '');
        hints.push(detail);
        const track = text('div', '', 'track');
        track.setAttribute('role','progressbar'); track.setAttribute('aria-label', label + ' \u5269\u4f59');
        track.setAttribute('aria-valuemin','0'); track.setAttribute('aria-valuemax','100'); track.setAttribute('aria-valuenow',String(w.remaining));
        const fill = text('div', '', 'fill');
        fill.style.width = `${w.remaining}%`;
        fill.style.background = w.remaining > 50 ? '#26936a' : w.remaining >= 20 ? '#bd871e' : '#d64a4a';
        track.append(fill);
        if(showWindow)block.append(text('div', label, 'label'), text('div', `${w.remaining}%`, 'percent'), track); section.append(block);
        if(w.minutes===10080&&visible('reset')) {
          const reset=text('div','','reset');
          const date=Number.isFinite(w.resetsAt)&&w.resetsAt>0?new Date(w.resetsAt*1000):null;
          const valid=date && Number.isFinite(date.getTime());
          const passed=valid && date.getTime()<=Date.now();
          const stamp=valid ? passed ? '\u5f85\u5237\u65b0' : date.toLocaleDateString('en-US',{timeZone:'Asia/Shanghai',month:'numeric',day:'numeric'}) : '--';
          reset.title=valid ? '\u989d\u5ea6\u91cd\u7f6e\uff08\u5317\u4eac\u65f6\u95f4\uff09: '+date.toLocaleString('zh-CN',{timeZone:'Asia/Shanghai',year:'numeric',month:'numeric',day:'numeric',weekday:'long',hour:'2-digit',minute:'2-digit'}) : '\u670d\u52a1\u7aef\u672a\u8fd4\u56de\u91cd\u7f6e\u65f6\u95f4';
          reset.append(text('div','\u91cd\u7f6e','label'),text('div',stamp,'reset-date'));
          block.append(reset);
        }
      }
      if(bucket.credits?.unlimited) hints.push(`${bucket.id}: \u79ef\u5206\u65e0\u9650\u5236\uff08\u4e0d\u4ee3\u8868\u65f6\u6bb5\u989d\u5ea6\u65e0\u9650\uff09`);
      else if(bucket.credits?.balance!==null && bucket.credits?.balance!==undefined) hints.push(`${bucket.id}: \u79ef\u5206\u4f59\u989d ${bucket.credits.balance}`);
    }
    if (!section.children.length&&(visible('short')||visible('week'))) section.append(text('div', '\u989d\u5ea6\n--', 'empty'));
    if(visible('resetCredits'))section.append(resetCount);
    const member=state.membership;
    const membership=text('div','','membership');
    const memberLabel=member?.kind==='expiry'?'\u5230\u671f':'\u7eed\u8d39';
    const memberDate=member?.date && /^\d{4}-\d{2}-\d{2}$/.test(member.date)?member.date:null;
    membership.title=memberDate ? `${member.estimated?'\u9884\u8ba1':''}\u4f1a\u5458${memberLabel}: ${memberDate}\n${member.estimated?'\u6309\u7528\u6237\u5145\u503c\u65e5\u671f\u548c\u6708\u4ed8\u5047\u8bbe\u63a8\u7b97\uff0c\u672a\u6838\u5bf9\u8d26\u5355':'\u7528\u6237\u624b\u52a8\u586b\u5199'}\uff1b\u4ee5\u8ba2\u9605\u9875\u9762\u4e3a\u51c6\u3002\u4e0d\u81ea\u52a8\u987a\u5ef6\u3002` : '\u4f1a\u5458\u65e5\u671f\u672a\u8bbe\u7f6e\uff0c\u4e0d\u4ece\u5468\u989d\u5ea6\u63a8\u6d4b';
    membership.append(text('div',memberLabel,'label'),text('div',memberDate?memberDate.slice(5).split('-').map(Number).join('/'):'--','membership-date'));
    if(memberDate&&visible('renewal')){section.append(membership);hints.push(membership.title);}
    if(visible('credits')) {
      const creditBuckets=buckets.filter(b=>b.credits);
      const credits=creditBuckets.length===1?creditBuckets[0].credits:null;
      const balance=typeof credits?.balance==='string'&&/^\d+(\.\d+)?$/.test(credits.balance)&&Number.isSafeInteger(Math.floor(Number(credits.balance)))?String(Math.floor(Number(credits.balance))):'--';
      const block=text('div','','window');block.dataset.metric='credits';
      block.append(text('div','额度','label'),text('div',credits?.unlimited?'∞':balance,'value'));
      block.title='Credits; displayed as a whole number, rounded down. Separate from quota percentage. No purchase or reset action.';section.append(block);
    }
    if(freshness==='fresh' && Number.isSafeInteger(state.resetCredits)) hints.push(`\u53ef\u7528\u989d\u5ea6\u91cd\u7f6e\u6b21\u6570: ${state.resetCredits}\uff08\u4ec5\u5c55\u793a\uff0c\u4e0d\u81ea\u52a8\u4f7f\u7528\uff09`);
    const usage=state.usage || {};
    const nextRefresh=Number.isFinite(usage.nextRefreshAt)?usage.nextRefreshAt:null;
    const expires=nextRefresh===null?usage.fetchedAt+1800000:Math.min(nextRefresh+1800000,usage.fetchedAt+86400000);
    const usageValid=Number.isFinite(usage.fetchedAt) && !usage.error && Date.now()<=expires;
    const usageLate=Date.now()>(nextRefresh===null?usage.fetchedAt+600000:nextRefresh+600000);
    const exact=v=>Number.isSafeInteger(v)&&v>=0?v.toLocaleString('en-US'): '--';
    const compact=v=>{
      if(!Number.isSafeInteger(v)||v<0) return '--';
      const units=[[1e15,'Q'],[1e12,'T'],[1e9,'B'],[1e6,'M'],[1e3,'K']];
      for(const [base,suffix] of units) if(v>=base*.9995) return `${Number((v/base).toFixed(v/base>=100?0:1))}${suffix}`;
      return String(v);
    };
    const usageBox=text('div','','usage'+(usageLate?' stale':''));
    usageBox.append(text('div','TOKEN','unit'));
    const calendar='\u670d\u52a1\u7aef\u65e5\u671f\u6807\u7b7e\uff0c\u5206\u6876\u65f6\u533a\u672a\u6838\u5b9e\uff1b\u76f8\u5bf9\u65e5\u671f\u6309 UTC \u6bd4\u8f83\u3002\u5468\u6c47\u603b\u4ece\u5468\u4e00\u8d77\uff0c\u4e0d\u662f\u8ba2\u9605\u989d\u5ea6\u5468\u671f\u3002';
    const week=usage.week;
    const month=usage.month;
    const average={...month,value:Number.isSafeInteger(month?.average)&&month.average>=0?month.average:null};
    const daily=usage.dailySelected;
    const localDay=d=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
    const yesterday=new Date();yesterday.setDate(yesterday.getDate()-1);
    const utcDate=localDay(new Date()),previousDate=localDay(yesterday);
    const dailyLabel=daily?.date===utcDate?'\u4eca\u65e5':daily?.date===previousDate?'\u6628\u65e5':'\u6700\u8fd1';
    const metrics=[['average','\u65e5\u5747',average],['week','\u672c\u5468',week],['monthly','\u672c\u6708',month],['lifetime','\u7d2f\u8ba1',{value:usage.lifetime,complete:true}]];
    if(usageValid && daily && /^\d{4}-\d{2}-\d{2}$/.test(daily.date) && Number.isSafeInteger(daily.value) && daily.value>=0)metrics.unshift(['daily',dailyLabel,{...daily,start:daily.date,end:daily.date,complete:true}]);
    else hints.push('\u6682\u65e0\u53ef\u7528\u6bcf\u65e5 Token \u6570\u636e\uff0c\u5df2\u9690\u85cf\u65e5\u7528\u91cf');
    for(const [key,label,metric] of metrics) {
      if(!visible(key==='week'?'weekly':key))continue;
      const dayKey=stamp=>new Date(stamp).toISOString().slice(0,10);
      const monday=stamp=>{const d=new Date(dayKey(stamp));d.setUTCDate(d.getUTCDate()-(d.getUTCDay()+6)%7);return dayKey(d);};
      const samePeriod=usageValid && (key==='average'||key==='monthly'?month?.start===dayKey(Date.now()).slice(0,7)+'-01':key==='week'?monday(usage.fetchedAt)===monday(Date.now()):true);
      const value=samePeriod?metric?.value:null, partial=value!==null&&value!==undefined&&metric?.complete===false;
      const block=text('div','','usage-metric');block.dataset.metric=key;
      const detail=[`${label}: ${exact(value)} Token${key==='average'?' / \u5929':''}`];
      if(key==='daily'){
        const observed=(usage.observations||[]).find(r=>r.date===metric.date);
        if(Number.isFinite(observed?.firstSeenAt))detail.push('\u672c\u673a\u9996\u6b21\u89c2\u6d4b\uff08\u5317\u4eac\u65f6\u95f4\uff09: '+beijingTime(observed.firstSeenAt));
        if(Number.isFinite(observed?.lastAbsentAt))detail.push('\u4e0a\u6b21\u5c1a\u672a\u8fd4\u56de: '+beijingTime(observed.lastAbsentAt));
        detail.push('\u89c2\u6d4b\u65f6\u95f4\u4e0d\u7b49\u4e8e\u5b98\u65b9\u53d1\u5e03\u65f6\u95f4\uff1b\u5173\u95ed\u671f\u95f4\u4e0d\u89c2\u6d4b');
      }
      if(key==='average' && usageValid && value!==null) detail.push(`Month: ${exact(month.value)} Token / ${month.days} returned days`);
      if(key!=='lifetime') {
        if(metric?.start) detail.push(`${metric.start} ~ ${metric.end}`);
        if(partial) detail.push(`\u6570\u636e\u4e0d\u5b8c\u6574: ${metric.days}/${metric.expected} \u5929\uff0c\u7f3a\u5931\u65e5\u671f\u4e0d\u6309 0 \u8ba1\u7b97`);
        detail.push(calendar);
      }
      if(key==='week' && usageValid) for(const w of (usage.weeks||[]).slice(1,5)) detail.push(`${w.start} ~ ${w.end}: ${w.complete?'':'\u4e0d\u5b8c\u6574 '}${exact(w.value)} Token`);
      detail.push('\u6765\u6e90: \u5b98\u65b9\u8d26\u53f7 Token \u6d3b\u52a8\uff08\u672c\u673a CLI \u767b\u5f55\u8d26\u53f7\uff09\uff1b\u4e0d\u662f API \u8d26\u5355');
      if(!samePeriod) detail.push('\u6682\u65e0\u53ef\u7528\u6570\u636e');
      if(usageValid) detail.push(`${usageLate?'\u53ef\u80fd\u8fc7\u671f\uff1b':''}\u6700\u540e\u540c\u6b65\uff08\u5317\u4eac\u65f6\u95f4\uff09: ${beijingTime(usage.fetchedAt)}`);
      if(nextRefresh!==null) detail.push(`\u542f\u52a8\u65f6\u8bfb\u53d6\uff0c\u4e4b\u540e\u6bcf 60 \u5206\u949f\u5237\u65b0\n\u4e0b\u6b21\uff08\u5317\u4eac\u65f6\u95f4\uff09: ${beijingTime(nextRefresh)}`);
      block.title=detail.join('\n');
      block.append(text('div',label,'label'));
      if(key==='daily'&&metric.date!==previousDate)block.append(text('div',metric.date.slice(5).split('-').map(Number).join('/'),'daily-date'));
      block.append(text('div',compact(value),'value'));
      usageBox.append(block);hints.push(detail.join('\n'));
    }
    if(usageBox.children.length>1)section.append(usageBox);
    hints.push('\u6765\u6e90: \u672c\u673a CLI \u8d26\u6237\uff0c\u8bf7\u4e0e\u684c\u9762\u8d26\u6237\u6838\u5bf9');
    if(state.fetchedAt) hints.push('\u6700\u540e\u540c\u6b65\uff08\u5317\u4eac\u65f6\u95f4\uff09: '+beijingTime(state.fetchedAt));
    root.title = hints.join('\n');
    for(const node of section.querySelectorAll('*')){if(node.children.length===0&&node.textContent)node.textContent=translated(node.textContent);if(node.title)node.title=translated(node.title);if(node.hasAttribute('aria-label'))node.setAttribute('aria-label',translated(node.getAttribute('aria-label')));}
    root.title=translated(root.title);
    root.setAttribute('aria-label', root.title);
  }
  function anchor() {
    // The navigation rail is distinct from the wider conversation sidebar.
    const selectors = 'aside.app-shell-left-panel [data-app-navigation-rail],aside[data-testid="app-shell-floating-left-panel"] [data-app-navigation-rail]';
    const candidates = [...document.querySelectorAll(selectors)].filter(e => {
      const rect = e.getBoundingClientRect(), style = getComputedStyle(e);
      return e.offsetWidth >= 40 && e.offsetWidth <= 80 && rect.height >= 100 &&
        style.visibility !== 'hidden' && style.display !== 'none' &&
        style.display === 'flex' && style.flexDirection === 'column' &&
        !e.closest('[data-settings-panel-slug]') && !e.querySelector('[data-settings-panel-slug]');
    });
    return candidates.length === 1 ? candidates[0] : null;
  }
  function mount() {
    const target = anchor();
    for (const e of document.querySelectorAll('#' + id)) if (e !== root) e.remove();
    const bottom = target && [...target.children].filter(e=>e!==root).at(-1);
    if(observedTarget!==target){resize.disconnect();observedTarget=target;if(target){resize.observe(target);for(const child of target.children)if(child!==root)resize.observe(child);}}
    const previous=layoutMode;
    layoutMode='hidden';layoutReason='sidebar-unrecognized';
    if(!bottom||target.children.length<2){root.remove();return;}
    if(root.parentElement!==target||root.nextElementSibling!==bottom)target.insertBefore(root,bottom);
    root.style.display='none';
    if(!section.children.length){layoutReason='disabled';return;}
    // Measure the official layout WITHOUT our contribution, including text and fixed controls.
    const rail=target.getBoundingClientRect(),css=getComputedStyle(target);
    const zoom=rail.width/target.offsetWidth||1;
    const gap=(parseFloat(css.rowGap)||0)*zoom;
    let top=Math.max(0,rail.top)+(parseFloat(css.paddingTop)||0)*zoom;
    const end=Math.min(innerHeight,rail.bottom,bottom.getBoundingClientRect().top);
    const controls=[...target.querySelectorAll('button,a,[role=button],input,[tabindex]')].filter(e=>e!==root&&!root.contains(e)&&e.getClientRects().length);
    for(const child of target.children){
      if(child===root||child===bottom||getComputedStyle(child).display==='none')continue;
      const style=getComputedStyle(child);
      if(Number(style.flexGrow)===0)top=Math.max(top,child.getBoundingClientRect().bottom);
      else {
        const walker=document.createTreeWalker(child,NodeFilter.SHOW_TEXT);
        for(let node=walker.nextNode();node;node=walker.nextNode())if(node.textContent.trim()){
          const range=document.createRange();range.selectNodeContents(node);
          for(const r of range.getClientRects())top=Math.max(top,r.bottom);
        }
        for(const e of controls)if(child.contains(e))top=Math.max(top,e.getBoundingClientRect().bottom);
      }
    }
    const baseline=controls.map(e=>({e,r:e.getBoundingClientRect()}));
    const budget=(end-top-2*gap)/zoom-8;
    section.style.display='flex';section.style.maxHeight='none';section.style.overflowY='visible';compact.hidden=true;root.style.display='block';
    const needed=section.getBoundingClientRect().height/zoom;
    const full=needed+(previous==='full'?0:16)<=budget;
    const scroll=!full&&budget>=(previous==='scroll'?120:136);
    if(scroll){section.style.maxHeight=Math.floor(budget)+'px';section.style.overflowY='auto';}
    if(!full&&!scroll){section.style.display='none';compact.hidden=false;}
    compact.title=state.language==='en'?'Open usage overview':state.language==='zh-TW'?'開啟用量概覽':'打开用量概览';
    compact.setAttribute('aria-label',compact.title);
    compact.disabled=typeof window.__cqsOpenOverview!=='function';
    const required=full?needed:scroll?Math.floor(budget):32;
    const box=root.getBoundingClientRect();
    const overlaps=(a,b)=>a.left<b.right&&a.right>b.left&&a.top<b.bottom&&a.bottom>b.top;
    const safe=required<=budget&&box.top>=Math.max(0,rail.top)&&box.bottom<=Math.min(innerHeight,rail.bottom)&&baseline.every(({e,r})=>{
      const now=e.getBoundingClientRect();
      if(overlaps(box,now)||Math.abs(now.top-r.top)>1||Math.abs(now.left-r.left)>1)return false;
      if(r.top>=0&&r.bottom<=innerHeight){const hit=document.elementFromPoint(now.x+now.width/2,now.y+now.height/2);if(!hit||!(hit===e||e.contains(hit)))return false;}
      return true;
    });
    if(!safe){root.style.display='none';layoutReason='official-controls-priority';return;}
    layoutMode=full?'full':scroll?'scroll':'compact';layoutReason=full?'available':scroll?'scroll-space':'limited-space';
  }
  const observer = new MutationObserver(records => {
    const relevant=records.some(r=>r.target!==root && r.target instanceof Element &&
      (r.target.contains(root) || r.target.closest('aside.app-shell-left-panel,aside[data-testid="app-shell-floating-left-panel"]')));
    if(root.isConnected && !relevant) return;
    if(relevant||!root.isConnected)schedule();
  });
  const timer = setInterval(() => {
    if (Date.now() - heartbeat > 90000) return dispose();
    render(); mount();
  }, 15000);
  function dispose() {
    disposed=true;clearInterval(timer); observer.disconnect();resize.disconnect();window.removeEventListener('resize',schedule);root.remove();
    delete window.__localCodexMeter;
  }
  window.__localCodexMeter = {
    version:'0.13.7',
    controllerId:'local-codex-sidebar-meter-v1',
    receive(value) { state = value; heartbeat = Date.now(); render(); mount(); },
    dispose,
    refreshLayout:schedule,
    layout() { return {mode:layoutMode,reason:layoutReason}; },
    mounted() { return root.isConnected; }
  };
  observer.observe(document.documentElement, {
    childList:true, subtree:true, attributes:true,
    attributeFilter:['class','style','hidden','aria-hidden','data-settings-panel-slug']
  });
  window.addEventListener('resize',schedule);
  render(); mount();
})();
