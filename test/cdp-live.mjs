// Optional real TCP integration test. Some Codex sandboxes deny loopback TCP.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import net from 'node:net';
import { listTargets, evaluate } from '../src/cdp.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const widget = await readFile(new URL('../src/widget.js', import.meta.url), 'utf8');
const reservation = net.createServer();
await new Promise(resolve => reservation.listen(0, '127.0.0.1', resolve));
const port = reservation.address().port;
await new Promise(resolve => reservation.close(resolve));
const browser = await chromium.launch({ headless: true,
  ...(process.env.TEST_BROWSER_PATH ? { executablePath: process.env.TEST_BROWSER_PATH } : {}),
  args: [`--remote-debugging-port=${port}`, '--remote-debugging-address=127.0.0.1']
});
try {
  const page = await browser.newPage();
  await page.goto(new URL('./webview/index.html', import.meta.url).href);
  const targets = await listTargets(port);
  assert.equal(targets.length, 1);
  const target = targets[0];
  assert.equal(await evaluate(target, port, `${widget}\nwindow.__localCodexMeter.receive({buckets:[]});window.__localCodexMeter.mounted();`), true);
  assert.equal(await page.locator('#local-codex-sidebar-meter').count(), 1);
  await assert.rejects(evaluate({ ...target, url:'https://example.com' }, port, '1'), /untrusted/);
  await evaluate(target, port, 'window.__localCodexMeter.dispose();');
  assert.equal(await page.locator('#local-codex-sidebar-meter').count(), 0);
  console.log('PASS: real loopback CDP integration');
} finally { await browser.close(); }
