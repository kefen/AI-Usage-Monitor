import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const {chromium}=createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE||'playwright');
const browser=await chromium.launch({headless:true,executablePath:process.env.TEST_BROWSER_PATH});
try{
  for(const width of [320,480])for(const mode of ['ok','stale','missing']){
    const page=await browser.newPage({viewport:{width,height:720}});
    await page.addInitScript(mode=>{window.chrome={runtime:{id:'a'.repeat(32),sendNativeMessage:async(name,payload)=>{
      if(name!=='org.kefen.codex_quota_sidebar'||JSON.stringify(payload)!=='{"op":"read"}')throw Error('Invalid request');
      if(mode==='missing')throw Error('No host');
      if(mode==='stale')return {ok:false,code:'STALE'};
      return {ok:true,windows:[{minutes:300,remaining:75}],daily:{date:'2026-11-14',value:0},week:1234567,lifetime:987654321,quotaAt:Date.now(),usageAt:Date.now()};
    }}};},mode);
    await page.goto(new URL('../browser/panel.html',import.meta.url).href);
    await page.waitForTimeout(200);
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'No horizontal overflow');
    if(mode==='ok'){assert.ok((await page.locator('#metrics').innerText()).includes('75%'));assert.ok((await page.locator('#metrics').innerText()).includes('2026-11-14'));}
    else assert.equal(await page.locator('#metrics').innerText(),'');
    assert.equal(await page.locator('#refresh').isDisabled(),true,'Refresh throttled');
    for(const [locale,heading] of [['zh-CN','用量概览'],['zh-TW','用量概覽'],['en','Usage overview']]){
      await page.locator('#language').selectOption(locale);
      assert.equal(await page.locator('h1').innerText(),heading);
      assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'Localized layout overflow');
      if(mode==='ok')assert.ok((await page.locator('#metrics').innerText()).includes('75%'));
    }
    await page.screenshot({path:fileURLToPath(new URL(`../verification/browser-${width}-${mode}.png`,import.meta.url))});
    await page.close();
  }
  console.log('PASS: browser panel mocked bridge, 320/480 widths, fresh/stale/missing states, cooldown; not live registration acceptance');
}finally{await browser.close();}
