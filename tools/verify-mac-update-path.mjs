import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdtemp, readFile, copyFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';

const [priorDir, version, arch] = process.argv.slice(2);
assert.equal(process.platform, 'darwin');
assert.equal(process.arch, arch);
assert.ok(['x64', 'arm64'].includes(arch));
const prior = resolve(priorDir);
const current = JSON.parse(await readFile(join(prior, 'versions.json'))).macos;
const scratch = await mkdtemp(join(tmpdir(), 'aim-mac-update-'));
try {
  await copyFile(join(prior, 'versions.json'), join(scratch, 'versions.json'));
  for (const operation of ['auto', 'check', 'download']) {
    const result = JSON.parse(execFileSync(process.execPath,
      [join(prior, 'src/update.mjs'), operation, scratch], {encoding: 'utf8', timeout: 330000}));
    assert.equal(result.current, current);
    assert.equal(result.version, version, `${arch}: ${current} saw ${result.version}, expected ${version}`);
    assert.equal(result.available, true);
    if (operation === 'download') assert.equal(result.ready, true);
  }
  const response = await fetch('https://api.github.com/repos/kefen/AI-Usage-Monitor/releases/tags/' +
    encodeURIComponent('macos/v' + version), {signal: AbortSignal.timeout(15000)});
  assert.ok(response.ok, `Release HTTP ${response.status}`);
  const release = await response.json();
  assert.equal(release.draft, false);
  const cpu = arch === 'x64' ? 'x86_64' : 'arm64';
  const asset = release.assets.find(a => a.name === `AI-Usage-Monitor-macOS-${version}-${cpu}-unsigned-test.dmg`);
  assert.ok(asset, `No public DMG for ${cpu}`);
  const dmg = await readFile(join(scratch, '.runtime', 'updates', 'update.dmg'));
  assert.equal(dmg.length, asset.size);
  assert.equal('sha256:' + createHash('sha256').update(dmg).digest('hex'), asset.digest);
  console.log(`Verified discovery and staged DMG: ${current} -> ${version} (${cpu}); not installed.`);
} finally {
  await rm(scratch, {recursive: true, force: true});
}
