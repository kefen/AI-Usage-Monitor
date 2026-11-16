# Release Review: 2026-11-16

Author: KEFEN. [Recorded authorization](docs/releases/accepted-0.12.json).

| Platform | Version | Release boundary |
| --- | --- | --- |
| Windows x64 | 0.12.3 | User-accepted stable; unsigned installer |
| Chrome MV3 | 0.3.1 | Experimental companion; live-profile acceptance pending |
| macOS ARM / Intel | 0.4.1-alpha.1 | Experimental DMGs; ad-hoc signed, not notarized; real-account acceptance pending |

## Verification

- Windows: 54 shared tests, six native test groups, installer extraction and 45
  payload hashes, clean install, upgrade, rollback and ownership-preserving uninstall.
- Sidebar collision checks: 100%, 125%, 150%, 200%; official controls have priority.
- Browser: mocked bridge, three languages, 320/480 widths, unavailable/stale states,
  display preferences and retained keyboard focus; real Windows native-host framed I/O.
- Mac: native Intel/Apple Silicon compilation, all six pages in three languages,
  in-place save behavior, backup validation and rejection of unknown fields.
- Official Mac publisher: verified Team ID 2DC432GLL2, bundle com.openai.codex,
  codesign strict verification and Gatekeeper assessment in
  [audit run 43805495761](https://github.com/kefen/codex-quota-sidebar/actions/runs/43805495761).
- Source/runtime manifests exclude authentication, personal state and local logs.
  No new npm runtime dependencies or network listeners were added.

## Remaining Boundaries

The current official Mac download is ARM-only. The Intel companion requires a
separately compatible official client; it does not emulate ARM. No real Mac
account, clean-user upgrade, browser profile registration or notarization acceptance
is claimed. Automated UI screenshots use fixtures, not private account data.
CDP grants more access than quota reading; explicit consent and loopback/process
ownership checks remain required. No independent security audit is claimed.

The accepted Windows interface is unchanged apart from stable version metadata.
Historical release details remain in [the release record](docs/RELEASES.md).
