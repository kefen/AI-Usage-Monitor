import {readFile,writeFile} from 'node:fs/promises';
const catalog=JSON.parse(await readFile(new URL('../ui/strings.json',import.meta.url),'utf8'));
await writeFile(new URL('../browser/strings.js',import.meta.url),'// Generated from ui/strings.json.\nglobalThis.CQS_STRINGS='+JSON.stringify(catalog)+';\n');
