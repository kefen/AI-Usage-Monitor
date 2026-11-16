import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const repo='kefen/codex-quota-sidebar';
const token=process.env.GITHUB_TOKEN,commit=process.env.GITHUB_SHA;
if(!token||process.env.GITHUB_REPOSITORY!==repo||process.env.GITHUB_REF!=='refs/heads/main'||!/^[a-f0-9]{40}$/.test(commit||''))throw Error('Expected authorized main-branch workflow');
const accepted=JSON.parse(await readFile('docs/releases/accepted-0.12.json','utf8'));
const versions=JSON.parse(await readFile('versions.json','utf8'));
const chrome=JSON.parse(await readFile('browser/manifest.json','utf8')).version;
if(accepted.windows!=='0.12.3'||accepted.macos!=='0.4.1-alpha.1'||accepted.chrome!=='0.3.1'||accepted.windowsAccepted!==true||accepted.publicReleaseAuthorized!==true||accepted.macAccountAccepted!==false||accepted.browserProfileAccepted!==false)throw Error('Not the authorized release set');
if(versions.windows!==accepted.windows||versions.macos!==accepted.macos||chrome!==accepted.chrome)throw Error('Version mismatch');
const source='Codex-Quota-Sidebar-source-windows-'+versions.windows+'-macos-'+versions.macos+'.zip';
const sets=[
 {tag:'windows/v'+versions.windows,title:'Windows '+versions.windows+' / KEFEN',prerelease:false,files:['Codex-Quota-Sidebar-Windows-'+versions.windows+'-x64-Setup.exe',source],note:'Stable Windows 10/11 x64 release. User accepted 0.12.3 UI on 2026-11-16. Compact same-window settings, three languages, clear save feedback, official-button collision protection, English desktop shortcut. Unsigned installer: verify origin and checksums. Upgrade in the existing folder to preserve settings.'},
 {tag:'chrome/v'+chrome,title:'Chrome '+chrome+' / KEFEN',prerelease:true,files:['Codex-Quota-Sidebar-Chrome-'+chrome+'.zip'],note:'Experimental Chrome MV3 companion. Three languages, same-panel navigation, local display preferences, sanitized diagnostics and retained keyboard focus. Requires a running desktop monitor and exact extension-ID native-host registration. Not a Chrome Web Store listing. Automated tests use a mocked native bridge; real-profile acceptance pending.'},
 {tag:'macos/v'+versions.macos,title:'macOS '+versions.macos+' / Experimental unsigned installers',prerelease:true,files:['Codex-Quota-Sidebar-macOS-'+versions.macos+'-arm64-unsigned-test.dmg','Codex-Quota-Sidebar-macOS-'+versions.macos+'-x86_64-unsigned-test.dmg'],note:'Experimental native DMGs for Apple Silicon and Intel, macOS 13.5+. Drag the app to Applications. Built and UI-tested on both native architectures in Actions. Ad-hoc signed only, NOT Developer ID signed or notarized. Official publisher was verified from the official distribution; no real-account connection acceptance on either architecture. The audited official download is ARM-only: Intel requires a separately compatible official client. The Intel companion cannot run an ARM-only official client. Settings/backup/help/about stay in one window. Do not disable Gatekeeper.'}
];
async function request(path,method='GET',data){
 const response=await fetch('https://api.github.com/repos/'+repo+path,{method,headers:{Authorization:'Bearer '+token,Accept:'application/vnd.github+json','Content-Type':'application/json'},body:data?JSON.stringify(data):undefined,signal:AbortSignal.timeout(30000)});
 if(response.status===404&&method==='GET')return null;
 if(!response.ok)throw Error('GitHub API '+response.status+' '+method+' '+path);
 return response.json();
}
for(const set of sets){
 const files=await Promise.all(set.files.map(async name=>{const bytes=await readFile('dist/'+name);return {name,bytes,digest:'sha256:'+createHash('sha256').update(bytes).digest('hex')};}));
 const sums=files.map(f=>f.digest.slice(7)+'  '+f.name).join('\n')+'\n';
 const sumName='SHA256SUMS-'+set.tag.replaceAll('/','-')+'.txt';
 await writeFile('dist/'+sumName,sums);
 files.push({name:sumName,bytes:Buffer.from(sums),digest:'sha256:'+createHash('sha256').update(sums).digest('hex')});
 const body=set.note+'\n\nSource commit: '+commit+'\n\n[Illustrated guide](https://github.com/'+repo+'/blob/'+commit+'/docs/USER-GUIDE.md) | [Security](https://github.com/'+repo+'/blob/'+commit+'/SECURITY.md)\n\nArtifacts are built from this commit by GitHub Actions. Checksums are attached. Unofficial; not affiliated with OpenAI. Author: KEFEN.';
 let release=await request('/releases/tags/'+encodeURIComponent(set.tag));
 if(!release)release=await request('/releases','POST',{tag_name:set.tag,target_commitish:commit,name:set.title,body,prerelease:set.prerelease,draft:true});
 if(release.name!==set.title||release.prerelease!==set.prerelease)throw Error('Existing release differs; will not overwrite '+set.tag);
 for(const file of files){
   const prior=release.assets.find(a=>a.name===file.name);
   if(prior){if(prior.digest!==file.digest)throw Error('Existing asset differs: '+file.name);continue;}
   const upload=await fetch(release.upload_url.split('{')[0]+'?name='+encodeURIComponent(file.name),{method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/octet-stream'},body:file.bytes,signal:AbortSignal.timeout(180000)});
   if(!upload.ok)throw Error('Asset upload '+upload.status+' '+file.name);
   const asset=await upload.json();if(asset.digest!==file.digest)throw Error('Uploaded digest mismatch '+file.name);
 }
 if(release.draft)release=await request('/releases/'+release.id,'PATCH',{draft:false});
 console.log('Verified published '+release.html_url);
}
