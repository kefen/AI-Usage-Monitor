import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const repo='kefen/codex-quota-sidebar';
const token=process.env.GITHUB_TOKEN,commit=process.env.GITHUB_SHA;
if(!token||process.env.GITHUB_REPOSITORY!==repo||process.env.GITHUB_REF!=='refs/heads/main'||!/^[a-f0-9]{40}$/.test(commit||''))throw Error('Expected authorized main-branch workflow');
const accepted=JSON.parse(await readFile('docs/releases/accepted-0.12.json','utf8'));
const versions=JSON.parse(await readFile('versions.json','utf8'));
const chrome=JSON.parse(await readFile('browser/manifest.json','utf8')).version;
if(accepted.windows!=='0.12.4'||accepted.macos!=='0.4.6-alpha.1'||accepted.chrome!=='0.3.2'||accepted.windowsAccepted!==true||accepted.publicReleaseAuthorized!==true||accepted.macAccountAccepted!==true||accepted.browserProfileAccepted!==false)throw Error('Not the authorized release set');
if(versions.windows!==accepted.windows||versions.macos!==accepted.macos||chrome!==accepted.chrome)throw Error('Version mismatch');
const source='Codex-Quota-Sidebar-source-windows-'+versions.windows+'-macos-'+versions.macos+'.zip';
const macSource='Codex-Quota-Sidebar-macOS-'+versions.macos+'-source.zip';
await writeFile('dist/'+macSource,await readFile('dist/'+source));
const common='Monthly daily average uses returned records in the current calendar month (missing days excluded); weekly calculation unchanged. Yesterday hides its numeric date and follows local midnight; older data remains dated. Read-only credit balance and available quota reset count are selectable. No purchase or reset action is performed. Three interface languages retained.';
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
const published=[];
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
 published.push({tag:set.tag,id:release.id,files:files.map(f=>({name:f.name,digest:f.digest}))});
 console.log('Verified published '+release.html_url);
}
// Destructive cleanup is explicitly scoped to the user-approved old release list.
for(const item of published){const release=await request('/releases/tags/'+encodeURIComponent(item.tag));if(release?.draft||!item.files.every(f=>release.assets.some(a=>a.name===f.name&&a.digest===f.digest)))throw Error('Published asset verification failed');}
if(accepted.deletePriorReleasesAfterVerification===true&&published.length===3){
 const oldTags=["windows/v0.12.3","macos/v0.4.1-alpha.1","chrome/v0.3.1","windows/v0.11.1-beta.1","windows/v0.11.0-beta.1","macos/v0.3.1-alpha.1","macos/v0.3.0-alpha.1","chrome/v0.2.1","chrome/v0.2.0"];
 for(const tag of oldTags){if(sets.some(s=>s.tag===tag))throw Error('Refuse to delete current release');const old=await request('/releases/tags/'+encodeURIComponent(tag));if(old)await request('/releases/'+old.id,'DELETE');}
 console.log('Removed approved previous Releases/assets; Git tags and commits retained.');
}

