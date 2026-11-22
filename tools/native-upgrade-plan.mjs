import {readFile, appendFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {newer, verifyFeed} from '../src/update.mjs';
export function previousRelease(releases, platform, target, requiredAssets) {
  const prefix=platform+'/v';
  const candidates=releases.filter(r=>!r.draft&&r.tag_name.startsWith(prefix))
    .map(r=>({...r,version:r.tag_name.slice(prefix.length)})).filter(r=>newer(target,r.version))
    .sort((a,b)=>newer(a.version,b.version)?-1:newer(b.version,a.version)?1:0);
  const prior=candidates[0];
  if(!prior)throw Error('No public previous version: '+platform);
  for(const name of requiredAssets(prior.version))if(!prior.assets.some(a=>a.name===name&&/^sha256:[a-f0-9]{64}$/.test(a.digest)))throw Error('Previous public package missing or unverifiable: '+name);
  return prior.version;
}
async function plan(){
  const response=await fetch('https://raw.githubusercontent.com/kefen/AI-Usage-Monitor/main/docs/updates/v2.json');
  if(!response.ok)throw Error('Production feed unavailable');
  const feed=verifyFeed(await response.json(),await readFile('src/update-public-key.pem','utf8'));
  const expected=JSON.parse(await readFile('versions.json','utf8'));
  const win=feed.releases['windows-x64'].version,mac=feed.releases['macos-arm64'].version;
  if(win!==expected.windows||mac!==expected.macos||feed.releases['macos-x64'].version!==mac)throw Error('Production feed and checkout disagree; never use a fixture instead');
  const releases=[];
  for(let page=1;;page++){
    const r=await fetch(`https://api.github.com/repos/kefen/AI-Usage-Monitor/releases?per_page=100&page=${page}`,{headers:{Authorization:'Bearer '+process.env.GH_TOKEN,'User-Agent':'AI-Usage-Monitor-Release-Acceptance'}});
    if(!r.ok)throw Error('Cannot read public release history');
    const rows=await r.json();releases.push(...rows);if(rows.length<100)break;
  }
  const values={windows_target:win,windows_prior:previousRelease(releases,'windows',win,v=>[`AI-Usage-Monitor-Windows-${v}-x64-Setup.exe`]),mac_target:mac,mac_prior:previousRelease(releases,'macos',mac,v=>['arm64','x86_64'].map(a=>`AI-Usage-Monitor-macOS-${v}-${a}-unsigned-test.dmg`))};
  await appendFile(process.env.GITHUB_OUTPUT,Object.entries(values).map(([k,v])=>`${k}=${v}\n`).join(''));console.log(JSON.stringify(values,null,2));
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)await plan();
