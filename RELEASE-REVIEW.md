# Release review / CHUNG

Candidate: Windows 0.9.3-beta.1, macOS 0.2.2-alpha.1, Chrome 0.1.1.
No public repository or release has been created by this build.

## Scope

Original blue winking-terminal logo; regular-weight native UI; CHUNG attribution.
Nine selectable desktop sidebar fields and manually recorded plan-family badge.
Optional renewal dates with monthly/manual and Business annual modes.
Chrome side panel reads a sanitized local snapshot through Native Messaging.
No changes to the user's currently installed application are part of this review.

## Release gates

- macOS is source-only: Swift compilation, Apple Silicon UI/installation,
  publisher Team ID verification, process-lock ownership and upgrade acceptance
  remain required. Fail-closed publisher validation is deliberately preserved.
- Windows installer is unsigned. Clean-machine installation and actual Codex
  upgrade acceptance remain necessary before advertising a stable release.
- Chrome host framed I/O is tested with isolated synthetic data. Actual extension
  registration and complete user-profile acceptance remain a separate gate.
- Unregister the browser helper before uninstalling the desktop candidate.
- No independent security audit has occurred. Local CDP grants broader access
  than this read-only feature uses; stopping the monitor does not close CDP.
- Manual membership metadata is not verified entitlement or billing information.
  The native settings UI is not pixel-identical to the earlier design prototype.

## Local verification evidence

0.9.1 follow-up: verified graceful monitor replacement with a changed child PID;
native button callback and feedback retention fixtures; atomic display-settings
notifications. An attempt to activate the actual Store app from the restricted
test shell was denied by Windows. Foreground activation must still be accepted
from the normally launched desktop app; no live activation success is claimed.

Live Windows follow-up: the user's normally launched 0.9.1 monitor mounted
successfully. A temporary plan-badge preference change repainted in 255 ms and
the original config was restored. Reconnect through the normal tray's request
channel preserved the tray, changed the monitor PID and remounted successfully.

- 49 Node unit/contract tests passed, including atomic preference replacement.
- Real compiled Windows bridge and Node framed I/O passed with synthetic data:
  exact-origin rejection, read-only operation and secret-field projection.
- Playwright sidebar fixtures passed at 1280/360 widths, including all-fields-off.
- Browser panel fixtures passed at 320/480 widths for fresh/stale/missing states;
  these use a mocked Chrome bridge, not live extension registration.
- Native consent, startup/status/retry, installer and 150% layout fixtures passed.
  Testing found an installer completion-thread bug; explicit UI dispatch fixed it
  and the same fixture then passed. Preferences save/cancel/skip also passed.
- Isolated install, upgrade, ownership, rollback, uninstall preservation and
  process-restart safety tests passed. Real setup extraction checked 44 payload
  hashes. Screenshots were reviewed for native installer and browser panel.

## Publication decision

Suitable for a clearly labeled experimental source review after the owner
confirms repository ownership and license. Not ready for a stable all-platform
binary release. Ship Mac source only and explicitly disclose the gates above.
Use allowlisted archives, not the entire working directory, which contains local
build/test artifacts. Inspect FILE-HASHES.json and SHA256SUMS.txt before upload.
