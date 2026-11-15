import { readFile } from 'node:fs/promises';

export function nextUsageRefresh(now=Date.now()) {
  return now+3600000;
}

export function normalizeMembership(value) {
  if(value?.enabled===false)return null;
  if(value?.annualEstimate===true && !value.date && value.purchaseDate) value={...value,date:nextAnnualDate(value.purchaseDate),estimated:true};
  if(value?.monthlyEstimate===true && !value.date && value.purchaseDate) value={...value,date:nextMonthlyDate(value.purchaseDate),estimated:true};
  if(!['renewal','expiry'].includes(value?.kind) || typeof value?.date!=='string' || !/^\d{4}-\d{2}-\d{2}$/.test(value.date)) return null;
  const stamp=Date.parse(value.date+'T00:00:00Z');
  if(!Number.isFinite(stamp)||new Date(stamp).toISOString().slice(0,10)!==value.date) return null;
  return {date:value.date,kind:value.kind,estimated:value.estimated===true};
}

export function nextMonthlyDate(value) {
  if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value))return null;
  const date=new Date(value+'T00:00:00Z');
  if(!Number.isFinite(date.getTime())||date.toISOString().slice(0,10)!==value)return null;
  const day=date.getUTCDate();date.setUTCDate(1);date.setUTCMonth(date.getUTCMonth()+1);
  const end=new Date(Date.UTC(date.getUTCFullYear(),date.getUTCMonth()+1,0)).getUTCDate();
  date.setUTCDate(Math.min(day,end));return date.toISOString().slice(0,10);
}

export async function readMembership(path) {
  try {return normalizeMembership(JSON.parse(await readFile(path,'utf8')));} catch {return null;}
}
export function nextAnnualDate(value){
  const first=nextMonthlyDate(value);if(!first)return null;
  const date=new Date(value+'T00:00:00Z'),year=date.getUTCFullYear()+1,month=date.getUTCMonth();
  return new Date(Date.UTC(year,month,Math.min(date.getUTCDate(),new Date(Date.UTC(year,month+1,0)).getUTCDate()))).toISOString().slice(0,10);
}
