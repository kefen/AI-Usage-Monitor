import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {mkdir,readFile} from 'node:fs/promises';
const {version}=JSON.parse(await readFile(new URL('../browser/manifest.json',import.meta.url),'utf8'));
const {chromium}=createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE||'playwright');
const out=new URL('../verification/v3-browser/',import.meta.url);
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,executablePath:process.env.TEST_BROWSER_PATH});
const errors=[];
try{
 for(const width of [320,390,480])for(const locale of ['en','zh-CN','zh-TW'])for(const mode of ['full','partial','empty','stale','offline']){
  const page=await browser.newPage({viewport:{width,height:900}});
  page.on('pageerror',error=>errors.push(error.message));
  await page.addInitScript(({locale,mode,version})=>{
   localStorage.setItem('cqs-language',locale);localStorage.setItem('cqs-visible',JSON.stringify({'5-hour remaining':false}));
   window.bridgeCalls=[];window.fixtureMode=mode;
   window.chrome={runtime:{id:'a'.repeat(32),getManifest:()=>({version}),sendNativeMessage:async(name,payload)=>{
    window.bridgeCalls.push(payload);if(name!=='org.kefen.codex_quota_sidebar'||JSON.stringify(payload)!=='{"op":"read"}')throw Error('Not read-only');
    const mode=window.fixtureMode;if(mode==='offline')throw Error('No helper');
    const now=Date.now(),metadata={visible:Object.fromEntries(['plan','short','week','reset','renewal','daily','average','weekly','lifetime','credits','resetCredits'].map(k=>[k,mode!=='none'&&!(mode==='selected'&&['short','daily','plan'].includes(k))])),planBadge:'Pro',renewalDate:'2026-12-13',planSource:'manual'};
    if(mode==='stale')return {...metadata,ok:false,code:'STALE'};
    if(mode==='empty'||mode==='none')return {...metadata,ok:true,generatedAt:now,quotaAt:now,usageAt:now,windows:[]};
    const today=new Date(),day=today.getFullYear()+'-'+String(today.getMonth()+1).padStart(2,'0')+'-'+String(today.getDate()).padStart(2,'0');
    return {...metadata,ok:true,generatedAt:now,windows:[...(mode==='partial'?[]:[{minutes:300,remaining:mode==='today'?0:62}]),{minutes:10080,remaining:37,resetsAt:1795168800}],daily:{date:mode==='today'?day:'2026-11-16',value:mode==='today'?0:202650000},monthAverage:125350000,week:mode==='partial'?null:96900000,lifetime:3010000000,creditBalance:'162.8117935',resetCredits:0,quotaAt:mode==='aged'?now-180000:now,usageAt:mode==='aged'?now-5400000:now};
   }}};
  },{locale,mode,version});
  await page.route('https://api.github.com/**',route=>route.fulfill({json:[{tag_name:'chrome/v99.0.0',body:'## English\n1. English release note\n## 简体中文\n1. 简体更新说明\n## 繁體中文\n1. 繁體更新說明'}]}));
  await page.goto(new URL('../browser/panel.html',import.meta.url).href);
  await page.waitForFunction(()=>window.bridgeCalls.length>0&&document.querySelector('[data-metric]'));
  assert.equal(await page.locator('[data-metric]').count(),11);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'No horizontal overflow');
  assert.equal(await page.locator('input[type=checkbox]').count(),0,'No independent display preferences');
  assert.equal(await page.locator('.quota-pair .track').count(),2);
  assert.equal(await page.locator('.usage-table tbody tr').count(),4);
  assert.equal(await page.evaluate(()=>[...document.querySelectorAll('body *')].filter(el=>el.scrollHeight>el.clientHeight+1&&['auto','scroll'].includes(getComputedStyle(el).overflowY)).length),0,'Only document scrolls');
  assert.ok(await page.locator('#version').innerText());
  if(['full','partial'].includes(mode)){
   assert.ok((await page.locator('[data-metric=resetCredits]').innerText()).includes('0'));
   assert.ok((await page.locator('[data-metric=daily]').innerText()).includes('202.65M'));
   assert.ok((await page.locator('[data-metric=plan]').innerText()).includes('Pro'));
   assert.ok((await page.locator('[data-metric=short]').innerText()).includes(mode==='full'?'62%':'--'));
  }else assert.ok((await page.locator('[data-metric=short]').innerText()).includes('--'));
  await page.screenshot({path:fileURLToPath(new URL(`${locale}-${width}-${mode}.png`,out)),fullPage:true});
  if(width===390&&mode==='full'){
   if(locale==='en'){
    await page.evaluate(()=>{window.fixtureMode='today';document.dispatchEvent(new Event('visibilitychange'));});
    await page.waitForFunction(()=>document.querySelector('[data-metric=daily]').textContent.includes('Today tokens'));
    assert.ok((await page.locator('[data-metric=daily]').innerText()).includes('0'));
    assert.equal(await page.locator('[data-metric=short] [role=progressbar]').getAttribute('aria-valuenow'),'0');
    await page.evaluate(()=>{window.fixtureMode='aged';document.dispatchEvent(new Event('visibilitychange'));});
    await page.waitForFunction(()=>document.querySelector('[data-metric=daily]').textContent.includes('Data expired'));
    assert.ok((await page.locator('[data-metric=short]').innerText()).includes('--'));
    await page.evaluate(()=>{window.fixtureMode='full';document.dispatchEvent(new Event('visibilitychange'));});
   }
   await page.locator('#display-settings').click();
   assert.ok(await page.locator('#settings-feedback').innerText());
   assert.ok((await page.evaluate(()=>window.bridgeCalls)).every(c=>c.op==='read'));
   await page.locator('#check-updates').click();
   await page.locator('#update-status a').waitFor();
   assert.ok((await page.locator('#update-status').innerText()).includes('chrome://extensions'));
   assert.ok((await page.locator('#update-status').innerText()).includes(locale==='en'?'English release note':locale==='zh-CN'?'简体更新说明':'繁體更新說明'));
   await page.evaluate(()=>{window.fixtureMode='selected';});
   await page.waitForFunction(()=>!document.querySelector('[data-metric=short]'),{},{timeout:8000});
   assert.equal(await page.locator('[data-metric]').count(),8,'Shared settings applied on next read');
   await page.evaluate(()=>{window.fixtureMode='none';});
   await page.waitForFunction(()=>document.querySelector('#empty-selection'),{},{timeout:8000});
   assert.equal(await page.locator('[data-metric]').count(),0);
  }
  await page.close();
 }
 assert.deepEqual(errors,[]);
 console.log('PASS: 45 browser screenshots; 320/390/480, three locales, full/partial/empty/stale/offline; shared choices, zero, read-only settings fallback, localized updates + explicit reload. Mock bridge, not live Chrome registration.');
}finally{await browser.close();}
