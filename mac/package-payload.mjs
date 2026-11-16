import {readFile,mkdir,copyFile} from 'node:fs/promises';
import {dirname,resolve} from 'node:path';
const output=resolve(process.argv[2]);
const files=JSON.parse(await readFile('source-files.json','utf8')).filter(p=>/^(src\/|ui\/strings\.json$|assets\/(cqs-128|tray-template)\.png$|mac\/(launch\.mjs|trust\.json)$|browser\/(Register-Mac\.mjs|native-host\.mjs|native-host\.command)$|versions\.json$|LICENSE$)/.test(p));
for(const name of files){if(name.includes('..'))throw Error('Unsafe payload path');const target=resolve(output,name);await mkdir(dirname(target),{recursive:true});await copyFile(name,target);}
