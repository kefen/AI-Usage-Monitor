import assert from 'node:assert/strict';
import {mkdir,mkdtemp} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
const {chromium}=createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE||'playwright');
const root=fileURLToPath(new URL('../',import.meta.url)),out=fileURLToPath(new URL('../../verification/browser-web/',import.meta.url));
await mkdir(out,{recursive:true});
const profile=await mkdtemp(join(tmpdir(),'cqs-web-'));
const context=await chromium.launchPersistentContext(profile,{
 headless:true,executablePath:process.env.TEST_BROWSER_PATH,ignoreDefaultArgs:['--disable-extensions'],
 args:['--disable-extensions-except='+root,'--load-extension='+root],viewport:{width:1280,height:800}
});
try{
 const worker=context.serviceWorkers()[0]||await context.waitForEvent('serviceworker',{timeout:10000});
 const manifest=await worker.evaluate(()=>chrome.runtime.getManifest());assert.equal(manifest.version,'0.5.2');assert.deepEqual(manifest.permissions,['storage','alarms']);assert.equal(manifest.host_permissions,undefined);
 await worker.evaluate(()=>chrome.storage.local.set({cqsWebPreferences:{language:'en',choices:{week:true,plan:true,credits:true,resets:true,reset:true}}}));
 await context.route('https://chatgpt.com/**',route=>route.fulfill({contentType:'text/html; charset=utf-8',body:`<!doctype html><style>*{box-sizing:border-box}body{margin:0;font:14px system-ui}.layout{display:flex;height:100vh}#app-shell-sidebar{display:flex;width:340px}.rail{display:flex;flex-direction:column;justify-content:space-between;width:52px;flex-shrink:0;background:#eee}.secondary{display:flex;flex-direction:column;min-width:0;flex:1;overflow:hidden}.official{min-height:0;flex:1;overflow:auto;padding:14px}main{padding:32px}#portal>[role=menu]{position:fixed;left:52px;bottom:70px;padding:20px;background:white;border:1px solid #aaa}</style><div class="layout"><aside id="app-shell-sidebar"><nav class="rail" data-app-navigation-rail="true"><span>Home</span><div><button id="official-usage" aria-label="Usage" aria-description="Weekly usage: 42% left" aria-expanded="false">Usage</button><button aria-label="Open profile menu">Profile</button></div></nav><div class="secondary"><div class="official">ChatGPT<br>New chat<br>Projects<br>Recent conversations</div></div></aside><main><h1>ChatGPT workspace</h1><p>Synthetic extension-load acceptance. No real account.</p></main></div><div id="portal"></div><script>
 document.getElementById('official-usage').onclick=()=>{const b=document.getElementById('official-usage'),open=b.getAttribute('aria-expanded')==='true';b.setAttribute('aria-expanded',String(!open));document.getElementById('portal').innerHTML=open?'':'<div role="menu" aria-labelledby="official-usage"><p>Usage source: Your Pro plan</p><div role="menuitem">Weekly limit 42% left</div><div role="menuitem">Credits 999.99 credits</div></div>'};
 if(location.pathname==='/settings/usage')document.querySelector('main').innerHTML='<div><section><div>ChatGPT Pro 100</div></section><section><div>Weekly limit</div><span>Resets in 2 days</span><progress max="100" value="42" aria-label="Remaining usage"></progress></section><section><div id="usage-limit-resets"></div><button role="tab">Available 0</button></section><section><div>剩余额度：751</div></section></div>';
 </script>`}));
 const page=await context.newPage();await page.goto('https://chatgpt.com/');
 const host=page.locator('#cqs-web-usage-preview');await host.locator('[data-metric=credits] dd').filter({hasText:'999'}).waitFor();
 assert.equal(await host.locator('[data-metric=week] dd').innerText(),'42%');assert.equal(await host.locator('img').evaluate(el=>el.complete&&el.naturalWidth===32),true);
 await host.getByRole('button',{name:'Display choices',exact:true}).click();await host.locator('input[data-field=plan]').uncheck();await host.getByRole('button',{name:'Back',exact:true}).click();
 assert.equal(await host.locator('[data-metric=plan]').count(),0);await page.reload();await host.locator('[data-metric=credits] dd').filter({hasText:'999'}).waitFor();assert.equal(await host.locator('[data-metric=plan]').count(),0,'actual extension preferences did not survive reload');
 const stored=await worker.evaluate(()=>chrome.storage.local.get(null));assert.ok(Object.keys(stored).every(k=>['cqsWebPreferences','cqsCheckedAt','cqsNewVersion'].includes(k)));assert.equal(stored.cqsWebPreferences.choices.plan,false);
 await page.screenshot({path:out+'actual-extension-en.png'});
 const opened=context.waitForEvent('page');await host.getByRole('link',{name:'Read full usage'}).click();const official=await opened;
 const bring=official.getByRole('button',{name:'Same account: bring readings back'});await bring.click();
 await host.locator('[data-metric=credits] dd').filter({hasText:'751'}).waitFor();
 assert.equal(await host.locator('[data-metric=resets] dd').innerText(),'0');assert.equal(await host.locator('[data-metric=reset] dd').innerText(),'Resets in 2 days');
 assert.deepEqual(await worker.evaluate(()=>chrome.storage.session.get(null)),{},'consumed route must be cleared');
 const another=context.waitForEvent('page');await host.getByRole('link',{name:'Read full usage'}).click();const next=await another;
 await page.getByRole('button',{name:'Open profile menu'}).click();
 await next.getByRole('button',{name:'Same account: bring readings back'}).click();
 await next.locator('#cqs-web-usage-preview .status').filter({hasText:'open full usage again'}).waitFor();
 assert.equal(await host.locator('[data-metric=week] dd').innerText(),'--','account change must invalidate outstanding handback');
 console.log('PASS: official sibling sections, explicit same-account confirmation, handback to originating chat including real zero');
 console.log('PASS: actual MV3 extension loaded, content scripts auto-mounted, real storage persisted choices across reload, icon rendered, no quota stored, no native-host permission');
}finally{await context.close();}
