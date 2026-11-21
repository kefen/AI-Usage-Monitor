import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdtemp, mkdir, readFile, copyFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';

const [priorDir, version, arch] = process.argv.slice(2);
assert.equal(process.platform, 'darwin');
assert.equal(process.arch, arch);
assert.ok(['x64', 'arm64'].includes(arch));
const prior = resolve(priorDir);
const installedVersions = process.argv[5] ?? join(prior, 'versions.json');
const current = JSON.parse(await readFile(installedVersions)).macos;
const scratch = await mkdtemp(join(tmpdir(), 'aim-mac-update-'));
try {
  await copyFile(installedVersions, join(scratch, 'versions.json'));
  for (const operation of ['auto', 'check', 'download']) {
    const result = JSON.parse(execFileSync(process.execPath,
      [join(prior, 'src/update.mjs'), operation, scratch], {encoding: 'utf8', timeout: 330000}));
    assert.equal(result.current, current);
    assert.equal(result.version, version, `${arch}: ${current} saw ${result.version}, expected ${version}`);
    assert.equal(result.available, true);
    if (operation === 'download') assert.equal(result.ready, true);
  }
  const release = JSON.parse(await readFile(process.env.RELEASE_JSON, 'utf8'));
  assert.equal(release.tag_name, 'macos/v' + version);
  assert.equal(release.draft, false);
  const cpu = arch === 'x64' ? 'x86_64' : 'arm64';
  const asset = release.assets.find(a => a.name === `AI-Usage-Monitor-macOS-${version}-${cpu}-unsigned-test.dmg`);
  assert.ok(asset, `No public DMG for ${cpu}`);
  const dmg = await readFile(join(scratch, '.runtime', 'updates', 'update.dmg'));
  assert.equal(dmg.length, asset.size);
  assert.equal('sha256:' + createHash('sha256').update(dmg).digest('hex'), asset.digest);
  const mount = join(scratch, 'mount');
  await mkdir(mount);
  execFileSync('/usr/bin/hdiutil', ['attach', '-readonly', '-nobrowse', '-mountpoint', mount, join(scratch, '.runtime', 'updates', 'update.dmg')]);
  try {
    const payload = join(mount, 'AI Usage Monitor.app', 'Contents', 'Resources', 'payload');
    await copyFile(join(payload, 'versions.json'), join(scratch, 'versions.json'));
    const check = JSON.parse(execFileSync(join(payload, 'runtime', 'node'),
      [join(payload, 'src', 'update.mjs'), 'check', scratch], {encoding: 'utf8', timeout: 60000}));
    assert.equal(check.current, version);
    assert.equal(check.version, version);
    assert.equal(check.available, false);
  } finally {
    execFileSync('/usr/bin/hdiutil', ['detach', mount]);
  }
  console.log(`Verified discovery and staged DMG: ${current} -> ${version} (${cpu}); not installed.`);
} finally {
  await rm(scratch, {recursive: true, force: true});
}
