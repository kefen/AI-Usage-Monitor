import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {sign,createHash} from 'node:crypto';
import {join} from 'node:path';
import {validateAsset} from '../src/update.mjs';
const versions=JSON.parse(await readFile('versions.json','utf8'));
const chrome=JSON.parse(await readFile('browser/manifest.json','utf8')).version;
const folder=process.env.CQS_SIGNING_DIRECTORY;if(!folder)throw Error('CQS_SIGNING_DIRECTORY must point outside the repository');
const releases={};
const notesByLocale=JSON.parse(await readFile('docs/releases/notes-ui-fixes.json','utf8'));
const notes=notesByLocale.en.map((line,i)=>(i+1)+'. '+line).join('\n');
for(const [target,version,name,tag] of [
 ['windows-x64',versions.windows,'Codex-Quota-Sidebar-Windows-'+versions.windows+'-x64-Setup.exe','windows/v'+versions.windows],
 ['macos-arm64',versions.macos,'Codex-Quota-Sidebar-macOS-'+versions.macos+'-arm64-unsigned-test.dmg','macos/v'+versions.macos],
 ['macos-x64',versions.macos,'Codex-Quota-Sidebar-macOS-'+versions.macos+'-x86_64-unsigned-test.dmg','macos/v'+versions.macos]
]){
 const bytes=await readFile(join(process.env.CQS_ARTIFACT_DIRECTORY||'dist',name));
 releases[target]=validateAsset({version,size:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex'),url:'https://github.com/kefen/codex-quota-sidebar/releases/download/'+encodeURIComponent(tag)+'/'+name,notes,notesByLocale});
}
const payload=Buffer.from(JSON.stringify({schema:1,issuedAt:Date.now(),expiresAt:Date.now()+180*86400000,releases,chrome}));
const privateKey=await readFile(join(folder,'private.pem'),'utf8');
await mkdir('docs/updates',{recursive:true});
await writeFile('docs/updates/latest.json',JSON.stringify({payload:payload.toString('base64'),signature:sign(null,payload,privateKey).toString('base64')},null,2)+'\n');
console.log('Signed public update feed; no private key was exported.');
