import assert from 'node:assert/strict';
import {readFile,mkdir} from 'node:fs/promises';
import {createRequire} from 'node:module';
const {chromium}=createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE||'playwright');
const scripts=await Promise.all(['source.js','content.js'].map(name=>readFile(new URL('../'+name,import.meta.url),'utf8')));
const icon='data:image/png;base64,'+(await readFile(new URL('../icon-32.png',import.meta.url))).toString('base64');
const browser=await chromium.launch({headless:true,executablePath:process.env.TEST_BROWSER_PATH});
await mkdir(new URL('../../verification/browser-web',import.meta.url),{recursive:true});
const fixture=(lang='en')=>`<!doctype html><html lang="${lang}"><style>*{box-sizing:border-box}body{margin:0;font:14px system-ui;background:#f8f9fb;color:#252b35}.layout{display:flex;height:100vh}#app-shell-sidebar{width:340px;max-width:100vw;display:flex;flex-shrink:0}.rail{width:52px;display:flex;flex-direction:column;justify-content:space-between;background:#eceef2;flex-shrink:0}.secondary{display:flex;flex-direction:column;flex:1;min-width:0;overflow:hidden}.official{display:flex;flex:1;min-height:0;overflow:auto;flex-direction:column;background:white;padding:12px}.official a{display:block;padding:10px 0}.official button{margin-top:auto}.main{padding:30px;flex:1;min-width:0}button{cursor:pointer}#usage-menu{position:fixed;bottom:80px;left:50px;background:white;border:1px solid #ccc;padding:15px;z-index:100}h1{font-size:24px}</style><div class="layout"><aside id="app-shell-sidebar"><nav class="rail" data-app-navigation-rail="true"><div>Home</div><div><button aria-label="Usage" aria-description="Weekly usage: 30% left" aria-expanded="false" id="usage-trigger">Usage</button><button aria-label="Open profile menu">Profile</button></div></nav><div class="secondary"><nav class="official"><strong>ChatGPT</strong><a href="#">New chat</a><a href="#">Projects</a><a href="#">Recent conversations</a><button id="official-bottom">Official controls</button></nav></div></aside><main class="main"><h1>ChatGPT workspace</h1><p>Synthetic data. Not a real account.</p><div id="private-chat">Private chat sentinel</div></main></div><div id="portal"></div>`;
async function setup(page,language){
 await page.route('https://chatgpt.com/**',route=>route.fulfill({contentType:'text/html',body:fixture(language)}));
 await page.goto('https://chatgpt.com/');
 await page.evaluate(({language,icon})=>{
   globalThis.savedPrefs=[];
   globalThis.chrome={runtime:{id:'test-extension',getURL:()=>icon,getManifest:()=>({version:'0.5.2'}),onMessage:{addListener(){}}},storage:{local:{get:async()=>({cqsWebPreferences:{language}}),set:async obj=>{savedPrefs.push(obj);}}}};
   document.getElementById('usage-trigger').addEventListener('click',()=>{
    const trigger=document.getElementById('usage-trigger'),open=trigger.getAttribute('aria-expanded')==='true';trigger.setAttribute('aria-expanded',String(!open));
    document.getElementById('portal').innerHTML=open?'':'<div id="usage-menu" role="menu" aria-labelledby="usage-trigger"><div>Usage source: Your Pro plan</div><div role="menuitem">Weekly limit 30% left</div><div><div>额度</div><div>额度：<span>163.9</span></div></div></div>';
   });
   const privateNode=document.getElementById('private-chat');for(const key of ['innerText','textContent'])Object.defineProperty(privateNode,key,{get(){throw Error('Private chat was inspected');}});
 },{language,icon});
 for(const code of scripts)await page.addScriptTag({content:code});
 await page.locator('#cqs-web-usage-preview [data-metric=credits] dd').filter({hasText:'163'}).waitFor();
}
try{
 for(const language of ['en','zh-CN','zh-TW'])for(const width of [1280,760,360]){
  const page=await browser.newPage({viewport:{width,height:800},locale:language});await setup(page,language);
  const host=page.locator('#cqs-web-usage-preview');
  assert.equal(await host.locator('[data-metric=week] dd').innerText(),'30%');
  assert.equal(await host.locator('.history .hint').innerText(),{en:'Not provided by this page','zh-CN':'此网页未提供','zh-TW':'此網頁未提供'}[language]);
  assert.equal(await page.locator('[role=menu]').count(),0,'own usage probe must restore the menu');
  assert.equal(await host.evaluate(el=>el.parentElement.className),'secondary');
  assert.ok(await host.locator('img').evaluate(img=>img.complete&&img.naturalWidth===32),'brand image did not render');
  assert.equal(await host.evaluate(el=>el.shadowRoot.querySelector('details').scrollWidth>el.clientWidth),false,'horizontal overflow');
  const bounds=await host.boundingBox(),official=await page.locator('.official').boundingBox();assert.ok(official.y+official.height<=bounds.y+1,'official navigation overlaps the tool');assert.ok(official.height>=200);
  assert.equal(await host.locator('details').evaluate(el=>el.scrollHeight>el.clientHeight+1),false,'default overview needs a scrollbar');
  const buttons=host.locator('.tools button');await buttons.last().click();
  assert.equal(await host.locator('input[type=checkbox]:disabled').count(),3);
  const week=host.locator('input[data-field=week]');await week.uncheck();await host.locator('section:not([hidden]) .tools button').click();
  assert.equal(await host.locator('[data-metric=week]').count(),0,'display setting did not apply');
  assert.equal(await page.evaluate(()=>savedPrefs.at(-1).cqsWebPreferences.choices.week),false);
  await buttons.last().click();await host.locator('input[data-field=week]').check();await host.locator('section:not([hidden]) .tools button').click();
  await page.getByRole('button',{name:'Open profile menu',exact:true}).click();
  assert.equal(await host.locator('[data-metric=week] dd').innerText(),'--','previous account quota leaked');
  await buttons.first().click();await host.locator('[data-metric=week] dd').filter({hasText:'30%'}).waitFor();
  await page.screenshot({path:new URL('../../verification/browser-web/'+language+'-'+width+'.png',import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1'),fullPage:true});
  // A user-owned menu must remain open after a manual refresh.
  await page.getByRole('button',{name:'Usage',exact:true}).click();await buttons.first().click();assert.equal(await page.locator('[role=menu]').count(),1);
  await page.close();
 }
 // Current settings overview is a separate strict source; historical analytics is not.
 const page=await browser.newPage();await setup(page,'en');
 const overview=`<div><h1>Usage</h1><div>ChatGPT Pro 100</div><div><div>Weekly limit</div><span>Resets in 3 days</span><div><progress max="100" value="30" aria-label="Remaining usage"></progress></div></div><div id="usage-limit-resets" role="group"></div><div role="tablist"><button role="tab">Available 3</button></div><div>Credits 163 credits</div></div>`;
 await page.evaluate(html=>{document.querySelector('main').innerHTML=html;history.pushState({},'', '/settings/usage?tab=overview');},overview);
 const collected=await page.evaluate(()=>CQSWebSource.parse(CQSWebSource.collect(document,location.pathname,location.search)));
 assert.equal(collected.plan,'Pro 100');assert.equal(collected.resets,3);assert.equal(collected.reset,'Resets in 3 days');
 assert.equal(await page.evaluate(()=>CQSWebSource.parse(CQSWebSource.collect(document,'/settings/usage','?tab=analytics')).resets),null);
 await page.evaluate(()=>window.dispatchEvent(new PopStateEvent('popstate')));
 await page.locator('[data-metric=resets] dd').filter({hasText:'3'}).waitFor();
 await page.locator('#cqs-web-usage-preview').screenshot({path:new URL('../../docs/screenshots/chrome-web-052.png',import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1')});
 await page.evaluate(()=>{document.querySelector('progress').value=37;document.querySelector('#usage-trigger').setAttribute('aria-description','Weekly usage: 37% left');});
 await page.locator('[data-metric=week] dd').filter({hasText:'37%'}).waitFor({timeout:2000});
 await page.close();
 console.log('PASS: three locales, three widths, working saved choices, account invalidation, popup ownership, current-overview-only fields and no chat inspection');
}finally{await browser.close();}
