import assert from 'node:assert/strict';
import {readFile,mkdir} from 'node:fs/promises';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE||'playwright');
const widget=await readFile(new URL('../src/widget.js',import.meta.url),'utf8');
const browser=await chromium.launch({headless:true,executablePath:process.env.TEST_BROWSER_PATH});
await mkdir(new URL('../verification/',import.meta.url),{recursive:true});
try{
  for(const scale of [1,1.25,1.5,2]){
    const page=await browser.newPage({viewport:{width:1000,height:900}});
    await page.setContent(`<style>*{box-sizing:border-box}body{margin:0;font:13px Arial}aside{height:100vh;width:52px}nav{height:100%;display:flex;flex-direction:column;align-items:center;padding:8px;gap:8px;width:52px}.top{flex:1;min-height:0}.bottom{flex:none}button{display:block;width:32px;height:32px;margin:2px 0}</style><aside class="app-shell-left-panel"><nav data-app-navigation-rail><div class="top"><button id="home">H</button></div><div class="bottom"><button id="account">A</button></div></nav></aside>`);
    await page.evaluate(scale=>{document.body.style.zoom=scale;document.querySelector('aside').style.height=`calc(100vh / ${scale})`;},scale);
    await page.evaluate(()=>{window.opens=0;window.__cqsOpenOverview=()=>window.opens++;const interval=window.setInterval;window.setInterval=(callback,ms)=>{window.meterTick=callback;return interval(callback,ms);};});
    await page.evaluate(widget);
    await page.evaluate(()=>window.__localCodexMeter.receive({fetchedAt:Date.now(),planBadge:'Pro',membership:{date:'2026-12-13'},buckets:[{id:'codex',windows:[{minutes:300,remaining:60},{minutes:10080,remaining:70,resetsAt:Date.now()/1000+9000}]}],usage:{fetchedAt:Date.now(),lifetime:1000,dailySelected:{date:new Date().toISOString().slice(0,10),value:100},week:{value:200,days:2}}}));
    const mode=()=>page.evaluate(()=>window.__localCodexMeter.layout().mode);
    const safe=async()=>assert.equal(await page.evaluate(()=>['home','account','update'].every(id=>{const e=document.getElementById(id);if(!e)return true;const r=e.getBoundingClientRect();const hit=document.elementFromPoint(r.x+r.width/2,r.y+r.height/2);return r.top>=0&&r.bottom<=innerHeight&&!!hit&&(hit===e||e.contains(hit));})),true,'official buttons must stay visible and clickable');
    await safe();
    await page.setViewportSize({width:1000,height:Math.round(300*scale)});
    await page.evaluate(()=>{const b=document.createElement('button');b.id='update';b.textContent='U';b.title='Restart to update';document.querySelector('.bottom').prepend(b);});
    await page.waitForTimeout(180);
    assert.equal(await mode(),'scroll');await safe();
    assert.equal(await page.locator('#local-codex-sidebar-meter section').evaluate(e=>e.scrollHeight>e.clientHeight),true);
    await page.setViewportSize({width:1000,height:Math.round(220*scale)});
    await page.waitForTimeout(180);assert.equal(await mode(),'compact');await safe();
    await page.locator('#local-codex-sidebar-meter button').click();
    assert.equal(await page.evaluate(()=>window.opens),1);
    await page.screenshot({path:new URL(`../verification/safety-${scale}.png`,import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1')});
    await page.setViewportSize({width:1000,height:Math.round(138*scale)});
    await page.waitForTimeout(180);assert.equal(await mode(),'hidden');await safe();
    await page.evaluate(()=>{const now=Date.now;Date.now=()=>now()+60001;window.meterTick();Date.now=now;});
    assert.equal(await page.locator('#local-codex-sidebar-meter').isVisible(),false,'minute refresh cannot reveal a hidden meter');await safe();
    await page.setViewportSize({width:1000,height:Math.round(900*scale)});
    await page.waitForTimeout(180);assert.equal(await mode(),'full');await safe();
    await page.evaluate(()=>{document.getElementById('update').style.cssText='position:absolute;top:120px;left:10px;height:400px';});
    await page.waitForTimeout(180);assert.equal(await mode(),'hidden','absolute official controls take priority');
    await page.evaluate(()=>document.getElementById('update').removeAttribute('style'));
    await page.waitForTimeout(180);assert.equal(await mode(),'full');
    await page.evaluate(()=>{window.frames=0;const raf=window.requestAnimationFrame;window.requestAnimationFrame=callback=>{window.frames++;return raf(callback);};});
    await page.waitForTimeout(300);assert.ok(await page.evaluate(()=>window.frames)<5,'no resize/mutation feedback loop at rest');
    await page.evaluate(()=>document.querySelector('nav').style.flexDirection='row');
    await page.waitForTimeout(180);assert.equal(await mode(),'hidden');
    await page.evaluate(()=>window.__localCodexMeter.dispose());
    assert.equal(await page.locator('#local-codex-sidebar-meter').count(),0);
    await page.close();console.log(`PASS safety zoom ${scale}`);
  }
}finally{await browser.close();}
