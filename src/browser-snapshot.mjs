const numeric=x=>Number.isFinite(x)&&x>=0?x:null;
const count=x=>Number.isSafeInteger(x)&&x>=0?x:null;
export function browserSnapshot(state,usage,now=Date.now(),display={}){
  const fresh=numeric(state?.fetchedAt)!==null&&now-state.fetchedAt>=0&&now-state.fetchedAt<180000&&!state.error;
  const usageFresh=numeric(usage?.fetchedAt)!==null&&now-usage.fetchedAt>=0&&now-usage.fetchedAt<5400000&&!usage.error;
  const creditBuckets=(state?.buckets||[]).filter(b=>b.credits);
  const balance=creditBuckets.length===1?creditBuckets[0].credits.balance:null;
  const renewal=normalizeMembership({enabled:true,kind:'renewal',date:display.renewalDate});
  return {schema:1,author:'KEFEN',generatedAt:now,quotaAt:numeric(state?.fetchedAt),usageAt:numeric(usage?.fetchedAt),
    visible:normalizeDisplay(display.visible),planBadge:['Free','Go','Plus','Pro','Biz','Ent','Edu','Other'].includes(display.planBadge)?display.planBadge:'?',renewalDate:renewal?.date||null,planSource:['desktop','manual'].includes(display.planSource)?display.planSource:'unknown',
    windows:fresh?(state.buckets||[]).slice(0,8).flatMap(b=>(b.windows||[]).slice(0,4).filter(w=>numeric(w.minutes)!==null&&numeric(w.remaining)!==null&&w.remaining<=100).map(w=>({minutes:w.minutes,remaining:w.remaining,resetsAt:numeric(w.resetsAt)}))):[],
    lifetime:usageFresh?count(usage.lifetime):null,week:usageFresh?count(usage.week?.value):null,
    monthAverage:usageFresh&&usage.month?.start===new Date(now).toISOString().slice(0,7)+'-01'?count(usage.month?.average):null,
    creditBalance:fresh&&typeof balance==='string'&&/^\d+(\.\d+)?$/.test(balance)?balance:null,resetCredits:fresh?count(state.resetCredits):null,
    daily:usageFresh&&/^\d{4}-\d{2}-\d{2}$/.test(usage.dailySelected?.date)&&count(usage.dailySelected?.value)!==null?{date:usage.dailySelected.date,value:usage.dailySelected.value}:null};
}
import {normalizeDisplay} from './display-settings.mjs';
import {normalizeMembership} from './settings.mjs';
