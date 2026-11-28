import {app,BrowserWindow,protocol,Menu,nativeTheme,systemPreferences,screen,ipcMain,clipboard,Notification,Tray,nativeImage,shell,dialog} from 'electron';
import {appendFile,lstat,mkdir,readFile,rename,stat,writeFile} from 'node:fs/promises';
import {mkdirSync,mkdtempSync,readFileSync,unlinkSync,writeFileSync} from 'node:fs';
import {tmpdir,release} from 'node:os';
import {basename,dirname,extname,isAbsolute,join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {setTimeout as pause} from 'node:timers/promises';
import {demoUrl,resolveAsset,windowMaterial,compositionCheck,profileName,version} from './contract.mjs';
import {desktopActionAllowed,openCodex} from './actions.mjs';
import {loadCollectorSource,storeCollectorSource} from './source-config.mjs';
import {syncSidebarFields} from './sidebar-display.mjs';
import {edges,nearestEdge,dockBounds,contains,liveWindow,dockVisible} from './dock.mjs';
import {trackWorkspaceDock} from './mac-dock-visibility.mjs';

const captureArg = process.argv.find(arg => arg.startsWith('--capture-dir='));
const captureDir = captureArg ? resolve(captureArg.slice('--capture-dir='.length)) : null;
const reference = Boolean(captureDir && process.argv.includes('--reference-scene'));
const composedArg = process.argv.find(arg => arg.startsWith('--compose-dir='));
const composedDir = composedArg ? resolve(composedArg.slice('--compose-dir='.length)) : null;
const platform = process.platform;
const installedShell = app.isPackaged || (platform==='darwin' && resolve(app.getAppPath())===resolve(process.resourcesPath,'app'));
const profile=profileName(process.argv)??(installedShell&&!captureDir&&!composedDir?'local':null);
const workspace = demoUrl(platform,'workspace',profile?{sample:'workflow'}:{});
const setup = demoUrl(platform,'setup');
const settingsTest=process.argv.find(arg=>arg.startsWith('--settings-test='))?.split('=')[1];
const legacyArg=process.argv.find(arg=>arg.startsWith('--import-workspace='));
const legacyPath=legacyArg?.slice('--import-workspace='.length);
let usageSource=process.argv.find(arg=>arg.startsWith('--usage-source='))?.slice('--usage-source='.length);
const bindArg=process.argv.find(arg=>arg.startsWith('--bind-collector='));
const binding=bindArg?.slice('--bind-collector='.length);
if(bindArg&&(!binding||!profile||usageSource))throw new Error('Binding requires a collector folder and a named profile.');
if(usageSource&&!profile)throw new Error('Local usage requires a named profile.');
const usageTest=process.argv.find(arg=>arg.startsWith('--usage-test='))?.slice('--usage-test='.length);
const collectorTest=process.argv.find(arg=>arg.startsWith('--collector-test='))?.slice('--collector-test='.length);
if(collectorTest&&(!usageTest||!['attached','unknown','stale'].includes(collectorTest)))throw new Error('Collector acceptance requires a snapshot fixture.');
if(usageTest&&(!profile||!['known','dual','missing'].includes(usageTest)))throw new Error('Usage acceptance requires a named profile and a supported case.');
const trayTest=process.argv.includes('--tray-test');
const updateTest=process.argv.includes('--update-test');
const dataTest=process.argv.includes('--data-test');
if(dataTest&&(!profile||usageTest||settingsTest||trayTest||updateTest||composedDir))throw new Error('Data acceptance requires a named profile.');
if(updateTest&&(!profile||usageTest||settingsTest||trayTest||composedDir))throw new Error('Update acceptance requires a named profile.');
if(trayTest&&(!profile||settingsTest||usageTest||captureDir||composedDir))throw new Error('Tray acceptance requires an isolated named profile.');
const validateImport=process.argv.includes('--validate-import');
if(validateImport&&!legacyPath)throw new Error('No import source to validate.');
if(legacyArg&&(!legacyPath||!profile||settingsTest||captureDir||composedDir))throw new Error('Import requires a source folder and a new named desktop profile.');
if(settingsTest&&(!profile||!['save','reopen'].includes(settingsTest)))throw new Error('Settings acceptance requires a named profile and a save or reopen phase.');
const desktopRevision=['win32','darwin'].includes(platform)&&installedShell?version:'';
const workspaceHeight=640;
const sidebarBeta=version==='0.15.5-beta.1';
const profileRoot=installedShell?join(app.getPath('appData'),sidebarBeta?'AI-Usage-Monitor-Sidebar-Beta':'AI-Usage-Monitor-Demo8-QA'+(desktopRevision?'-r13':'')):
  fileURLToPath(new URL('../../build/demo8-profiles/',import.meta.url));
const scratch=profile?join(profileRoot,profile):mkdtempSync(join(tmpdir(),'aum-demo8-'));
const isolatedAlerts=process.argv.includes('--enable-codex-alerts');
if(isolatedAlerts&&(!usageSource||resolve(usageSource)!==resolve(scratch,'collector')))
  throw new Error('Native alert testing requires the named profile’s own collector directory.');
if(profile)mkdirSync(scratch,{recursive:true});
app.setPath('userData',scratch);
app.setName('AI Usage Monitor');
if(platform==='win32')app.setAppUserModelId('KEFEN.AIUsageMonitor');
protocol.registerSchemesAsPrivileged([{scheme:'aum-preview',privileges:{standard:true,secure:true,supportFetchAPI:true}}]);
const types = {'.html':'text/html;charset=utf-8','.css':'text/css;charset=utf-8','.js':'text/javascript;charset=utf-8','.mjs':'text/javascript;charset=utf-8','.png':'image/png','.jpg':'image/jpeg'};
const csp = "default-src 'none'; script-src 'self'; connect-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; base-uri 'none'; frame-ancestors 'none'; form-action 'none'";
let win,tray,quitting=false;
let updateCheckInFlight=null;
async function checkSavedPreferences(open){
  const run=fn=>win.webContents.executeJavaScript('('+fn.toString()+')()');
  await open(workspace,{sample:'workflow',page:'plans'});
  if(settingsTest==='save'){
    const plan=await run(()=>{
      const set=(id,value)=>{const el=document.getElementById(id);el.value=value;el.dispatchEvent(new Event('change',{bubbles:true}));};
      set('planFamily','Pro');
      set('dateMode','manual');
      set('purchaseDate','2026-11-13');
      set('renewalDate','2026-11-12');
      document.querySelector('[data-action=savePlan]').click();
      if(!document.getElementById('planSaveStatus')?.textContent||
        localStorage.getItem('aum-dual-v2-preferences')!==null)throw new Error('Invalid plan dates were saved');
      set('renewalDate','2026-12-13');
      document.querySelector('[data-action=savePlan]').click();
      const plan=JSON.parse(localStorage.getItem('aum-dual-v2-preferences')).plans.codex;
      if(plan.plan!=='Pro'||plan.date!=='2026-12-13')throw new Error('Plan save failed');
      return plan;
    });
    await open(workspace,{sample:'workflow',page:'settings'});
    const alerts=await run(()=>{
      const el=document.getElementById('threshold');
      el.value='25';el.dispatchEvent(new Event('change',{bubbles:true}));
      const language=document.getElementById('language');
      language.value='en';language.dispatchEvent(new Event('change',{bubbles:true}));
      const p=JSON.parse(localStorage.getItem('aum-dual-v2-preferences'));
      if(p.alerts.threshold!==25||p.language!=='en')throw new Error('Threshold or language save failed');
      return p.alerts;
    });
    await open(workspace,{sample:'workflow',page:'display',surface:'quick'});
    const display=await run(()=>{
      const input=document.querySelector('input[data-field=week]');
      if(!input?.checked)throw new Error('Unexpected fenced profile display defaults');
      input.click();
      const fields=JSON.parse(localStorage.getItem('aum-dual-v2-preferences')).fields;
      if(fields.codex.quick.includes('week')||!fields.codex.host.includes('week')||!fields.claude.quick.includes('week'))
        throw new Error('Display change leaked into another scope or provider');
      return {codexQuickWeek:false};
    });
    win.webContents.session.flushStorageData();
    return {plan,alerts,display,saved:true};
  }
  const plan=await run(()=>{
    if(document.getElementById('planFamily')?.value!=='Pro'||document.getElementById('renewalDate')?.value!=='2026-12-13')
      throw new Error('Plan and recorded date were not restored in the UI');
    return document.getElementById('renewalDate').value;
  });
  await open(workspace,{sample:'workflow',page:'settings'});
  const settings=await run(()=>{
    const threshold=document.getElementById('threshold')?.value,language=document.getElementById('language')?.value;
    if(threshold!=='25'||language!=='en'||document.documentElement.lang!=='en')throw new Error('Settings were not restored in the UI');
    return {threshold,language};
  });
  await open(workspace,{sample:'workflow',page:'display',surface:'quick'});
  const display=await run(()=>{
    const input=document.querySelector('input[data-field=week]');
    if(!input||input.checked)throw new Error('Display preference was not restored in the UI');
    return {codexQuickWeek:input.checked};
  });
  return {renewalDate:plan,...settings,...display,restored:true};
}
async function checkDataPages(open){
  const run=fn=>win.webContents.executeJavaScript('('+fn.toString()+')()');
  await open(workspace,{page:'settings',settingsTab:'data'});
  const preferences=await run(async()=>{
    let blob;
    URL.createObjectURL=value=>{blob=value;return 'blob:aum-preview://demo8/test';};
    URL.revokeObjectURL=()=>{};
    HTMLAnchorElement.prototype.click=()=>{};
    document.querySelector('[data-action=backup]').click();
    const backup=JSON.parse(await blob.text());
    if(backup.format!=='aum-desktop-settings-v1'||backup.prefs.connections||
      !document.querySelector('[data-action=clearObservation]').disabled)throw new Error('Unsafe desktop backup');
    backup.prefs.language='en';
    const input=document.createElement('input');input.type='file';input.id='restoreFile';input.hidden=true;
    document.body.append(input);
    const transfer=new DataTransfer();transfer.items.add(new File([JSON.stringify(backup)],'settings.json',{type:'application/json'}));
    input.files=transfer.files;input.dispatchEvent(new Event('change',{bubbles:true}));
    const end=Date.now()+3000;
    while(!document.querySelector('[data-action=confirmRestore]')&&Date.now()<end)await new Promise(r=>setTimeout(r,25));
    const saved=()=>JSON.parse(localStorage.getItem('aum-dual-v2-preferences'));
    if(saved()!==null)throw new Error('Settings changed before confirmation');
    document.querySelector('[data-action=confirmRestore]').click();
    if(saved()?.language!=='en'||document.documentElement.lang!=='en')throw new Error('Restore did not update desktop preferences');
    return {backup:backup.format,restoreConfirmed:true,language:saved().language};
  });
  await open(workspace,{page:'settings'});
  await run(()=>{
    const input=document.getElementById('reduceTransparency');
    if(input.checked)throw new Error('Fresh profile unexpectedly reduced transparency');
    input.click();
    if(document.documentElement.dataset.transparency!=='reduced')throw new Error('Desktop surface was not reduced');
  });
  await pause(200);
  let material;
  if(platform==='win32'&&process.env.WIN_DEMO8_DWM_EXE&&Number(release().split('.')[2])>=22621){
    const {readBackdrop}=(await import('../../tools/win-demo8-backdrop.cjs')).default;
    const off=readBackdrop(process.env.WIN_DEMO8_DWM_EXE,win).value;
    if(off!==1)throw new Error('Native backdrop did not turn off: '+off);
    await run(()=>document.getElementById('reduceTransparency').click());
    await pause(200);
    const on=readBackdrop(process.env.WIN_DEMO8_DWM_EXE,win).value;
    if(on!==3)throw new Error('Native backdrop did not restore: '+on);
    material={off,on};
  }
  await open(workspace,{page:'help'});
  const diagnostics=await run(async()=>{
    let blob;
    URL.createObjectURL=value=>{blob=value;return 'blob:aum-preview://demo8/test';};
    URL.revokeObjectURL=()=>{};
    HTMLAnchorElement.prototype.click=()=>{};
    document.querySelector('[data-action=diagnostics]').click();
    const data=JSON.parse(await blob.text()),rect=document.querySelector('.app-window').getBoundingClientRect();
    if(data.format!=='aum-desktop-diagnostics-v1'||data.synthetic||Math.abs(rect.bottom-innerHeight)>1)
      throw new Error('Diagnostics or desktop viewport did not match');
    await Promise.all([document.fonts.ready,...[...document.images].map(image=>image.decode())]);
    return {format:data.format,version:data.version,footerAligned:true};
  });
  if(captureDir){
    await mkdir(captureDir,{recursive:true});await pause(250);
    const image=await win.webContents.capturePage(undefined,{stayHidden:true});
    if(image.isEmpty())throw new Error('Empty diagnostics capture');
    await writeFile(join(captureDir,'desktop-diagnostics.png'),image.toPNG());
  }
  return {preferences,material,diagnostics};
}
async function offerMacUpgrade(){
  if(sidebarBeta||platform!=='darwin'||!installedShell||profile!=='local')return;
  const folders=['/Applications',join(app.getPath('home'),'Applications')];
  const appBundle=resolve(process.resourcesPath,'../..');
  if(!folders.some(folder=>appBundle===join(folder,'AI Usage Monitor.app')))return;
  const receipt=join(scratch,'mac-upgrade-reviewed-v1');
  if(await lstat(receipt).catch(()=>null))return;
  const candidates=[];
  for(const folder of folders){
    if(!(await lstat(folder).catch(()=>null))?.isDirectory())continue;
    for(const [name,id] of [['AI Usage Monitor Demo.8.app','local.demo8.preview'],
      ['AI Usage Monitor.app','org.codexquotasidebar.desktop']]){
      const old=join(folder,name),contents=join(old,'Contents'),plist=join(contents,'Info.plist');
      if(old===appBundle||!(await lstat(old).catch(()=>null))?.isDirectory()||
        !(await lstat(contents).catch(()=>null))?.isDirectory()||!(await lstat(plist).catch(()=>null))?.isFile())continue;
      try{
        if(execFileSync('/usr/bin/plutil',['-extract','CFBundleIdentifier','raw','-o','-',plist],
          {encoding:'utf8',timeout:1600,stdio:['ignore','pipe','ignore']}).trim()===id)candidates.push(old);
      }catch{}
    }
  }
  if(!candidates.length)return;
  const zh=app.getLocale().startsWith('zh');
  const {response}=await dialog.showMessageBox(win,{type:'question',
    message:zh?'将旧版 AI Usage Monitor 移到废纸篓？':'Move older AI Usage Monitor apps to the Trash?',
    detail:candidates.join('\n')+'\n\n'+(zh?'请先退出旧版。只移除应用，保留设置和历史。':'Quit the older apps first. Your settings and history are kept.'),
    buttons:zh?['暂不处理','移到废纸篓']:['Not now','Move to Trash'],defaultId:0,cancelId:0});
  if(response===1)for(const old of candidates)await shell.trashItem(old);
  await writeFile(receipt,'0.15.0\n',{flag:'wx'});
}
async function start(){
  if(binding){
    usageSource=await storeCollectorSource(scratch,resolve(binding));
    if(!usageSource)throw new Error('No recognized collector snapshot in the provided directory.');
  }
  if(profile&&!usageSource&&(!installedShell||usageTest))usageSource=await loadCollectorSource(scratch);
  if(usageTest&&!usageSource)throw new Error('Usage acceptance requires a collector fixture.');
  const usageModule=profile?await import('./usage.mjs'):null;
  const usage=usageModule?.readDesktopUsage;
  const nativeFeed=installedShell&&profile&&!usageTest&&!settingsTest&&!dataTest&&!updateTest&&!trayTest&&!legacyArg;
  const nativeCodex=nativeFeed?await import('./local-codex.mjs'):null;
  const sidebarProfile=join(scratch,'sidebar-source');
  let sidebarRoot=usageSource||await loadCollectorSource(sidebarProfile)||(platform==='darwin'?join(app.getPath('home'),'Library/Application Support/CodexSidebarMeter/.runtime'):
    join(app.getPath('documents'),'Codex/Apps/CodexSidebarMeter/.runtime'));
  let pendingSidebarWrite=Promise.resolve();
  const bundleFile=join(scratch,'codex-bundle.json');
  let bundle=null;
  if(platform==='darwin')try{const path=JSON.parse(readFileSync(bundleFile));if(typeof path==='string'&&isAbsolute(path)&&path.endsWith('.app'))bundle=path;}catch{}
  const directCodex=nativeCodex?.localCodexReader({options:()=>({bundle})});
  const claudeHome=isAbsolute(process.env.CLAUDE_CONFIG_DIR||'')?process.env.CLAUDE_CONFIG_DIR:join(app.getPath('home'),'.claude');
  const claudeSettings=join(profile==='local'?claudeHome:join(scratch,'claude-config'),'settings.json');
  const exists=async path=>Boolean(await stat(path).catch(()=>null));
  function claudeConfig(){
    const quote=value=>{
      if(platform==='win32'&&value.includes("'"))throw new Error('Unsupported quote in status line path');
      return "'"+(platform==='win32'?value.replaceAll('\\','/'):value.replaceAll("'","'\\''"))+"'";
    };
    const script=fileURLToPath(new URL('../../src/claude-statusline.mjs',import.meta.url));
    const runtime=platform==='darwin'?'ELECTRON_RUN_AS_NODE=1 '+quote(process.execPath):'node';
    return {statusLine:{type:'command',command:runtime+' '+quote(script)+' capture-desktop '+quote(scratch)}};
  }
  let previousMode,workspaceBounds,workspaceResized=false,glanceMode='quick';
  let traceQueue=Promise.resolve();
  const readings=async(codex,claude,force,surface='background')=>{
    const start=Date.now(),trace={at:new Date(start).toISOString(),surface,force,source:'collector'};
    try{
    const local=await usage(scratch);
    const snapshot=usageSource?await usage(resolve(usageSource)):local;
    let codexReading=nativeFeed&&!usageSource?null:snapshot.codex,codexConnection;
    if(codex&&directCodex){
      if(usageSource&&nativeCodex.codexHasReadings(codexReading))codexConnection='desktop';
      else{
        codexReading=await directCodex(force,trace);
        codexConnection=directCodex.state();
      }
    }
    trace.display=codexConnection??'collector';
    return {...snapshot,codex:codexReading,claude:claude?(snapshot.claude??local.claude):null,
      ...(codexConnection?{codexConnection}:{})};
    }catch(error){trace.failure='refresh-failed';throw error;}
    finally{if(codex&&['win32','darwin'].includes(process.platform)){
      trace.totalMs=Date.now()-start;
      traceQueue=traceQueue.then(async()=>{
        const file=join(scratch,'codex-refresh.jsonl');
        if((await stat(file).catch(()=>null))?.size>=262144)await rename(file,file+'.1');
        await appendFile(file,JSON.stringify(trace)+'\n');
      }).catch(()=>{});
      await traceQueue;
    }}
  };
  const notify=isolatedAlerts?(await import('./alerts.mjs')).notifyWeeklyCodex:null;
  protocol.handle('aum-preview',async request=>{
    const url=new URL(request.url);
    if(usage&&(usageSource||nativeFeed)&&request.method==='GET'&&url.origin===new URL(workspace).origin&&url.hostname==='demo8'&&url.pathname==='/readings.json'){
      return new Response(JSON.stringify(await readings(url.searchParams.get('codex')==='1',url.searchParams.get('claude')!=='0',url.searchParams.get('refresh')==='1',url.searchParams.get('surface')==='rail'?'rail':'workspace')),{headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
    }
    const path=resolveAsset(url);
    if(!path || request.method!=='GET')return new Response(null,{status:404});
    try{
      const bytes=await readFile(path),type=extname(path);
      const handoff=type==='.html'&&url.pathname===new URL(workspace).pathname&&url.searchParams.get('desktopRail')==='1'?directCodex?.peek():null;
      const body=type==='.html'?bytes.toString('utf8')
        .replace('<html ',reference?'<html data-desktop-app data-reference-scene="true" ':'<html data-desktop-app ')
        .replace('<html ',desktopRevision?'<html data-build-revision="'+desktopRevision+'" ':'<html ')
        .replace('<html ',usageSource||nativeFeed?'<html data-live-usage="true" ':'<html ')
        .replace('<html ',nativeFeed?'<html data-native-feed="true" ':'<html ')
        .replace('</head>',()=>(handoff?'<meta name="rail-reading" content="'+encodeURIComponent(JSON.stringify(handoff))+'">':'')+'<link rel="stylesheet" href="/window.css"></head>'):bytes;
      return new Response(body,{headers:{'Content-Type':types[type],'Content-Security-Policy':csp,'X-Content-Type-Options':'nosniff','Cache-Control':'no-store'}});
    }
    catch{return new Response(null,{status:404});}
  });
  const area=screen.getPrimaryDisplay().workAreaSize;
  const reduced = nativeTheme.shouldUseHighContrastColors || (platform==='darwin' && systemPreferences.getUserDefault('reduceTransparency','boolean'));
  const material=windowMaterial(platform,release(),reduced);
  let preferredReduced=false,panel,railReady=false;
  function surfaceMaterial(solid){
    const next=windowMaterial(platform,release(),solid);
    return next;
  }
  const preload=fileURLToPath(new URL('./actions-preload.cjs',import.meta.url));
  function applyWindowMaterial(){
    // The pinned panel must remain readable over another app.
    const next=surfaceMaterial(reduced||preferredReduced||previousMode==='widget');
    if(material.backgroundMaterial)win.setBackgroundMaterial(next.backgroundMaterial||'none');
    if(platform==='darwin')win.setVibrancy(next.vibrancy??null);
    win.setBackgroundColor(next.backgroundColor);
  }
  win=new BrowserWindow({
    show:false,width:Math.min(area.width,1296),height:Math.min(area.height,workspaceHeight),
    minWidth:Math.min(area.width,768),minHeight:Math.min(area.height,590),
    title:'AI Usage Monitor',titleBarStyle:'hidden',
    ...(platform==='win32'?{icon:fileURLToPath(new URL('../../assets/Monitor.ico',import.meta.url))}:{}),
    ...(platform==='win32'?{titleBarOverlay:{color:'#00000000',symbolColor:nativeTheme.shouldUseDarkColors?'#ffffff':'#17222b',height:34}}:{}),
    ...surfaceMaterial(reduced),webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true,
      ...(profile?{preload,backgroundThrottling:false}:{})}
  });
  let rail,indicator,edge='right',displayId,expanded=true,changeAt=0,holdUntil=0,drag=null,railHeight=540;
  const dockFile=join(scratch,'desktop-dock.json');
  let floating=null,locked=false,above=true,anchor=.5;
  let surfaceRequest=0;
  try{const saved=JSON.parse(readFileSync(dockFile));if(edges.includes(saved.edge)){edge=saved.edge;displayId=saved.displayId;}
    if(Number.isFinite(saved.floating?.x)&&Number.isFinite(saved.floating?.y))floating=saved.floating;
    locked=saved.locked===true;above=saved.above!==false;
    if(Number.isFinite(saved.anchor))anchor=Math.max(0,Math.min(1,saved.anchor));
  }catch{}
  function areaForRail(){return (screen.getAllDisplays().find(d=>d.id===displayId)||screen.getDisplayMatching(win.getBounds())).workArea;}
  function positionRail(show){
    if(quitting||!liveWindow(win)||!liveWindow(rail))return;
    if(floating||locked)show=true;
    expanded=show;changeAt=0;
    const area=areaForRail(),target=dockBounds(area,floating?'left':edge,show,railHeight,anchor);
    if(floating){for(const [k,n] of [['x','width'],['y','height']])target[k]=Math.max(area[k],Math.min(floating[k],area[k]+area[n]-target[n]));}
    if(liveWindow(indicator)){
      // Windows enforces a minimum HWND size at some DPI settings. Clip both paint and hit-testing.
      if(show){
        indicator?.hide();
        rail.setBounds(target);
        if(railReady&&!rail.isVisible())rail.showInactive();
      }
      else{
        const width=Math.max(48,target.width),height=Math.max(48,target.height);
        rail.hide();
        const bounds={width,height,x:edge==='right'?area.x+area.width-width:target.x,
          y:edge==='bottom'?area.y+area.height-height:target.y};
        indicator.setBounds(bounds);
        const current=indicator;
        current.webContents.executeJavaScript('document.body.className='+JSON.stringify(edge)).then(()=>{
          if(!quitting&&!expanded&&indicator===current&&liveWindow(current))current.showInactive();
        }).catch(error=>{if(!quitting&&liveWindow(current))console.warn('Edge indicator:',error.message);});
      }
    }else rail.setBounds(target);
    rail.webContents.send('dock-state',{edge:floating?'floating':edge,expanded,locked,above});
  }
  function rememberDock(){writeFileSync(dockFile,JSON.stringify({edge,displayId,floating,locked,above,anchor}));}
  async function openRail(chosen){
    if(quitting||!liveWindow(win))return false;
    ++surfaceRequest;
    if(edges.includes(chosen)){floating=null;edge=chosen;rememberDock();}
    holdUntil=Date.now()+1500;
    if(liveWindow(rail)){if(railReady){positionRail(true);rail.showInactive();win.hide();}return true;}
    railReady=false;
    rail=new BrowserWindow({show:false,frame:false,thickFrame:false,hasShadow:false,alwaysOnTop:true,skipTaskbar:true,
      resizable:false,fullscreenable:false,minimizable:false,maximizable:false,roundedCorners:false,
      ...surfaceMaterial(reduced||preferredReduced),...dockBounds(areaForRail(),floating?'left':edge,true,railHeight,anchor),
      webPreferences:{preload,nodeIntegration:false,sandbox:true,contextIsolation:true,backgroundThrottling:false,paintWhenInitiallyHidden:true}});
    const r=rail;
    r.setAlwaysOnTop(above);
    r.webContents.setWindowOpenHandler(()=>({action:'deny'}));r.webContents.on('will-navigate',e=>e.preventDefault());
    const timer=setInterval(()=>{
      if(quitting||rail!==r||!liveWindow(win)||!liveWindow(r)){clearInterval(timer);return;}
      if(floating||locked||drag||Date.now()<holdUntil||!dockVisible(r,indicator))return;
      const inside=contains(expanded?r.getBounds():dockBounds(areaForRail(),edge,false,railHeight,anchor),screen.getCursorScreenPoint());
      if(inside===expanded){changeAt=0;return;}
      if(!changeAt)changeAt=Date.now();
      if(Date.now()-changeAt>=(inside?70:460))positionRail(inside);
    },32);
    r.once('closed',()=>{
      clearInterval(timer);
      if(rail!==r)return;
      const previous=indicator;
      indicator=null;rail=null;railReady=false;drag=null;
      if(liveWindow(previous))previous.destroy();
    });
    const url=new URL(workspace);url.searchParams.set('desktopRail','1');
    try{
      if(['win32','darwin'].includes(platform)){
        indicator=new BrowserWindow({title:'AUM edge indicator',show:false,frame:false,transparent:true,backgroundColor:'#00000000',hasShadow:false,roundedCorners:false,focusable:false,skipTaskbar:true,alwaysOnTop:true,resizable:false,thickFrame:false,webPreferences:{sandbox:true,nodeIntegration:false,contextIsolation:true}});
        const mark=indicator;
        mark.once('closed',()=>{
          if(indicator!==mark)return;
          indicator=null;
          if(!quitting&&rail===r&&liveWindow(r)&&railReady&&!expanded){
            positionRail(true);r.showInactive();
          }
        });
        indicator.setIgnoreMouseEvents(true);
        await indicator.loadURL('data:text/html,'+encodeURIComponent('<title>AUM edge indicator</title><style>*{margin:0}i{position:absolute;background:rgba(250,251,252,.62);border-radius:3px}.left i,.right i{top:50%;transform:translateY(-50%);height:min(56px,100%);width:6px}.top i,.bottom i{left:50%;transform:translateX(-50%);width:min(56px,100%);height:6px}.right i{right:0}.bottom i{bottom:0}</style><body><i></i></body>'));
      }
      if(quitting||!liveWindow(r)||!liveWindow(win))return false;
      await r.loadURL(url.href);positionRail(true);
      if(quitting||!liveWindow(r)||!liveWindow(win))return false;
      await r.webContents.executeJavaScript('new Promise(done=>requestAnimationFrame(()=>requestAnimationFrame(()=>done(true))))');
      if(quitting||!liveWindow(r)||!liveWindow(win))return false;
      railReady=true;r.showInactive();win.hide();return true;
    }
    catch(e){if(quitting||!liveWindow(r))return false;r.destroy();throw e;}
  }
  screen.on('display-removed',()=>positionRail(expanded));screen.on('display-metrics-changed',()=>positionRail(expanded));
  ipcMain.handle('desktop-dock',async(event,command,value)=>{
    const fromRail=event.sender===rail?.webContents;
    if(quitting||!liveWindow(win)||!profile||(!fromRail&&event.sender!==win.webContents)||event.senderFrame!==event.sender.mainFrame||
      !desktopActionAllowed(event.senderFrame.url,true,'material'))return false;
    if(!fromRail){
      if(command==='open')return openRail(value);
      if(command==='start')return openRail(value);
      return false;
    }
    if(command==='size'&&!drag&&Number.isFinite(value)){railHeight=Math.min(850,Math.max(118,Math.ceil(value)));if(expanded)positionRail(true);}
    if(command==='workspace'){win.show();win.focus();win.webContents.send('dock-state',{workspaceReturned:true});rail.close();}
    if(command==='collapse')positionRail(false);
    if(command==='lock'||command==='above'){
      if(command==='lock')locked=!locked;else{above=!above;rail.setAlwaysOnTop(above);}
      rememberDock();positionRail(true);holdUntil=Date.now()+600;
    }
    if(command==='drag-start'&&!locked){drag={point:screen.getCursorScreenPoint(),bounds:rail.getBounds()};}
    if(command==='drag-move'&&drag){
      const p=screen.getCursorScreenPoint(),b=drag.bounds;
      rail.setBounds({x:b.x+p.x-drag.point.x,y:b.y+p.y-drag.point.y,width:b.width,height:b.height});
    }
    if(command==='drag-end'&&drag){
      const p=screen.getCursorScreenPoint(),d=screen.getDisplayNearestPoint(p),a=d.workArea;
      displayId=d.id;edge=nearestEdge(a,p);
      anchor=Math.max(0,Math.min(1,['left','right'].includes(edge)?(p.y-a.y)/a.height:(p.x-a.x)/a.width));
      floating=Math.min(p.x-a.x,a.x+a.width-p.x,p.y-a.y,a.y+a.height-p.y)<=24?null:
        {x:drag.bounds.x+p.x-drag.point.x,y:drag.bounds.y+p.y-drag.point.y};
      drag=null;rememberDock();holdUntil=Date.now()+400;positionRail(!!floating);
    }
    return true;
  });
  async function showCodexPanel(){
    if(panel&&!panel.isDestroyed()){panel.show();panel.moveTop();return true;}
    const work=screen.getDisplayMatching(win.getBounds()).workArea;
    const width=Math.min(work.width,380),height=Math.min(work.height,430),origin=win.getBounds();
    const next=new BrowserWindow({show:false,width,height,
      x:Math.max(work.x,Math.min(origin.x+32,work.x+work.width-width)),
      y:Math.max(work.y,Math.min(origin.y+32,work.y+work.height-height)),
      minWidth:Math.min(width,350),minHeight:Math.min(height,195),title:'AI Usage Monitor',
      alwaysOnTop:true,backgroundColor:nativeTheme.shouldUseDarkColors?'#20282d':'#f4f8fa',
      titleBarStyle:'hidden',...(platform==='win32'?{titleBarOverlay:{color:'#00000000',
        symbolColor:nativeTheme.shouldUseDarkColors?'#ffffff':'#17222b',height:34}}:{}),
      webPreferences:{contextIsolation:true,nodeIntegration:false,sandbox:true,preload}
    });
    panel=next;
    next.webContents.setWindowOpenHandler(()=>({action:'deny'}));
    next.webContents.on('will-navigate',event=>event.preventDefault());
    next.on('closed',()=>{if(panel===next)panel=null;});
    try{
      const url=new URL(workspace);
      url.searchParams.set('mode','widget');
      url.searchParams.set('codexPanel','1');
      await next.loadURL(url.href);
      if(next.isDestroyed())return false;
      next.show();next.moveTop();
      return true;
    }catch{if(!next.isDestroyed())next.destroy();return false;}
  }
  ipcMain.handle('demo8-action',async(event,action,value)=>{
    const from=event.senderFrame,isPanel=event.sender===panel?.webContents;
    const surface=isPanel?panel:win;
    if(!profile||!from||event.sender!==surface.webContents||
       !desktopActionAllowed(from.url,from===surface.webContents.mainFrame,action))return false;
    if(action==='copy-claude'){clipboard.writeText('claude');return true;}
    if(['check-codex-sidebar','sync-sidebar-fields','choose-sidebar-settings'].includes(action)){
      if(!nativeFeed||isPanel||(!usageSource&&profile!=='local'))return false;
      if(action==='choose-sidebar-settings'){
        const pick=await dialog.showOpenDialog(surface,{properties:['openFile'],filters:[{name:'display.json',extensions:['json']}]});
        if(pick.canceled)return 'cancelled';
        const file=pick.filePaths[0];
        if(!file||basename(file)!=='display.json'||!(await lstat(file)).isFile())return 'invalid';
        await mkdir(sidebarProfile,{recursive:true});
        const selected=await storeCollectorSource(sidebarProfile,dirname(file));
        if(!selected)return 'invalid';
        sidebarRoot=selected;
        return 'selected';
      }
      if(action==='check-codex-sidebar')return {...await usageModule.inspectCodexSidebar(sidebarRoot,null),path:join(sidebarRoot,'status.json')};
      const root=sidebarRoot;
      pendingSidebarWrite=pendingSidebarWrite.catch(()=>null).then(()=>syncSidebarFields(root,value));
      return pendingSidebarWrite;
    }
    if(action==='show-codex-panel'){
      return nativeFeed&&!isPanel&&showCodexPanel();
    }
    if(action==='show-workspace'){
      if(!isPanel)return false;
      const page=['sources','settings','display'].includes(value)?value:null;
      if(page)await open(workspace,{page,...(page==='display'?{provider:'codex',surface:'quick'}:{})});
      win.show();win.focus();
      if(!surface.isDestroyed())surface.close();
      return true;
    }
    if(action==='panel-pin'){
      if(!isPanel||typeof value!=='boolean')return false;
      surface.setAlwaysOnTop(value);
      return true;
    }
    if(action==='fit-content'){
      if(!nativeFeed||!Number.isSafeInteger(value)||value<1||value>8000||
        surface.isMaximized()||surface.isFullScreen()||surface.isMinimized())return false;
      const route=new URL(from.url),mode=route.searchParams.get('mode')||'workspace';
      if(!isPanel&&mode!==previousMode)return false;
      const compact=isPanel||['quick','widget'].includes(mode);
      if(!compact&&(workspaceResized||(route.searchParams.get('page')||'overview')!=='overview'))return false;
      const bounds=surface.getBounds(),work=screen.getDisplayMatching(bounds).workArea;
      const frame=bounds.height-surface.getContentSize()[1];
      const height=Math.min(work.height,Math.max(compact?195:workspaceHeight,value+frame));
      if(Math.abs(height-bounds.height)<=2||(!compact&&height<bounds.height))return false;
      surface.setBounds({...bounds,height,y:Math.max(work.y,Math.min(bounds.y,work.y+work.height-height))});
      return true;
    }
    if(action==='connect-claude'){
      if(!['darwin','win32'].includes(platform)||!installedShell||!nativeFeed||isPanel)return 'failed';
      if(process.execPath.startsWith('/Volumes/')||process.execPath.includes('/AppTranslocation/'))return 'temporary';
      const {connectClaude}=await import('./claude-connect.mjs');
      return connectClaude(claudeSettings,claudeConfig());
    }
    if(action==='check-claude-statusline'){
      if(!nativeFeed)return false;
      let command;
      try{command=claudeConfig().statusLine.command;}catch{}
      return {...await usageModule.inspectClaudeStatusline(claudeSettings,command,[scratch,usageSource]),settingsPath:claudeSettings};
    }
    if(action==='locate-integration'){
      if(!nativeFeed)return false;
      if(value==='codex'&&platform==='darwin'&&!isPanel){
        const pick=await dialog.showOpenDialog(win,{title:'选择 Codex 桌面应用',defaultPath:'/Applications',properties:['openFile'],filters:[{name:'Codex',extensions:['app']}]});
        if(pick.canceled)return false;
        const path=pick.filePaths[0];
        if(!path?.endsWith('.app')||!isAbsolute(path))return false;
        // Only accept a Codex application, never an arbitrary executable.
        try{const id=execFileSync('/usr/bin/plutil',['-extract','CFBundleIdentifier','raw',join(path,'Contents/Info.plist')],{encoding:'utf8',timeout:1500}).trim();
          if(!/^com\.openai\.codex(?:[.-][\w.-]+)?$/i.test(id))return 'invalid';
        }catch{return 'invalid';}
        bundle=path;await writeFile(bundleFile,JSON.stringify(path));return true;
      }
      if(value==='claude'){
        if(await exists(claudeSettings)){shell.showItemInFolder(claudeSettings);return true;}
        return await shell.openPath(await exists(claudeHome)?claudeHome:app.getPath('home'))==='';
      }
      return false;
    }
    if(action==='copy-claude-statusline'){
      if(!nativeFeed)return false;
      try{
        clipboard.writeText(JSON.stringify(claudeConfig(),null,2));
        return true;
      }catch{return false;}
    }
    if(action==='quit'){setImmediate(()=>app.quit());return true;}
    if(action==='check-updates'){
      updateCheckInFlight??=import('./update-check.mjs').then(m=>m.checkPreviewUpdate({
        onAvailable:nativeFeed&&profile==='local'&&!isPanel?async(asset,current)=>{
          const {applyDesktopUpdate}=await import('./install-update.mjs');
          return applyDesktopUpdate({app,dialog,win,asset,current});
        }:undefined
      })).finally(()=>{if(!win.isDestroyed())win.setProgressBar(-1);updateCheckInFlight=null;});
      return updateCheckInFlight;
    }
    if(action==='material'){
      if(!value||typeof value.reduced!=='boolean'||!['light','dark','system'].includes(value.theme))return false;
      nativeTheme.themeSource=value.theme;
      preferredReduced=value.reduced;
      if(!isPanel)applyWindowMaterial();
      if(rail){const m=surfaceMaterial(preferredReduced||reduced);
        if(material.backgroundMaterial)rail.setBackgroundMaterial(m.backgroundMaterial||'none');
        if(platform==='darwin')rail.setVibrancy(m.vibrancy??null);
        rail.setBackgroundColor(m.backgroundColor);}
      return true;
    }
    return openCodex();
  });
  const projectLinks=new Set(['https://github.com/kefen/AI-Usage-Monitor','https://github.com/kefen/AI-Usage-Monitor/issues/new','https://github.com/kefen/AI-Usage-Monitor/releases']);
  win.webContents.setWindowOpenHandler(({url})=>{
    if(profile&&projectLinks.has(url))void shell.openExternal(url).catch(()=>{});
    return {action:'deny'};
  });
  if(profile)win.webContents.session.on('will-download',(event,item,sender)=>{
    if(sender!==win.webContents||!desktopActionAllowed(sender.getURL(),true,'quit')||!item.getURL().startsWith('blob:')){
      event.preventDefault();return;
    }
    item.setSaveDialogOptions({title:'AI Usage Monitor'});
  });
  win.webContents.on('will-navigate',(event,href)=>{if(!resolveAsset(new URL(href)))event.preventDefault();});
  win.webContents.session.setPermissionRequestHandler((_wc,_permission,reply)=>reply(false));
  if(notify&&Notification.isSupported()){
    let checking=false;
    const tick=async()=>{
      if(checking||win.isDestroyed()||!desktopActionAllowed(win.webContents.getURL(),true,'quit'))return;
      checking=true;
      try{
        const settings=await win.webContents.executeJavaScript("JSON.parse(localStorage.getItem('aum-dual-v2-preferences'))");
        if(settings?.platforms?.codex===false||settings?.alerts?.enabled!==true)return;
        const readings=await usage(resolve(usageSource));
        await notify(scratch,readings.codex,settings.alerts,remaining=>{
          const en=settings.language==='en';
          new Notification({title:'AI Usage Monitor',body:en?`Codex weekly remaining: ${remaining}%`:`Codex 周额度剩余：${remaining}%`}).show();
        });
      }catch(error){console.error('Weekly notification check failed:',error.code||'E_NOTIFY');}
      finally{checking=false;}
    };
    const timer=setInterval(tick,30000);
    win.on('closed',()=>clearInterval(timer));
  }
  let materialReadback=null;
  if(platform==='win32' && process.env.WIN_DEMO8_DWM_EXE && material.backgroundMaterial){
    const {probeWindow,readBackdrop}=(await import('../../tools/win-demo8-backdrop.cjs')).default;
    materialReadback=probeWindow(win,window=>readBackdrop(process.env.WIN_DEMO8_DWM_EXE,window));
  }
  function fitWindow(url){
    const mode=url.searchParams.get('mode')||'workspace';
    if(mode===previousMode)return;
    if(previousMode==='workspace')workspaceBounds=win.getBounds();
    previousMode=mode;
    const compact=['quick','widget'].includes(mode);
    if(compact)glanceMode=mode;
    const work=screen.getDisplayMatching(win.getBounds()).workArea;
    const width=Math.min(work.width,compact?376:1296),height=Math.min(work.height,compact?424:workspaceHeight);
    win.setMinimumSize(Math.min(width,compact?350:768),Math.min(height,compact?195:590));
    const [w,h]=win.getContentSize();
    if(!compact&&workspaceBounds){
      win.setBounds(workspaceBounds);
      const actual=win.getBounds();
      if(actual.width!==workspaceBounds.width||actual.height!==workspaceBounds.height){
        // Fractional display scaling can round the native frame outwards.
        win.setBounds({...workspaceBounds,width:2*workspaceBounds.width-actual.width,height:2*workspaceBounds.height-actual.height});
      }
    }
    else if(w!==width||h!==height)win.setContentSize(width,height);
    applyWindowMaterial();
    win.setAlwaysOnTop(mode==='widget');
  }
  win.on('will-resize',()=>{if(previousMode==='workspace')workspaceResized=true;});
  win.webContents.on('did-navigate-in-page',(_event,href)=>fitWindow(new URL(href)));
  const open = async (target,params={}) => {
    const url=new URL(target);
    for(const [key,value] of Object.entries(params))url.searchParams.set(key,value);
    fitWindow(url);
    await win.loadURL(url.href);
  };
  Menu.setApplicationMenu(Menu.buildFromTemplate([
    {label:'AI Usage Monitor',submenu:[
      {label:'Workspace',accelerator:'CmdOrCtrl+1',click:()=>showSurface('workspace')},
      {label:'Desktop sidebar',accelerator:'CmdOrCtrl+2',click:()=>openRail()},
      {role:'quit'}
    ]}
  ]));
  win.autoHideMenuBar=true;win.menuBarVisible=false;
  const showSurface=async mode=>{
    if(quitting||!liveWindow(win))return;
    const request=++surfaceRequest;
    if(liveWindow(rail))rail.destroy();
    if(win.isMinimized())win.restore();
    await open(workspace,{mode});
    if(request===surfaceRequest&&!quitting&&liveWindow(win)&&(!trayTest||process.argv.includes('--dock-lifecycle-test'))){win.show();win.focus();}
  };
  if(profile&&!captureDir&&!settingsTest&&!usageTest&&!updateTest&&!dataTest&&!composedDir&&!validateImport){
    const macTrayIcon=platform==='darwin'?nativeImage.createFromPath(fileURLToPath(new URL('../../assets/MonitorTray.png',import.meta.url))):null;
    if(macTrayIcon)for(const scaleFactor of [2,3]){
      if(!macTrayIcon.getScaleFactors().includes(scaleFactor))macTrayIcon.addRepresentation({scaleFactor,buffer:await readFile(new URL('../../assets/MonitorTray@'+scaleFactor+'x.png',import.meta.url))});
    }
    const trayMark=macTrayIcon||fileURLToPath(new URL('../../assets/Monitor.ico',import.meta.url));
    if(macTrayIcon?.isEmpty())throw new Error('The tray icon is missing.');
    tray=new Tray(trayMark);tray.setToolTip('AI Usage Monitor');
    const choose=mode=>()=>{void showSurface(mode==='quick'?glanceMode:mode).catch(error=>console.error('Tray action failed:',error.message));};
    const zh=app.getLocale().startsWith('zh');
    tray.setContextMenu(Menu.buildFromTemplate([
      {label:zh?'打开工作台':'Open workspace',click:choose('workspace')},
      {label:zh?'桌面侧栏':'Desktop sidebar',click:()=>openRail()},
      {type:'separator'},{label:zh?'退出软件':'Quit',click:()=>app.quit()}
    ]));
    if(platform==='win32')tray.on('click',()=>openRail());
    if(platform==='darwin')trackWorkspaceDock(win,app.dock);
    win.on('close',event=>{if(!quitting){event.preventDefault();win.hide();}});
    app.on('second-instance',()=>choose('workspace')());
  }
  if(trayTest){
    if(process.argv.includes('--dock-lifecycle-test')){
      for(const side of edges){
        await showSurface('workspace');
        await openRail(side);
        const oldIndicator=indicator;
        if(win.isVisible()||!rail.isVisible())throw new Error('Sidebar did not take over');
        positionRail(false);
        for(let i=0;i<60&&!oldIndicator.isVisible();i++)await pause(32);
        if(rail.isVisible()||!oldIndicator.isVisible())throw new Error('Sidebar did not collapse: '+side);
        if(side==='bottom'){
          indicator.destroy();
          await pause(100);
          if(!rail.isVisible())throw new Error('Closed indicator stranded the hidden rail');
        }
        const previous=rail;
        await showSurface('workspace');
        if(!previous.isDestroyed()||!oldIndicator.isDestroyed()||!win.isVisible())throw new Error('Tray did not restore the workspace exclusively');
        const opening=openRail();
        await showSurface('workspace');
        await opening;
        if(liveWindow(rail)||!win.isVisible())throw new Error('Pending sidebar survived the workspace request');
      }
      await openRail('bottom');
      positionRail(false);
      await pause(100);
      console.log('Dock lifecycle: all four edges passed; quitting with collapsed sidebar');
      app.quit();return;
    }
    const modes=[];
    await showSurface('workspace');
    const initial=win.getBounds();
    for(const mode of ['quick','workspace','widget','workspace','quick','workspace']){
      await showSurface(mode);
      const [width]=win.getContentSize(),pinned=win.isAlwaysOnTop();
      const compact=mode!=='workspace';
      if((compact&&width>410)||(!compact&&width<700)||(pinned!==(mode==='widget')))throw new Error('Unexpected tray window geometry');
      const bounds=win.getBounds();
      if(!compact&&['width','height'].some(key=>Math.abs(bounds[key]-initial[key])>1))throw new Error('Workspace size changed: '+JSON.stringify({initial,bounds}));
      modes.push({mode,width,pinned,initial,bounds});
    }
    await new Promise(done=>process.stdout.write(JSON.stringify({nativeTray:!tray.isDestroyed(),modes})+'\n',done));
    app.quit();return;
  }
  if(dataTest){
    const result=await checkDataPages(open);
    await new Promise(done=>process.stdout.write(JSON.stringify(result)+'\n',done));
    app.quit();return;
  }
  if(updateTest){
    await open(workspace,{page:'settings'});
    const evidence=await win.webContents.executeJavaScript(`(async () => {
      const entry=document.querySelector('.update-settings [data-action=updates]');
      if(!entry||entry.disabled||entry.matches('.update-notice'))throw new Error('Unexpected initial update state');
      entry.click();
      const busy=document.querySelector('.update-settings [data-action=updates]');
      if(!busy.disabled||busy.getAttribute('aria-busy')!=='true')throw new Error('Update action did not become busy');
      const deadline=Date.now()+20000;
      while(!document.querySelector('dialog[open][data-update-result]')&&Date.now()<deadline)await new Promise(r=>setTimeout(r,75));
      const dialog=document.querySelector('dialog[open][data-update-result]');
      if(!dialog||dialog.querySelector('[data-action=downloadUpdate],[data-action=installUpdate]')||
        document.querySelector('.update-settings [data-action=updates]').disabled)throw new Error('Invalid update result or busy state');
      await new Promise(done=>requestAnimationFrame(()=>requestAnimationFrame(done)));
      return {state:dialog.dataset.updateResult,text:dialog.textContent.trim().replace(/\\s+/g,' '),installOffered:false};
    })()`);
    if(captureDir){
      await mkdir(captureDir,{recursive:true});
      const image=await win.webContents.capturePage(undefined,{stayHidden:true});
      if(image.isEmpty())throw new Error('Empty update capture');
      await writeFile(join(captureDir,'public-update-check.png'),image.toPNG());
    }
    await new Promise(done=>process.stdout.write(JSON.stringify(evidence)+'\n',done));
    app.quit();return;
  }
  if(usageTest){
    await open(workspace,{page:'overview'});
    const metrics=await win.webContents.executeJavaScript(`(async () => {
      const deadline=Date.now()+3500;
      while(!document.querySelector('.overview-grid')&&Date.now()<deadline)await new Promise(r=>setTimeout(r,25));
      if(!document.querySelector('.overview-grid'))throw new Error('Local usage view did not initialize');
      await Promise.all([document.fonts.ready,...[...document.images].map(image=>image.decode())]);
      await new Promise(done=>requestAnimationFrame(()=>requestAnimationFrame(done)));
      const meter=(id,span)=>document.querySelector('[data-provider-panel='+id+'] [data-quota='+span+'] [role=meter]')?.getAttribute('aria-valuenow')??null;
      const canvas=document.getElementById('usageChart');
      const chart=canvas&&window.Chart?.getChart(canvas);
      return {short:meter('codex','short'),week:meter('codex','week'),claude:meter('claude','week'),
        claudeContext:document.querySelector('[data-provider-panel=claude] [data-reading=context] dd')?.textContent??null,
        series:chart?.data.datasets.length??0,actions:Object.keys(window.aumDesktop||{}).sort(),
        chart:!!chart,points:chart?.data.datasets[0]?.data.filter(Number.isFinite).length??0,
        synthetic:!!document.querySelector('.footer-freshness')?.textContent.includes('14:32')};
    })()`);
    const known=usageTest!=='missing',dual=usageTest==='dual';
    if(metrics.short!==(known?'0':null)||metrics.week!==(known?'33':null)||
       metrics.chart!==known||metrics.points!==(known?3:0)||metrics.series!==(known?1:0)||
       metrics.claude!==(dual?'0':null)||metrics.claudeContext!==(dual?'24%':'—')||
       metrics.actions.filter(k=>k!=='connectClaude').join(',')!=='checkClaudeStatusline,checkUpdates,copyClaude,copyClaudeStatusline,fitContent,locateIntegration,openCodex,panelPin,quit,setReducedTransparency,showCodexPanel,showWorkspace'||metrics.synthetic)throw new Error('Unexpected local usage rendering: '+JSON.stringify(metrics));
    if(captureDir){
      await mkdir(captureDir,{recursive:true});
      await pause(250);
      const image=await win.webContents.capturePage(undefined,{stayHidden:true});
      if(image.isEmpty())throw new Error('Empty local usage capture');
      await writeFile(join(captureDir,'usage-'+usageTest+'.png'),image.toPNG());
    }
    await open(workspace,{page:'activity'});
    const activity=await win.webContents.executeJavaScript(`(async () => {
      const deadline=Date.now()+3500;
      while(!document.querySelector('.activity-table')&&Date.now()<deadline)await new Promise(r=>setTimeout(r,25));
      if(!document.querySelector('.activity-table'))throw new Error('Local activity did not initialize');
      const count=kind=>document.querySelectorAll('[data-observed-activity='+kind+']').length;
      const codex=count('daily-local-total'),claude=count('experimental-request');
      const filter=document.getElementById('platformFilter');
      filter.value='claude';filter.dispatchEvent(new Event('change',{bubbles:true}));
      return {codex,claude,filtered:count('experimental-request'),hiddenCodex:count('daily-local-total')===0};
    })()`);
    if(activity.codex!==(known?3:0)||activity.claude!==(dual?1:0)||activity.filtered!==activity.claude||!activity.hiddenCodex)
      throw new Error('Observed activity filtering failed: '+JSON.stringify(activity));
    let connection;
    if(collectorTest){
      await open(workspace,{page:'sources'});
      connection=await win.webContents.executeJavaScript(`(async () => {
        const deadline=Date.now()+3500;
        while(!document.querySelector('.platform-entry.codex')&&Date.now()<deadline)await new Promise(r=>setTimeout(r,20));
        return {phase:document.documentElement.dataset.collectorPhase,
          label:document.querySelector('.platform-entry.codex .provider-title p')?.textContent};
      })()`);
      if(connection.phase!==collectorTest||!connection.label)throw new Error('Collector state did not reach connection page: '+JSON.stringify(connection));
    }
    await new Promise(done=>process.stdout.write(JSON.stringify({usageTest,metrics,activity,connection,fixture:true})+'\n',done));
    app.quit();return;
  }
  if(legacyPath){
    const {readLegacyPreferences}=await import('./legacy.mjs');
    const imported=await readLegacyPreferences(resolve(legacyPath));
    await open(workspace);
    const key='aum-dual-v2-preferences';
    const wasEmpty=await win.webContents.executeJavaScript(`(() => {
      const key=${JSON.stringify(key)};
      if(localStorage.getItem(key)!==null)return false;
      localStorage.setItem(key,${JSON.stringify(JSON.stringify(imported))});
      return true;
    })()`);
    if(!wasEmpty)throw new Error('The selected profile already has settings; import would overwrite them.');
    win.webContents.session.flushStorageData();
    if(validateImport){
      await open(workspace,{page:'plans'});
      const selected=await win.webContents.executeJavaScript(`({
        plan:document.getElementById('planFamily')?.value,
        tier:document.getElementById('planTier')?.value,
        date:document.getElementById('renewalDate')?.value||document.getElementById('estimatedDate')?.textContent,
        language:document.documentElement.lang
      })`);
      if(selected.plan!==imported.plans.codex.plan||selected.tier!==imported.plans.codex.tier)throw new Error('Imported plan was not shown in the desktop UI.');
      await new Promise(done=>process.stdout.write(JSON.stringify({profile,selected,imported:true})+'\n',done));
      app.quit();return;
    }
    await open(workspace);
    win.show();return;
  }
  if(settingsTest){
    const result=await checkSavedPreferences(open);
    await new Promise(done=>process.stdout.write(JSON.stringify({settingsTest,profile,result})+'\n',done));
    app.quit();return;
  }
  if(composedDir){
    const helper=process.env.WIN_DEMO8_CAPTURE_EXE;
    if(platform!=='win32'||!helper)throw new Error('Windows desktop capture helper is required.');
    await mkdir(composedDir,{recursive:true});
    await open(workspace,{page:'display'});
    const underlay=new BrowserWindow({show:false,frame:false,focusable:false,skipTaskbar:true,webPreferences:{sandbox:true}});
    try{
      const original=win.getBounds();
      const workArea=screen.getDisplayMatching(original).workArea;
      const compact={width:Math.min(original.width,960,workArea.width-16),
        height:Math.min(original.height,650,workArea.height-16)};
      const candidates=[original,
        {...compact,x:workArea.x+8,y:workArea.y+8},
        {...compact,x:workArea.x+workArea.width-compact.width-8,y:workArea.y+workArea.height-compact.height-8}
      ];
      underlay.setAlwaysOnTop(true);
      win.setAlwaysOnTop(true,'screen-saver');
      await underlay.loadURL('data:text/html;charset=utf-8,<body style="margin:0;background:%23003f93">');
      const coastUrl=new URL('coast.jpg',workspace);
      const coast=(await readFile(resolveAsset(coastUrl))).toString('base64');
      const hwnd=win.getNativeWindowHandle().readBigUInt64LE().toString(16);
      const backingHwnd=underlay.getNativeWindowHandle().readBigUInt64LE().toString(16);
      const capture=sample=>JSON.parse(execFileSync(helper,[hwnd,backingHwnd,String(process.pid),join(composedDir,sample+'.png')],{encoding:'utf8',windowsHide:true,timeout:6000,stdio:['ignore','pipe','pipe']}));
      let pixels, bounds, lastOcclusion;
      for(const candidate of candidates){
        win.setBounds(candidate);
        underlay.setBounds(win.getBounds());
        underlay.setBackgroundColor('#003f93');
        underlay.showInactive();
        win.show();win.moveTop();win.focus();
        await pause(650);
        try{pixels={blue:capture('blue')};bounds=win.getBounds();break;}
        catch(error){
          if(!String(error.stderr).includes('The test window is occluded'))throw error;
          lastOcclusion=error;
        }
      }
      if(!pixels)throw lastOcclusion;
      for(const [sample,color] of [['green','#32844e'],['coast','#32844e'],['solid','#32844e']]){
        const bg=sample==='coast'?'<img src="data:image/jpeg;base64,'+coast+'" style="width:100vw;height:100vh;object-fit:cover;object-position:center 54%">':'';
        await underlay.loadURL('data:text/html;charset=utf-8,'+encodeURIComponent('<body style="margin:0;background:'+color+'">'+bg+'</body>'));
        underlay.setBackgroundColor(color);
        underlay.showInactive();
        if(sample==='solid'){win.setBackgroundMaterial('none');win.setBackgroundColor('#e7edef');}
        win.show();win.moveTop();win.focus();
        await pause(650);
        pixels[sample]=capture(sample);
      }
      const result=compositionCheck(pixels);
      await writeFile(join(composedDir,'composition.json'),JSON.stringify({version,bounds,pixels,materialReadback,result},null,2)+'\n');
      if(!result.passed)throw new Error('The visible surface did not distinguish both backdrops and the opaque control.');
    }finally{underlay.destroy();}
    app.quit();return;
  }
  if(!captureDir){
    const upgrade=platform==='darwin'&&process.argv.find(a=>a.startsWith('--aum-upgrade='));
    await open(workspace,upgrade?{mode:'workspace'}:{boot:'1'});if(!rail)win.show();
    if(upgrade){
      const {acknowledgeMacWorkspace}=await import('./workspace-ack.mjs');
      await acknowledgeMacWorkspace(upgrade,win,version);
    }
    void offerMacUpgrade().catch(()=>{});
    return;
  }
  await mkdir(captureDir,{recursive:true});
  const cases = [
    ...['overview','display','plans','activity','sources','settings','help','about'].map(page=>[page,workspace,{page}]),
    ...['quick','widget'].map(mode=>[mode,workspace,{mode}]),
    ...['new','upgrade','add'].map(intent=>['setup-'+intent,setup,{intent}])
  ];
  let displayCopy;
  const uiReview={};
  for(const [name,target,params] of cases){
    await open(target,params);
    const expected = name.startsWith('setup-') ? '.setup-stage' : '.sidebar-version';
    const result = await win.webContents.executeJavaScript(`new Promise((done, fail) => {
      const deadline = Date.now()+4000;
      const check = () => {
        const target = document.querySelector(${JSON.stringify(expected)});
        if(target){
          if(getComputedStyle(document.querySelector('.reviewbar')).display!=='none')return fail(new Error('Desktop shell CSS did not apply'));
          Promise.all([document.fonts.ready, ...[...document.images].map(image=>image.decode())])
            .then(()=>requestAnimationFrame(()=>requestAnimationFrame(()=>done(target.textContent))),fail);
        }
        else if(Date.now()>deadline) fail(new Error('Demo renderer did not initialize'));
        else setTimeout(check,30);
      };
      check();
    })`);
    if(!name.startsWith('setup-')&&!result.includes(version))throw new Error('Unexpected demo version');
    const image = await win.webContents.capturePage(undefined,{stayHidden:true});
    if(image.isEmpty())throw new Error('Empty renderer screenshot: '+name);
    await writeFile(join(captureDir,name+'.png'),image.toPNG());
    if(name==='overview'&&desktopRevision)uiReview.overview=await win.webContents.executeJavaScript(`(() => {
      const body=document.querySelector('.app-main[data-page=overview] .content-scroll');
      const provider=body.querySelector('.provider[data-presentation=overview]');
      const spacing=parseFloat(getComputedStyle(provider.querySelector('.provider-records')).marginTop);
      const titleGap=parseFloat(getComputedStyle(provider.querySelector('.provider-head')).marginBottom);
      if(spacing<12||titleGap<15||body.scrollHeight>body.clientHeight+2)
        throw new Error('Overview spacing or fitted height is incorrect');
      return {height:innerHeight,spacing,titleGap,scrolls:false};
    })()`);
    if(name==='sources')uiReview.refresh=await win.webContents.executeJavaScript(`(() => {
      const control=document.querySelector('.page-actions [data-action=refresh]');
      const before=control.getBoundingClientRect();
      control.click();
      const after=control.getBoundingClientRect();
      if(control.textContent.trim()||!control.querySelector('svg')||before.width!==after.width||before.height!==after.height)
        throw new Error('Icon-only refresh changed its contents or dimensions');
      return true;
    })()`);
    if(['quick','widget'].includes(name))uiReview[name]=await win.webContents.executeJavaScript(`(() => {
      const header=document.querySelector('.quick-window>header');
      const actions=[...header.querySelectorAll('button')].filter(button=>button.getClientRects().length);
      const boxes=actions.map(button=>button.getBoundingClientRect());
      const separated=boxes.every((box,index)=>box.top>=34&&box.right<=innerWidth&&(!index||box.left>=boxes[index-1].right));
      if(!separated||getComputedStyle(header).webkitAppRegion!=='drag'||
        actions.some(button=>getComputedStyle(button).webkitAppRegion!=='no-drag'))
        throw new Error('Compact title bar, drag handle or action bounds are invalid');
      return {top:header.getBoundingClientRect().top,actions:actions.length,separated};
    })()`);
    if(name==='settings')uiReview.glass=await win.webContents.executeJavaScript(`(() => {
      const stage=document.querySelector('.desktop-stage');
      const opacity=document.querySelector('#glassTransparency'),blur=document.querySelector('#glassBlur');
      const set=(input,value)=>{input.value=value;input.dispatchEvent(new Event('input',{bubbles:true}));};
      const original=[opacity.value,blur.value];
      if(document.documentElement.dataset.buildRevision&&!document.documentElement.hasAttribute('data-reference-scene')){
        const pane=document.querySelector('.app-main');
        set(opacity,'20');const low=getComputedStyle(pane).backgroundColor;
        set(opacity,'65');const high=getComputedStyle(pane).backgroundColor;
        set(opacity,original[0]);
        if(getComputedStyle(stage,'::before').content!=='none'||blur.getClientRects().length||
          (!opacity.disabled&&low===high))throw new Error('Native material settings still use a simulated layer');
        return {simulatedArtwork:false,controlled:'content tint',low,high};
      }
      set(opacity,'20');set(blur,'12');
      const low=getComputedStyle(stage,'::before');
      const lowOpacity=Number(low.opacity),lowFilter=low.filter;
      set(opacity,'65');set(blur,'35');
      const high=getComputedStyle(stage,'::before');
      const highOpacity=Number(high.opacity),highFilter=high.filter;
      set(opacity,original[0]);set(blur,original[1]);
      if(document.documentElement.hasAttribute('data-reference-scene'))return 'reference-scene';
      if(!document.documentElement.matches('[data-transparency=reduced]')&&
        (highOpacity<=lowOpacity||!lowFilter.includes('12px')||!highFilter.includes('35px')))
        throw new Error('Glass sliders did not change opacity and blur');
      return {lowOpacity,highOpacity,lowFilter,highFilter};
    })()`);
    if(name==='display'){
      displayCopy=await win.webContents.executeJavaScript(`(() => {
        const $=s=>document.querySelector(s);
        const click=s=>{const target=$(s);if(!target)throw new Error('Missing control: '+s);target.click();};
        const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
        const saved=()=>JSON.parse(localStorage.getItem('aum-demo8-sample-dual')).fields;
        click('#copyFields');
        const confirm='[data-action=confirmCopyFields]';
        if(!$(confirm)?.disabled)throw new Error('Copy allowed without a destination');
        click('[data-copy-scope=quick]');
        if($(confirm)?.disabled)throw new Error('Copy remains disabled with a destination');
        click(confirm);
        const copied=saved();
        if(!same(copied.codex.quick,copied.codex.host)||!$('.copy-receipt'))throw new Error('Copy did not update the selected scope');
        click('[data-action=undoCopy]');
        const restored=saved();
        if($('.copy-receipt')||same(copied.codex.quick,restored.codex.quick)||
          !same(copied.codex.host,restored.codex.host)||!same(copied.codex.workspace,restored.codex.workspace)||
          !same(copied.claude,restored.claude))throw new Error('Undo did not restore only the selected destination');
        return {destinationRequired:true,copiedCount:copied.codex.quick.length,restoredCount:restored.codex.quick.length,otherFieldsUnchanged:true};
      })()`);
    }
  }
  await writeFile(join(captureDir,'evidence.json'), JSON.stringify({version,platform,arch:process.arch,materialRequested:material,materialReadback,capture:reference?'reference-scene-renderer-only':'renderer-only',cases:cases.map(([name])=>name),displayCopy,uiReview},null,2)+'\n');
  app.quit();
}
const localBuild=installedShell&&profile==='local';
const activeBuildPath=join(scratch,'active-build.json');
if(profile&&!app.requestSingleInstanceLock()){
  let sameBuild=false;
  if(localBuild)try{
    const active=JSON.parse(readFileSync(activeBuildPath,'utf8'));
    if(Number.isSafeInteger(active.pid)&&active.pid>0&&active.version===version){
      process.kill(active.pid,0);
      sameBuild=true;
    }
  }catch{}
  if(localBuild&&!sameBuild)app.whenReady().then(()=>{
    const zh=app.getLocale().startsWith('zh');
    dialog.showErrorBox('AI Usage Monitor '+version,zh?
      '已有一个监测器进程占用本地设置。请从托盘菜单退出旧版，再打开新版本。不需要关闭 Codex。':
      'Another monitor is using these settings. Quit it from the tray, then open the new version. Codex can stay open.');
    app.exit(2);
  });
  else app.exit(2);
}else{
  if(localBuild)try{
    writeFileSync(activeBuildPath,JSON.stringify({version,pid:process.pid}),{mode:0o600});
    app.once('quit',()=>{try{unlinkSync(activeBuildPath);}catch{}});
  }catch{}
  app.whenReady().then(start).catch(error=>{console.error(error);app.exit(1);});
}
app.on('before-quit',()=>{quitting=true;});
app.on('window-all-closed',()=>app.quit());
