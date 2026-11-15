import {existsSync} from 'node:fs';
const stop=process.argv[process.argv.indexOf('--stop-file')+1];
console.log('Fixture monitor started; no account or Codex process touched.');
const timer=setInterval(()=>{if(existsSync(stop))clearInterval(timer);},100);
