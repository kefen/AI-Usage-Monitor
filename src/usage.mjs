const count = value => Number.isSafeInteger(value) && value >= 0 ? value : null;
const dayMs=86400000;
const dateKey=value=>new Date(value).toISOString().slice(0,10);

export function normalizeUsage(result, now=Date.now()) {
  const today=dateKey(now), midnight=Date.parse(today+'T00:00:00Z');
  const monday=midnight-((new Date(midnight).getUTCDay()+6)%7)*dayMs;
  const daily=new Map();
  for(const bucket of Array.isArray(result?.dailyUsageBuckets)?result.dailyUsageBuckets:[]) {
    const key=bucket?.startDate, tokens=count(bucket?.tokens);
    if(typeof key!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(key)) continue;
    const stamp=Date.parse(key+'T00:00:00Z');
    if(!Number.isFinite(stamp)||dateKey(stamp)!==key||key>today) continue;
    // Repeated identical dates are harmless; conflicting rows are unknown.
    daily.set(key,daily.has(key)&&daily.get(key)!==tokens ? null : tokens);
  }
  const period=(start,end)=>{
    let sum=0, days=0;
    const expected=Math.round((end-start)/dayMs)+1;
    for(let stamp=start;stamp<=end;stamp+=dayMs) {
      const value=daily.get(dateKey(stamp));
      if(value!==undefined&&value!==null){sum+=value;days++;}
    }
    return {start:dateKey(start),end:dateKey(end),value:days?count(sum):null,days,expected,complete:days===expected};
  };
  const weeks=Array.from({length:5},(_,i)=>period(monday-i*7*dayMs,i?monday-(i-1)*7*dayMs-dayMs:midnight));
  const days=[...daily].filter(([,value])=>value!==null).sort(([a],[b])=>b.localeCompare(a)).slice(0,45).map(([date,value])=>({date,value}));
  return {fetchedAt:now,lifetime:count(result?.summary?.lifetimeTokens),today:period(midnight,midnight),daily:days,dailySelected:selectDailyUsage({daily:days},now),week:weeks[0],weeks,error:null};
}

export function selectDailyUsage(usage,now=Date.now()) {
  const today=dateKey(now),yesterday=dateKey(now-dayMs);
  const valid=(usage?.daily||[]).filter(d=>typeof d.date==='string' && /^\d{4}-\d{2}-\d{2}$/.test(d.date) && Number.isFinite(Date.parse(d.date)) && dateKey(Date.parse(d.date))===d.date && d.date<=today && count(d.value)!==null).sort((a,b)=>b.date.localeCompare(a.date));
  const selected=valid[0];
  return selected ? {...selected,relation:selected.date===today?'today':selected.date===yesterday?'yesterday':'latest'} : null;
}

export function observeAvailability(previous,usage,now=Date.now()) {
  const records=new Map();
  for(const row of Array.isArray(previous?.records)?previous.records:[]) {
    if(typeof row?.date!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(row.date))continue;
    const clean={date:row.date};
    for(const key of ['firstSeenAt','lastSeenAt','lastAbsentAt'])if(Number.isSafeInteger(row[key])&&row[key]>=0&&row[key]<=now)clean[key]=row[key];
    records.set(row.date,clean);
  }
  if(!usage?.error){
    const today=dateKey(now),returned=new Set();
    for(const day of usage?.daily||[]) {
      if(count(day.value)===null)continue;
      returned.add(day.date);
      const row=records.get(day.date)||{date:day.date};
      if(!row.firstSeenAt)row.firstSeenAt=now;
      row.lastSeenAt=now;records.set(day.date,row);
    }
    if(!returned.has(today)){
      const row=records.get(today)||{date:today};
      if(!row.firstSeenAt)row.lastAbsentAt=now;
      records.set(today,row);
    }
  }
  return {schema:1,lastCheckedAt:now,records:[...records.values()].sort((a,b)=>b.date.localeCompare(a.date)).slice(0,45)};
}
