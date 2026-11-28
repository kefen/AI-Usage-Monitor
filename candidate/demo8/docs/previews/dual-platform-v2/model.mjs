export const DEMO_VERSION='0.16.17';
export const SAMPLE_PREFIX='aum-demo8-sample-';
export const SAMPLE_DATE='2026-11-22';
export const SAMPLE_PROFILES={dual:{scenario:'normal'},codex:{scenario:'normal'},claude:{scenario:'normal'},low:{scenario:'low'},zero:{scenario:'exhausted'},stale:{scenario:'stale'},partial:{scenario:'normal'},pending:{scenario:'normal'},api:{scenario:'api'},ultra:{scenario:'shortUnlimited'},legacy:{scenario:'normal'}};
export const SCENARIOS=['normal','missing','stale','low','api','exhausted','shortMissing','weekMissing','shortUnlimited'];
export const PLAN_CHOICES={
  codex:['Unknown','Free','Go','Plus','Pro','Business','Enterprise','Other'],
  claude:['Unknown','Free','Pro','Max','Ultra','Team','Enterprise','Other']
};
export function planModes(id,plan){
  if(plan==='Free'||plan==='Unknown')return ['manual'];
  if((id==='codex'&&['Go','Plus','Pro'].includes(plan))||(id==='claude'&&['Max','Ultra'].includes(plan)))return ['monthly','manual'];
  return ['monthly','annual','manual'];
}
const blankPlan=()=>({plan:'Unknown',tier:'',purchase:'',mode:'manual',date:'',kind:'renewal'});
export function samplePrefs(id='dual',saved){
  if(saved)return createPrefs(saved);
  const p=createPrefs();
  p.connections.codex={status:'sample',embed:true,hostState:'sample'};
  p.connections.claude={status:'sample',embed:false,hostState:'pending'};
  p.access={codex:'account',claude:'account'};
  p.plans.codex={...blankPlan(),plan:'Pro',tier:'Pro 100',purchase:'2026-11-13',mode:'monthly'};
  p.plans.claude={...blankPlan(),plan:'Max',purchase:'2026-11-08',mode:'monthly'};
  if(id==='codex')p.platforms.claude=false;
  if(id==='claude')p.platforms.codex=false;
  for(const provider of id==='pending'?['codex','claude']:id==='partial'?['claude']:[]){
    p.connections[provider]={status:'pending',embed:false,hostState:'pending'};
    p.plans[provider]=blankPlan();p.access[provider]='unknown';
  }
  if(id==='api'){p.plans.claude=blankPlan();p.access.claude='api';}
  if(id==='ultra')p.plans.claude.plan='Ultra';
  if(id==='legacy')p.plans.claude={...blankPlan(),plan:'Max',tier:'20x',purchase:'2026-09-30',mode:'monthly'};
  return p;
}
export function segmentFills(value,count=20){
  const percentage=Number.isFinite(value)?Math.max(0,Math.min(100,value)):0;
  return Array.from({length:count},(_,i)=>Math.max(0,Math.min(100,percentage*count-i*100)));
}
export const FIELD_CATALOG={
  codex:['plan','short','week','reset','resetCredits','renewal','credits','daily','average','weekly','monthly','lifetime'],
  claude:['model','context','short','week','reset','plan','renewal','sessionTokens','sessionCost']
};
const surfaces=['host','quick','workspace'];
const defaults={
  codex:{host:FIELD_CATALOG.codex,quick:['short','week','reset','plan','renewal'],workspace:FIELD_CATALOG.codex},
  claude:{host:['model','context','short','week'],quick:['short','week','reset','model','context'],workspace:FIELD_CATALOG.claude}
};
export function createPrefs(saved={}){
  const result={platforms:{codex:true,claude:true},language:'system',theme:'system',reduceTransparency:false,alerts:{enabled:false,threshold:20},connections:{codex:{status:'pending',embed:false,hostState:'pending'},claude:{status:'pending',embed:false,hostState:'pending'}},fields:{},access:{codex:'unknown',claude:'unknown'},plans:{
    codex:blankPlan(),claude:blankPlan()
  }};
  if(!saved||typeof saved!=='object')saved={};
  result.directCodex=saved.directCodex===true;
  const bounded=(v,min,max,fallback)=>Number.isFinite(v)?Math.max(min,Math.min(max,v)):fallback;
  result.glass={transparency:bounded(saved.glass?.transparency,0,100,70),blur:bounded(saved.glass?.blur,12,40,24)};
  if(['system','zh-CN','zh-TW','en'].includes(saved.language))result.language=saved.language;
  if(['system','light','dark'].includes(saved.theme))result.theme=saved.theme;
  result.reduceTransparency=saved.reduceTransparency===true;
  result.alerts.enabled=saved.alerts?.enabled===true;
  result.alerts.threshold=Math.max(5,Math.min(50,Number(saved.alerts?.threshold)||20));
  for(const id of ['codex','claude']){
    if(typeof saved.platforms?.[id]==='boolean')result.platforms[id]=saved.platforms[id];
    const connection=saved.connections?.[id];
    if(connection&&['sample','pending','error'].includes(connection.status))result.connections[id]={status:connection.status,embed:connection.embed===true,hostState:connection.hostState==='sample'?'sample':'pending'};
    if(typeof connection?.readChoice==='boolean')result.connections[id].readChoice=connection.readChoice;
    if(['unknown','account','api'].includes(saved.access?.[id]))result.access[id]=saved.access[id];
    result.fields[id]={};
    for(const surface of surfaces){
      const fields=saved.fields?.[id]?.[surface];
      result.fields[id][surface]=Array.isArray(fields)?[...new Set(fields.filter(f=>FIELD_CATALOG[id].includes(f)))]:[...defaults[id][surface]];
    }
    const plan=saved.plans?.[id];
    if(plan&&typeof plan==='object'){
      if(plan.plan==='API')result.access[id]='api';
      else if(typeof plan.plan==='string'&&plan.plan.trim())result.plans[id].plan=plan.plan.trim().slice(0,80);
      if(typeof plan.tier==='string')result.plans[id].tier=plan.tier.slice(0,40);
      for(const key of ['purchase','date'])if(typeof plan[key]==='string'&&(plan[key]===''||validDate(plan[key])))result.plans[id][key]=plan[key];
      if(['monthly','annual','manual'].includes(plan.mode))result.plans[id].mode=plan.mode;
      if(['renewal','expiry'].includes(plan.kind))result.plans[id].kind=plan.kind;
      if(plan.show===false)for(const surface of surfaces)result.fields[id][surface]=result.fields[id][surface].filter(f=>f!=='renewal');
    }
  }
  return result;
}
export const enabledIds=p=>['codex','claude'].filter(id=>p.platforms[id]);
export const launcherItems=enabledIds;
export function resolveLocale(preference,system='en'){
  if(preference!=='system')return ['zh-CN','zh-TW','en'].includes(preference)?preference:'en';
  return /^zh-(TW|HK|MO|Hant)/i.test(system)?'zh-TW':/^zh/i.test(system)?'zh-CN':'en';
}
export const fieldsFor=(p,id,surface)=>p.fields[id][surface];
function validDate(value){
  if(!/^\d{4}-\d{2}-\d{2}$/.test(value))return false;
  const date=new Date(value+'T00:00:00Z');return !Number.isNaN(+date)&&date.toISOString().slice(0,10)===value;
}
export function renewalDate(plan){
  if(plan.mode==='manual')return validDate(plan.date)?plan.date:null;
  if(!['monthly','annual'].includes(plan.mode)||!validDate(plan.purchase))return null;
  const original=new Date(plan.purchase+'T00:00:00Z');
  const target=new Date(Date.UTC(original.getUTCFullYear()+(plan.mode==='annual'?1:0),original.getUTCMonth()+(plan.mode==='monthly'?1:0),1));
  const lastDay=new Date(Date.UTC(target.getUTCFullYear(),target.getUTCMonth()+1,0)).getUTCDate();
  target.setUTCDate(Math.min(original.getUTCDate(),lastDay));return target.toISOString().slice(0,10);
}
export function validPlanChronology(plan){
  if(plan.purchase&&!validDate(plan.purchase)||plan.mode==='manual'&&plan.date&&!validDate(plan.date))return false;
  const next=renewalDate(plan);
  return !(plan.purchase&&next&&next<plan.purchase);
}
export function readings(id,scenario='normal'){
  const missing=scenario==='api'||id==='claude'&&scenario==='missing';
  const shortUnlimited=id==='claude'&&scenario==='shortUnlimited';
  const remainingHours=id==='codex'?79:98;
  return {id,week:missing||scenario==='weekMissing'?null:scenario==='exhausted'?0:scenario==='low'?(id==='codex'?12:8):(id==='codex'?62:34),short:missing||shortUnlimited||scenario==='shortMissing'?null:id==='codex'?78:91,shortUnlimited,remainingHours,shortMinutes:id==='codex'?102:196,elapsed:Math.round((1-remainingHours/168)*100),stale:scenario==='stale',missing,activityAvailable:!(id==='claude'&&scenario==='missing'),quotaReason:scenario==='api'?'subscriptionUnavailable':'windowUnavailable'};
}
export function pace(d){if(d.missing||d.stale||d.week===null||!Number.isFinite(d.elapsed))return null;const delta=100-d.week-d.elapsed;return delta>5?'fast':delta< -5?'slow':'steady';}
const weeklySamples={codex:[72.4,104.8,0,96.2,181.5,113.6,142.6],claude:[12.5,28.1,8.4,36.8,22.1,41.3,36.2]};
export function tokenHistory(id,days=30){const week=weeklySamples[id],full=[...Array.from({length:23},(_,i)=>Math.round(week[i%7]*(.6+(i%5)*.12)*10)/10),...week];return full.slice(-days);}
export function tokenMetrics(id){const history=tokenHistory(id),monthly=history.slice(8).reduce((a,b)=>a+b,0);return {daily:history.at(-2),today:history.at(-1),weekly:history.slice(-7).reduce((a,b)=>a+b,0),monthly,average:monthly/22,lifetime:id==='codex'?4840:620};}

export function observedActivity(codex,claude,ids){
  const events=[];
  if(ids.includes('codex')&&/^\d{4}-\d{2}-\d{2}$/.test(codex?.date)&&Array.isArray(codex.days)){
    const month=codex.date.slice(0,7);
    codex.days.forEach((value,index)=>{
      if(Number.isFinite(value)&&value>=0)events.push({id:'codex',when:month+'-'+String(index+1).padStart(2,'0'),
        tokens:Math.round(value*1000000),evidence:'daily-local-total'});
    });
  }
  if(ids.includes('claude')&&Number.isSafeInteger(claude?.observedAt)&&Number.isSafeInteger(claude.sessionTokens)){
    const observed=new Date(claude.observedAt);
    if(Number.isFinite(+observed))events.push({id:'claude',when:observed.toISOString(),tokens:claude.sessionTokens,evidence:'experimental-request'});
  }
  return events.sort((a,b)=>b.when.localeCompare(a.when));
}

const desktopBackupFormat='aum-desktop-settings-v1';
export function desktopBackup(prefs){
  const {connections,...saved}=createPrefs(prefs);
  return {format:desktopBackupFormat,prefs:saved};
}
export function restoreDesktopBackup(envelope,current){
  if(envelope?.format!==desktopBackupFormat||!envelope.prefs||Array.isArray(envelope.prefs))
    throw new Error('E_DESKTOP_BACKUP_FORMAT');
  const source=envelope.prefs;
  for(const id of ['codex','claude']){
    if(typeof source.platforms?.[id]!=='boolean'||typeof source.plans?.[id]?.plan!=='string'||
       !['host','quick','workspace'].every(scope=>Array.isArray(source.fields?.[id]?.[scope])))
      throw new Error('E_DESKTOP_BACKUP_FIELDS');
  }
  const restored=createPrefs(source);
  if(!Object.values(restored.plans).every(validPlanChronology))throw new Error('E_DESKTOP_BACKUP_DATES');
  restored.connections=createPrefs(current).connections;
  return restored;
}
export function desktopDiagnostics(os,collector,hasCodex,hasClaude){
  const phases=['unknown','attached','quota-unavailable','sidebar-missing','waiting','failed','stopped','stale'];
  return {format:'aum-desktop-diagnostics-v1',version:DEMO_VERSION,platform:os==='win'?'windows':'macos',
    codex:{collector:phases.includes(collector)?collector:'unknown',readings:hasCodex===true},
    claude:{experimental:true,readings:hasClaude===true,accountVerified:false}};
}
export const SIDEBAR_REPORT_LIFETIME_MS=90000;
export function sidebarReportState(report,now=Date.now()){
  if(!report)return null;
  if(['error','no-report'].includes(report.state))return report.state;
  if(!Number.isFinite(report.updatedAt)||report.updatedAt>now)return 'unverified';
  return now-report.updatedAt>SIDEBAR_REPORT_LIFETIME_MS?'stale':report.state;
}
