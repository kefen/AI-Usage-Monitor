import {mkdir,readFile,writeFile,chmod,unlink} from 'node:fs/promises';
import {homedir} from 'node:os';import {join} from 'node:path';import {fileURLToPath} from 'node:url';
if(process.platform!=='darwin')throw new Error('Run on macOS');
const id=process.argv[2];if(!/^[a-p]{32}$/.test(id||''))throw new Error('Provide the exact 32-character Chrome extension ID');
const host=fileURLToPath(new URL('./native-host.command',import.meta.url));
const dir=join(homedir(),'Library/Application Support/Google/Chrome/NativeMessagingHosts');
const path=join(dir,'org.kefen.codex_quota_sidebar.json');
let prior;try{prior=JSON.parse(await readFile(path,'utf8'));}catch(e){if(e.code!=='ENOENT')throw e;}
if(prior&&prior.path!==host)throw new Error('Registration belongs to another installation');
if(process.argv.includes('--remove')){if(prior)await unlink(path);}
else{await mkdir(dir,{recursive:true});await mkdir(new URL('../.runtime/',import.meta.url),{recursive:true});await chmod(host,0o700);await writeFile(new URL('../.runtime/browser-host.json',import.meta.url),JSON.stringify({extensionId:id}),{mode:0o600});await writeFile(path,JSON.stringify({name:'org.kefen.codex_quota_sidebar',description:'Read-only quota snapshot by KEFEN',path:host,type:'stdio',allowed_origins:[`chrome-extension://${id}/`]}),{mode:0o600});}
