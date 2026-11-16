import {generateKeyPairSync} from 'node:crypto';
import {mkdir,writeFile,access} from 'node:fs/promises';
import {homedir} from 'node:os';
import {join} from 'node:path';
const folder=process.env.CQS_SIGNING_DIRECTORY||join(homedir(),'.codex','cqs-release-signing');
await mkdir(folder,{recursive:true});
const path=join(folder,'private.pem');
try{await access(path);throw Error('Signing key already exists; will not overwrite');}catch(e){if(e.code!=='ENOENT')throw e;}
const {publicKey,privateKey}=generateKeyPairSync('ed25519');
await writeFile(path,privateKey.export({type:'pkcs8',format:'pem'}),{flag:'wx',mode:0o600});
await writeFile('src/update-public-key.pem',publicKey.export({type:'spki',format:'pem'}),{flag:'wx'});
console.log('Created public trust anchor; private key stays outside the repository. Back up securely.');
