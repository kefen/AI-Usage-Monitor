const finite = x => typeof x === 'number' && Number.isFinite(x);

export function normalizeLimits(result, now = Date.now()) {
  const source = result?.rateLimitsByLimitId;
  const entries = source && typeof source === 'object' && !Array.isArray(source) && Object.keys(source).length
    ? Object.entries(source) : [['codex', result?.rateLimits]];
  const buckets = [];
  for (const [id, bucket] of entries) {
    if (!bucket || typeof bucket !== 'object') continue;
    const windows = [bucket.primary, bucket.secondary].filter(w =>
      w && finite(w.usedPercent) && w.usedPercent >= 0 && w.usedPercent <= 100 &&
      finite(w.windowDurationMins) && w.windowDurationMins > 0
    ).map(w => ({
      minutes: w.windowDurationMins,
      remaining: Math.round((100 - w.usedPercent) * 10) / 10,
      resetsAt: finite(w.resetsAt) && w.resetsAt > 0 ? w.resetsAt : null
    })).sort((a, b) => a.minutes - b.minutes);
    const credits=bucket.credits;
    const balance=typeof credits?.balance==='string' && /^\d+(\.\d+)?$/.test(credits.balance) && Number.isFinite(Number(credits.balance)) ? credits.balance : null;
    if (windows.length) buckets.push({ id: String(id).slice(0, 80), windows, credits:credits ? {balance,unlimited:credits.unlimited===true,hasCredits:credits.hasCredits===true}:null });
  }
  const resets=result?.rateLimitResetCredits?.availableCount;
  return { fetchedAt: now, buckets, resetCredits:Number.isSafeInteger(resets)&&resets>=0?resets:null, error: null };
}

export function freshness(state, now = Date.now()) {
  if (!Number.isFinite(state?.fetchedAt)) return 'unavailable';
  const age = now - state.fetchedAt;
  if (age > 900_000) return 'expired';
  return state.error || age > 180_000 ? 'stale' : 'fresh';
}

export function countdown(reset, nowSeconds = Date.now() / 1000) {
  if (!finite(reset)) return null;
  const minutes = Math.ceil((reset - nowSeconds) / 60);
  if (minutes <= 0) return 'pending';
  if (minutes < 60) return `${minutes}m`;
  if (minutes < 1440) return `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
  return `${Math.floor(minutes / 1440)}d ${Math.floor(minutes % 1440 / 60)}h`;
}

export function validateTarget(target, port) {
  try {
    const ws = new URL(target.webSocketDebuggerUrl);
    const page = new URL(target.url);
    const localSocket = ws.protocol === 'ws:' && ws.hostname === '127.0.0.1' &&
      Number(ws.port) === Number(port) && !ws.username && !ws.password && ws.pathname.startsWith('/devtools/page/');
    const appPage = ['codex:', 'app:'].includes(page.protocol) ||
      (page.protocol === 'file:' && /\/webview\/index\.html$/i.test(page.pathname)) ||
      (page.protocol === 'https:' && page.hostname === 'chatgpt.com');
    return target.type === 'page' && localSocket && appPage;
  } catch { return false; }
}
