import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {sign,createHash} from 'node:crypto';
import {join} from 'node:path';
import {validateAsset,verifyFeed} from '../src/update.mjs';
const versions=JSON.parse(await readFile('versions.json','utf8'));
const chrome=JSON.parse(await readFile('browser/manifest.json','utf8')).version;
const folder=process.env.CQS_SIGNING_DIRECTORY;if(!folder)throw Error('CQS_SIGNING_DIRECTORY must point outside the repository');
const windowsOnly=process.env.CQS_RELEASE_SCOPE==='windows-only';
const macOnly=process.env.CQS_RELEASE_SCOPE==='mac-only';
const publicKey=await readFile('src/update-public-key.pem','utf8');
const baseline=windowsOnly||macOnly?verifyFeed(JSON.parse(await readFile('docs/updates/latest.json','utf8')),publicKey):null;
if(windowsOnly&&(baseline.chrome!==chrome||baseline.releases['macos-arm64']?.version!==versions.macos||baseline.releases['macos-x64']?.version!==versions.macos))throw Error('Unchanged platform versions differ from verified baseline');
const releases=baseline?{...baseline.releases}:{};
const notesFile=macOnly?(versions.macos==='0.5.2-alpha.1'?'notes-monthly-tokens':'notes-mac-updater'):
 windowsOnly?(versions.windows==='0.13.5'?'notes-monthly-tokens':'notes-windows-responsive'):'notes-ui-fixes';
const notesByLocale=JSON.parse(await readFile('docs/releases/'+notesFile+'.json','utf8'));
const notes=notesByLocale.en.map((line,i)=>(i+1)+'. '+line).join('\n');
for(const [target,version,name,tag] of [
 ['windows-x64',versions.windows,'AI-Quota-Board-Windows-'+versions.windows+'-x64-Setup.exe','windows/v'+versions.windows],
 ['macos-arm64',versions.macos,'AI-Quota-Board-macOS-'+versions.macos+'-arm64-unsigned-test.dmg','macos/v'+versions.macos],
 ['macos-x64',versions.macos,'AI-Quota-Board-macOS-'+versions.macos+'-x86_64-unsigned-test.dmg','macos/v'+versions.macos]
]){
 if(windowsOnly&&target!=='windows-x64')continue;
 if(macOnly&&target==='windows-x64')continue;
 const bytes=await readFile(join(process.env.CQS_ARTIFACT_DIRECTORY||'dist',name));
 releases[target]=validateAsset({version,size:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex'),url:'https://github.com/kefen/AI-Quota-Board/releases/download/'+encodeURIComponent(tag)+'/'+name,notes,notesByLocale});
}
const payload=Buffer.from(JSON.stringify({schema:1,issuedAt:Date.now(),expiresAt:Date.now()+180*86400000,releases,chrome:baseline?.chrome??chrome}));
const privateKey=await readFile(join(folder,'private.pem'),'utf8');
const envelope={payload:payload.toString('base64'),signature:sign(null,payload,privateKey).toString('base64')};
verifyFeed(envelope,publicKey);
await mkdir('docs/updates',{recursive:true});
await writeFile('docs/updates/latest.json',JSON.stringify(envelope,null,2)+'\n');
console.log('Signed public update feed; no private key was exported.');
