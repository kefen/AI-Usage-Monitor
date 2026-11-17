import {readFile,mkdir} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const {chromium}=createRequire(import.meta.url)(process.env.PLAYWRIGHT_MODULE||'playwright');
const out=new URL('../docs/screenshots/',import.meta.url);await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true,executablePath:process.env.TEST_BROWSER_PATH});
try{
  const page=await browser.newPage({viewport:{width:600,height:680},deviceScaleFactor:2});
  await page.setContent(`<meta charset="utf-8"><style>*{box-sizing:border-box}body{margin:0;font:14px 'Microsoft YaHei',Arial;color:#242830;background:#f7f8fa}header{height:76px;padding:20px 24px;background:white;border-bottom:1px solid #dce2e9}h1{font-size:18px;font-weight:400;margin:0 0 5px}small{font-size:11px;color:#667085}aside{display:flex;width:100%;height:604px}nav{display:flex;flex-direction:column;align-items:center;gap:8px;padding:8px;width:52px;flex-shrink:0;background:#f1f3f6}.list{flex:1;min-height:0}.bottom{height:56px;width:36px}.bottom button{width:30px;height:30px;border:1px solid #d2d9e4;background:white;border-radius:50%;color:#7d8795}.sidebar-navigation{padding:28px;width:240px;background:#fafbfc;border-right:1px solid #e3e7ec}.item{padding:14px 0;color:#637083;border-bottom:1px solid #edf0f4}.workspace{padding:30px 24px;flex:1}.workspace p{font-size:12px;line-height:1.9;color:#738094}h2{font-size:15px;font-weight:400;margin:0 0 18px}</style><header><h1>Codex Quota Sidebar</h1><small>KEFEN / Sidebar demo / Synthetic sample data</small></header><aside class="app-shell-left-panel"><nav data-app-navigation-rail><div class="list"></div><div class="bottom"><button aria-label="Sample account">C</button></div></nav><div class="sidebar-navigation" data-slate-sidebar-content><h2>Sample projects</h2><div class="item">Project A</div><div class="item">Project B</div><div class="item">Project C</div></div><div class="workspace"><h2>Local usage</h2><p>Live sidebar component.<br>Quota and Tokens are separate.<br>Dates follow source records.<br>Plan and renewal are manual.</p></div></aside>`);
  await page.evaluate(await readFile(new URL('../src/widget.js',import.meta.url),'utf8'));
  await page.evaluate(()=>{const yesterday=new Date();yesterday.setDate(yesterday.getDate()-1);const day=yesterday.getFullYear()+'-'+String(yesterday.getMonth()+1).padStart(2,'0')+'-'+String(yesterday.getDate()).padStart(2,'0');window.__localCodexMeter.receive({language:'en',fetchedAt:Date.now(),planBadge:'Pro',planSource:'manual',resetCredits:3,buckets:[{id:'codex',credits:{balance:'162'},windows:[{minutes:300,remaining:62,resetsAt:Date.now()/1000+7200},{minutes:10080,remaining:37,resetsAt:Date.now()/1000+172800}]}],membership:{kind:'renewal',date:'2026-12-15',estimated:true},usage:{fetchedAt:Date.now(),lifetime:3010000000,dailySelected:{date:day,value:202650000},month:{average:125350000,value:2005600000,days:16,complete:false},week:{value:96900000,days:7,complete:true},weeks:[]}});});
  await page.screenshot({path:fileURLToPath(new URL('sidebar-demo.png',out))});
  await page.setViewportSize({width:1120,height:760});
  await page.evaluate(()=>{
    const sheet=document.createElement('style');
    sheet.textContent=`
      body{font-family:"Segoe UI",Arial,sans-serif;background:white}
      header{height:56px;padding:16px 22px;display:flex;align-items:center;justify-content:space-between}
      header h1{font-size:14px;margin:0}header small{font-size:11px}
      aside{height:664px}nav{width:58px;background:#f3f4f6}
      .sidebar-navigation{width:246px;padding:22px 18px;background:#fafafa}
      .sidebar-navigation h2{font-size:13px;color:#666;margin-top:28px}
      .item{border:0;font-size:13px;padding:10px 8px}.item.active{background:#edf0f4;border-radius:6px;color:#232830}
      .workspace{position:relative;padding:28px 32px;display:flex;flex-direction:column}
      .workspace .topline{font-size:12px;color:#6b7280}
      .workspace .welcome{flex:1;display:flex;align-items:center;justify-content:center;padding-bottom:65px}
      .workspace h2{font-size:27px;color:#232830}
      .composer{border:1px solid #dce0e6;border-radius:8px;padding:16px 18px;margin-bottom:16px;height:132px;background:white}
      .composer .placeholder{font-size:14px;color:#969ca6}.composer .actions{margin-top:52px;display:flex;justify-content:space-between;font-size:12px;color:#667085}
      footer{height:40px;padding:12px 22px;background:#f5f7fa;border-top:1px solid #e0e5ec;font-size:11px;color:#687386}
    `;
    document.head.append(sheet);
    document.querySelector('header').innerHTML='<h1>Codex / Workspace</h1><small>Codex Quota Sidebar by KEFEN</small>';
    document.querySelector('.sidebar-navigation').innerHTML='<div class="item active">+ New chat</div><div class="item">Search</div><h2>Projects</h2><div class="item">Sample workspace</div><h2>Recent chats</h2><div class="item">Example task</div><div class="item">Design review</div>';
    document.querySelector('.workspace').innerHTML='<div class="topline">Sample workspace</div><div class="welcome"><h2>What should we build?</h2></div><div class="composer"><div class="placeholder">Ask Codex...</div><div class="actions"><span>+ &nbsp; Local computer</span><span>Send &uarr;</span></div></div>';
    const footer=document.createElement('footer');footer.textContent='Generated Codex-style demonstration | Actual sidebar component, synthetic data | Not a live Codex screenshot';document.body.append(footer);
  });
  await page.screenshot({path:fileURLToPath(new URL('codex-sidebar-overview.png',out))});
}finally{await browser.close();}
