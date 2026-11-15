# Third-party code

`vendor/codex-quota/codex-cdp.ps1` is a locally modified Windows Store activation
and CDP listener ownership helper from `keaipiao/codex-quota`.

- Repository: https://github.com/keaipiao/codex-quota
- Commit: `54e3e15c898b65d66db4ecffec1725c4d8e9275d`
- Original path: `windows/codex-cdp.ps1`
- License: MIT; original license retained as `vendor/codex-quota/LICENSE`.
- Local change by KEFEN: explicit focus action reactivates the verified running
  Store application, after the existing listener ownership checks.
- TCP query failures are reported separately from an absent listener.

The new docked/floating sidebar selectors were checked against that project's
`src/renderer/panel-inject.js`. Other local meter code is independently maintained.

Release packages bundle Node.js 24.16.0 from https://nodejs.org/dist/v24.16.0/.
Windows x64 node.exe and the macOS arm64 archive are checked against the
official HTTPS SHASUMS256.txt. The Node license and bundled dependency notices
are included at runtime/LICENSE. Windows node.exe also retains its original
OpenJS Foundation Authenticode signature. The meter and installer are unsigned.
