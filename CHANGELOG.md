# Changelog

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

