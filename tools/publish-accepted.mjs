import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const repo='kefen/codex-quota-sidebar';
const token=process.env.GITHUB_TOKEN,commit=process.env.GITHUB_SHA;
if(!token||process.env.GITHUB_REPOSITORY!==repo||!/^[a-f0-9]{40}$/.test(commit||''))throw Error('Expected authenticated repository workflow');
const accepted=JSON.parse(await readFile('docs/releases/accepted-0.11.json','utf8'));
const versions=JSON.parse(await readFile('versions.json','utf8'));
const chrome=JSON.parse(await readFile('browser/manifest.json','utf8')).version;
if(accepted.windows!=='0.11.1-beta.1'||accepted.macos!=='0.3.1-alpha.1'||accepted.chrome!=='0.2.1'||!accepted.brandingOnlyPatch||accepted.basedOnAcceptedWindows!=='0.11.0-beta.1'||!accepted.macosSourceOnly||!accepted.prerelease)throw Error('Not the explicitly reviewed branding release set');
if(versions.windows!==accepted.windows||versions.macos!==accepted.macos||chrome!==accepted.chrome)throw Error('Version mismatch');
const source='Codex-Quota-Sidebar-source-windows-'+versions.windows+'-macos-'+versions.macos+'.zip';
const sets=[
 {tag:'windows/v'+versions.windows,title:'Windows '+versions.windows+' / KEFEN',files:['Codex-Quota-Sidebar-Windows-'+versions.windows+'-x64-Setup.exe',source],note:'KEFEN branding correction based on user-accepted Windows '+accepted.basedOnAcceptedWindows+'. Automated checks rerun; this patch is not separately user-accepted. Browser users must unregister the earlier host before upgrading, then register the new KEFEN host after updating both desktop and extension. Unsigned x64 beta.'},
 {tag:'chrome/v'+chrome,title:'Chrome '+chrome+' / KEFEN',files:['Codex-Quota-Sidebar-Chrome-'+chrome+'.zip'],note:'KEFEN branding correction. Native host is now org.kefen.codex_quota_sidebar. Upgrade the desktop tool too and rerun native-host registration with the exact extension ID. See the browser upgrade guide. Experimental; not a Chrome Web Store release.'},
 {tag:'macos/v'+versions.macos,title:'macOS '+versions.macos+' / SOURCE ONLY',files:[source],note:'Apple Silicon experimental SOURCE ONLY. No installable Mac binary. AppKit compilation, official Team ID verification and live Mac acceptance are outstanding. Fail-closed trust checks remain enabled.'}
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
 if(!release)release=await request('/releases','POST',{tag_name:set.tag,target_commitish:commit,name:set.title,body,prerelease:true,draft:true});
 if(release.name!==set.title||!release.prerelease)throw Error('Existing release differs; will not overwrite '+set.tag);
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
