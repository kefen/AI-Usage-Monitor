import {readFileSync} from 'node:fs';
const versions=JSON.parse(readFileSync(new URL('../versions.json',import.meta.url),'utf8'));
export const version=versions[process.platform==='darwin'?'macos':'windows'];
