import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const repo='kefen/codex-quota-sidebar';
const token=process.env.GITHUB_TOKEN,commit=process.env.GITHUB_SHA;
if(!token||process.env.GITHUB_REPOSITORY!==repo||process.env.GITHUB_REF!=='refs/heads/main'||!/^[a-f0-9]{40}$/.test(commit||''))throw Error('Expected authorized main-branch workflow');
const accepted=JSON.parse(await readFile('docs/releases/accepted-ui-fixes.json','utf8'));
const versions=JSON.parse(await readFile('versions.json','utf8'));
const chrome=JSON.parse(await readFile('browser/manifest.json','utf8')).version;
if(accepted.windows!=='0.13.1'||accepted.macos!=='0.5.1-alpha.1'||accepted.chrome!=='0.4.1'||accepted.publicReleaseAuthorized!==true||accepted.verificationRequired!==true)throw Error('Not the authorized release set');
if(versions.windows!==accepted.windows||versions.macos!==accepted.macos||chrome!==accepted.chrome)throw Error('Version mismatch');
const source='Codex-Quota-Sidebar-source-windows-'+versions.windows+'-macos-'+versions.macos+'.zip';
const macSource='Codex-Quota-Sidebar-macOS-'+versions.macos+'-source.zip';
await writeFile('dist/'+macSource,await readFile('dist/'+source));
const common='Native readability and resizing fixes: complete localized actions, clearer text and DPI-aware icons, connection feedback and protected settings. Desktop manual update checks are in About; a header notice appears only for a verified newer release. Startup and periodic checks are polling, not a real-time push service. Valid up-to-date results remain distinct from network and verification failures. Plan detection can briefly open the official usage menu to read a strict quota-source label, then restore the menu it opened. Manual corrections, specific tiers and dates stay protected; unsupported labels remain unknown. Mac adds native calendar selection and immediate month/year renewal estimates. All eleven choices and three languages retained. Windows remains unsigned. Mac remains ad-hoc signed and unnotarized. Never disable system protections.';
const sets=[
 {tag:'windows/v'+versions.windows,title:'Windows '+versions.windows+' / KEFEN',prerelease:false,files:['Codex-Quota-Sidebar-Windows-'+versions.windows+'-x64-Setup.exe',source],note:common+' Windows 10/11 x64. Unsigned installer; upgrade in the same folder to preserve settings. This is a follow-up to the user-accepted Windows baseline.'},
 {tag:'chrome/v'+chrome,title:'Chrome '+chrome+' / KEFEN',prerelease:true,files:['Codex-Quota-Sidebar-Chrome-'+chrome+'.zip'],note:common+' Experimental MV3 companion, not a Web Store listing. Requires the desktop monitor and exact extension-ID native-host registration. Real-profile acceptance pending.'},
 {tag:'macos/v'+versions.macos,title:'macOS '+versions.macos+' / Apple Silicon and Intel',prerelease:true,files:['Codex-Quota-Sidebar-macOS-'+versions.macos+'-arm64-unsigned-test.dmg','Codex-Quota-Sidebar-macOS-'+versions.macos+'-x86_64-unsigned-test.dmg',macSource],note:common+' Apple Silicon: arm64. Intel: x86_64. macOS 13.5+, compatible official client required. Quit the old companion, drag the app to Applications and replace, eject DMG, launch from Finder > Applications; optionally Keep in Dock. READ-ME-FIRST.html in the DMG provides three-language security approval guidance. Ad-hoc signed only, NOT Developer ID signed or notarized. Do not disable Gatekeeper. Prior Apple Silicon live connection user-confirmed; Intel live-account acceptance pending. No silent Codex restart.'}
];
async function request(path,method='GET',data){
 const response=await fetch('https://api.github.com/repos/'+repo+path,{method,headers:{Authorization:'Bearer '+token,Accept:'application/vnd.github+json','Content-Type':'application/json'},body:data?JSON.stringify(data):undefined,signal:AbortSignal.timeout(30000)});
 if(response.status===404&&method==='GET')return null;
 if(!response.ok)throw Error('GitHub API '+response.status+' '+method+' '+path);
 return response.status===204?null:response.json();
}
const notes=JSON.parse(await readFile('docs/releases/notes-ui-fixes.json','utf8'));
const localizedNotes=Object.entries({'English':'en','简体中文':'zh-CN','繁體中文':'zh-TW'}).map(([heading,locale])=>'## '+heading+'\n'+notes[locale].map((line,i)=>(i+1)+'. '+line).join('\n')).join('\n\n');
const published=[];
for(const set of sets){
 const files=await Promise.all(set.files.map(async name=>{const bytes=await readFile('dist/'+name);return {name,bytes,digest:'sha256:'+createHash('sha256').update(bytes).digest('hex')};}));
 const sums=files.map(f=>f.digest.slice(7)+'  '+f.name).join('\n')+'\n';
 const sumName='SHA256SUMS-'+set.tag.replaceAll('/','-')+'.txt';
 await writeFile('dist/'+sumName,sums);
 files.push({name:sumName,bytes:Buffer.from(sums),digest:'sha256:'+createHash('sha256').update(sums).digest('hex')});
 const body=set.note+'\n\n'+localizedNotes+'\n\nSource commit: '+commit+'\n\n[Illustrated guide](https://github.com/'+repo+'/blob/'+commit+'/docs/USER-GUIDE.md) | [Security](https://github.com/'+repo+'/blob/'+commit+'/SECURITY.md)\n\nArtifacts are built from this commit by GitHub Actions. Checksums are attached. Unofficial; not affiliated with OpenAI. Author: KEFEN.';
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
 published.push({tag:set.tag,id:release.id,files:files.map(f=>({name:f.name,digest:f.digest}))});
 console.log('Verified published '+release.html_url);
}
// Historical Releases, assets, commits and tags are deliberately retained.
for(const item of published){const release=await request('/releases/tags/'+encodeURIComponent(item.tag));if(release?.draft||!item.files.every(f=>release.assets.some(a=>a.name===f.name&&a.digest===f.digest)))throw Error('Published asset verification failed');}


