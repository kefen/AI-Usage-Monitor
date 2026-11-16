# Changelog

## 2026-11-16 Update Baseline
- Windows 0.12.5 / macOS 0.4.7-alpha.1 / Chrome 0.3.3.
- Update check sits immediately above the platform version. Desktop updates use a pinned Ed25519 key, signed expiring metadata and SHA-256 verified full packages.
- Desktop replacement waits for the companion to quit; preserves settings and does not close official Codex. Browser unpacked installations require explicit reload.
- Credits now use the official English name and integer display rounded down. Reset count follows reset date; credits follow renewal.
- Windows SmartScreen and Mac Privacy & Security instructions are shown before download and included in installation help.

## Windows 0.11.2-beta.1 (local candidate, awaiting user acceptance)

- Measure official navigation controls before allocating sidebar space.
- Collapse to a quota icon or hide safely when controls need the space; restore automatically.
- Open the native usage overview through a fixed, local-only CDP action.
- Report compact/hidden states in English, Simplified Chinese and Traditional Chinese.
- Cover update buttons, small windows, 100-200% scaling and layout changes with browser tests.
- macOS Intel/Apple Silicon packaging and other Windows targets are deferred until Windows acceptance.
- No GitHub publication or installed-user configuration changes in this candidate build.

## Windows 0.11.1-beta.1 / macOS 0.3.1-alpha.1 / Chrome 0.2.1

- Standardize all current first-party attribution and native messaging on KEFEN.
- Rename the native host to org.kefen.codex_quota_sidebar; browser re-registration required.
- Add author metadata and cross-platform native-host consistency regression tests.
- Retire obsolete local publication entry points to prevent restoring old source.
- Preserve historical commits and immutable earlier release files.

## Windows 0.11.0-beta.1 / macOS 0.3.0-alpha.1 / Chrome 0.2.0

- Apply approved A installer and A3 usage-overview direction.
- Add English, Simplified Chinese and Traditional Chinese UI selection.
- Display platform versions, KEFEN attribution and the project GitHub link.
- Clarify optional Codex subscription records; no software membership required.
- Add sanitized, freshness-checked overview metrics without extra account polling.
- Refresh English-first README and fixture screenshots.
- macOS source updated only; real-Mac build and acceptance remain required.
- Windows user acceptance confirmed on 2026-11-15; publication authorized.
- Add illustrated installation/connection guide and explicit platform release record.

## Windows 0.8.0-beta.1 (local candidate)

- Rename public project to Codex Quota Sidebar, add MIT license and clean source manifest.
- Automatically choose current, previous or most recent returned date; always show the
  actual date, including full year in tooltip. Hide missing daily data, preserve real zero.
- Observe first-seen daily data using existing hourly reads; no token history upload.
- Native first-run consent and optional membership settings, month-end preview,
  explicit renewal/expiry date override, skip/hide and later tray settings.
- Manual refresh with a one-minute cooldown, observation-history reset.
- Reduce legacy PowerShell tray to a forwarding wrapper.
- Keep installer/uninstaller mutex during changes; restore partial copies on failure.
- Separate runtime/source allow-lists, fixed dependency hashes and pinned CI actions.
- No remote publishing, auto-updater, telemetry or added npm runtime dependencies.

## macOS 0.1.0-alpha.1 (source only)

- Independent version channel sharing usage normalization and sidebar code.
- Official publisher requirement added; intentionally disabled until the actual
  signing Team ID is verified on an Apple Silicon Mac.
- No binary release. Native onboarding, process identity, upgrade and actual app
  compatibility remain acceptance gates, not Windows-tested claims.
# Windows 0.9.0-beta.1 / macOS 0.2.0-alpha.1 / Chrome 0.1.0

- KEFEN attribution and original blue winking-terminal branding.
- Nine configurable sidebar fields and manually selected plan-family badge.
- Broader plan metadata, optional dates and Business annual estimates.
- Read-only Chrome Native Messaging companion with exact extension allowlist.
- Bounded snapshot projection; no cookies, host permissions or network listener.
- Fixed installer completion dispatch to the UI thread.
- Mac remains experimental source only; no real-machine acceptance claimed.

# Windows 0.9.1-beta.1 / macOS 0.2.1-alpha.1 / Chrome 0.1.1

- Explicit verified Store focus action and visible activation success/failure feedback.
- Reconnect gracefully replaces the owned monitor, preserving the Codex application.
- Filesystem-driven sidebar settings repaint, independent of hourly account reads.
- Save confirmation for display preferences and compact rail layout regression check.
- Mac equivalents updated as source only; Chrome companion repackaged unchanged.

# Windows 0.9.2-beta.1 / macOS 0.2.2-alpha.1

- Hiding a membership date preserves previously saved purchase/billing fields.
- Switching date modes clears obsolete explicit dates before saving a new mode.
- Rename the monitor stop action to Exit software; exiting does not close Codex.
- Regression reproduced and fixed in the native preferences save/cancel/skip test.

# Windows 0.9.4-beta.1

- Fix Windows PowerShell 5.1 restart dialog loading: Add-Type rejects EXE files;
  load the managed assembly with Assembly.LoadFrom instead.
- Preserve explicit user confirmation and default-to-cancel behavior before restart.
- Add Windows PowerShell loading regression and native restart-dialog decision tests.
- Distinguish restart-dialog loading errors from a running client without CDP.

# Windows 0.10.0-beta.1 (local acceptance only)

- Guided setup: environment, writable destination, sidebar choices, install and explicit connection.
- Custom installation directory; protected, linked, foreign and low-space destinations rejected.
- Request graceful shutdown of the owned older meter, without stopping Codex.
- Clear install failure/retry and connected/disconnected primary actions.
- Optional membership setup after installation; preserve existing preferences during upgrade.
- Allow-listed diagnostic export, validated settings backup/restore and manual release-page link.
- Attribution updated to Codex Quota Sidebar by KEFEN; original icon and rail layout retained.
- Native navigation, recovery, 150% layout, path safety and privacy fixtures added.
- GitHub publication withheld until the user's Windows acceptance.
- macOS and Chrome source attribution updated; no new Mac installation-flow acceptance.

# R2 test candidate - 2026-11-16

- Windows 0.12.0-beta.1: compact setup; single-window navigation; separate data,
  help and about pages; bottom-left version; three retained languages.
- Shared rail: full display, bounded scrolling, compact action, then hidden.
  Official controls always take priority, including dynamically appearing updates.
- Chrome 0.3.0: local display preferences, help, sanitized diagnostic download,
  about page; unchanged read-only Native Messaging permission boundary.
- macOS 0.4.0-alpha.1: Intel/Apple Silicon unsigned test build workflow and
  native navigation changes. Publisher trust and real-device acceptance remain
  required; compiling a DMG does not establish working Codex integration.
- Candidate branch only. No public Release or main-branch update authorized.

# Windows 0.12.1-beta.1 - 2026-11-16

- Fix initial overview being covered by an empty transient page before the window
  is shown; reconnect status now remains visible without navigating away.
- Embedded subscription save stays on the current page, clears dirty state, and
  uses the same 1.4-second success button as sidebar settings. Remove redundant
  embedded cancel/skip controls; keep standalone onboarding behavior.
- Remove nested editor close callbacks that re-entered navigation and confirmations.
- Number restart safety instructions; widen confirmation button; load saved locale.
- Re-space installation actions/completion steps and compact project information.
- Windows-only candidate; no Mac update or public Release in this iteration.

# Windows 0.12.2-beta.1 - 2026-11-16

- Always create the default desktop shortcut as Codex Quota Sidebar, independently
  of interface language. Do not inherit legacy localized/misdecoded names.
- Read installation manifests explicitly as UTF-8 for Windows PowerShell 5.1.
- After successful installation, remove only verified same-installation shortcut
  duplicates beside the new shortcut. Preserve foreign shortcuts and symlinks.
- Keep UI language selection and all saved preferences unchanged.

# Windows 0.12.3-beta.1 - 2026-11-16

- Main-window brand caption now shows only by KEFEN, without a repeated page title.
- Compact sidebar notes, data actions, diagnostic steps and About information.
- Text rows size to their translated content instead of reserving large fixed
  heights; keep spacing between action groups and preserve long-text wrapping.
- Windows-only visual iteration; save behavior, language choice and English
  shortcut naming are unchanged. Not publicly released.

# 2026-11-16: Windows 0.12.3 / Chrome 0.3.1 / macOS 0.4.1-alpha.1

- Promote the user-accepted Windows UI to stable without changing its behavior.
- Mac: single-window pages, in-place save feedback, validated backup/restore,
  compact layout, official publisher verification and updated bundled CLI discovery.
- Browser: three-language navigation and retained checkbox keyboard focus.
- Package both native Mac architectures; explicitly retain experimental status
  and disclose the official client's Intel compatibility prerequisite.
- Update illustrated English documentation and checksummed release automation.

# macOS 0.4.2-alpha.1 test candidate

- Preserve upstream Node.js bytes and Developer ID signature instead of replacing
  them with an ad-hoc signature. Verify the Node.js publisher during the build.
- Fix inline codesign requirement syntax: the missing equals prefix previously
  made macOS interpret the publisher rule as a filename. Keep strict signature
  validation and allow up to 60 seconds for a full official-app verification.
- Bundle an offline Simplified Chinese / Traditional Chinese / English installation
  guide in the DMG and the app; show security guidance before first connection.
- Probe Node startup before running the monitor; distinguish missing/failed/timed-out
  runtime from Codex connection errors and restore retry controls.
- Restore a missing runtime during reinstall; keep Windows and Chrome release
  versions unchanged. Apple notarization and real-account acceptance remain pending.

# macOS 0.4.3-alpha.1 (test candidate)

- Reuse an existing Codex connection port, or offer a localized, explicit save-work/restart confirmation. Request normal quit only; never force-close the official app.
- Keep errors visible above transient feedback. Cancellation and quit timeout leave an actionable message.
- Align Mac navigation, button sizing, selection colors, typography and two-row metrics with the Windows companion.
- Extend the offline three-language guide with running-client connection, optional Automation permission and upgrade instructions.
- Windows 0.12.3 remains unchanged. Real-device acceptance is required before release.

# macOS 0.4.4-alpha.1 (test candidate)

- Accept the official Computer Use helper as a co-owner only with a verified main-process owner, exact helper path, direct parent, expected bundle ID and OpenAI Developer ID signature. Reject unknown owners and non-loopback addresses.
- Query full-width process paths and distinguish ownership, helper signature, non-local address and query errors in all three languages. Include only allowlisted connection codes in exported diagnostics.
- Pin page content to the top independently of navigation height. Check failure refresh and page switching in native screenshot tests.
- Windows remains at 0.12.3. Requires user Mac acceptance before release.

# macOS 0.4.5-alpha.1 (UI test candidate)

- Separate small dated captions from tabular count values, align metric columns and abbreviate K/M/B counts with exact-count tooltips. Clear stale captions with unavailable data.
- Unify regular-weight headings, labels, compact status rows, grouped sidebar choices and stable Save feedback. Keep the window visible after connecting until the user closes it.
- Explain drag-to-Applications installation before running from a DMG or AppTranslocation path. Add Show application in Finder to About and a three-language next-launch guide.
- Add native populated-data screenshots and formatter tests. Preserve the 0.4.4 connection policy and Windows 0.12.3.

# Windows 0.12.4 / macOS 0.4.6-alpha.1 / Chrome 0.3.2

- Daily average now uses current-month returned days; weekly calculation unchanged.
- Yesterday hides the numeric date, follows local midnight, and never disguises older records.
- Optional read-only credit balance and available quota-reset count.
- Fix Mac caption layout constraint that stalled native UI startup.
- Document Apple Silicon versus Intel installation and retained version history.

