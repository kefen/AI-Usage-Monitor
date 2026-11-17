# Release Record

## Approved V3: 2026-11-17

| Platform | Version | Changes |
|---|---|---|
| Windows 10/11 x64 | 0.13.0 | Approved V3 client and installer, all eleven shared choices, localized numbered notes |
| macOS Apple Silicon | 0.5.0-alpha.1 | arm64 V3 native client, version-acknowledged upgrade and preserved settings |
| macOS Intel | 0.5.0-alpha.1 | x86_64 native package; live-account acceptance remains pending |
| Chrome MV3 | 0.4.0 | Shared selections, readable quota/Token overview, localized release notes |

UI direction and publication were authorized by the user. Build/test evidence and
asset digests are recorded separately from that authorization. No new live-account
acceptance is implied. Plan detection uses supported verified-desktop metadata
only; unknown is an expected fallback. Manual plan corrections lock automatic
replacement, and detecting again preserves manually entered tier and dates.

This is an additive release. Existing Releases, source commits and tags remain.
Mac remains ad-hoc signed and unnotarized. Older Mac updater failures may require
one manual application replacement as described in the user guide.

## Usage Overview: 2026-11-16

| Platform | Version | Changes |
|---|---|---|
| Windows 10/11 x64 | 0.12.6 | Fixed monthly average, aligned metric grid and explicit unavailable states |
| macOS Apple Silicon | 0.4.8-alpha.1 | arm64 native layout, compact status strip and same metric order |
| macOS Intel | 0.4.8-alpha.1 | x86_64 native layout; real-account acceptance remains pending |
| Chrome | 0.3.4 | Two-column metrics, compact values and visible missing-data slots |

All builds retain three languages, signed desktop update checks and manual plan
records. No new account or billing credentials are read. Previous Releases remain
available; this is a normal additive update after the earlier baseline cleanup.

## Update Baseline: 2026-11-16

| Platform | Version | Update support |
|---|---|---|
| Windows x64 | 0.12.5 | Signed checks, verified download, transactional install after restart |
| macOS Apple Silicon | 0.4.7-alpha.1 | arm64 DMG, signed checks and verified app replacement |
| macOS Intel | 0.4.7-alpha.1 | x86_64 DMG; real-account acceptance pending |
| Chrome | 0.3.3 | Check above version; explicit download/unpack/reload |

Includes integer Credits, reset-count/renewal/Credits ordering, and three-language
first-launch security help. Mac remains experimental and unnotarized.
Previous Releases/assets are removed after new package verification.
Source commits and tags are retained.

## Public Baseline: 2026-11-16 Follow-up

| Platform | Version | Package distinction |
| --- | --- | --- |
| Windows 10/11 x64 | 0.12.4 | Windows-x64-Setup.exe |
| macOS Apple Silicon | 0.4.6-alpha.1 | macOS-arm64-unsigned-test.dmg |
| macOS Intel | 0.4.6-alpha.1 | macOS-x86_64-unsigned-test.dmg |
| Chrome MV3 | 0.3.2 | Chrome ZIP; desktop native host required |

All share the monthly returned-day average, unchanged Monday weekly total,
local-midnight yesterday label without a numeric date, and read-only credit
balance / available quota-reset count. Older daily fallback values remain dated.
Mac includes compact typography and install/launch guidance. No reset is spent.

This is the authorized new public release baseline, not a reset of version numbers.
After all three releases and their attached SHA256 digests are verified, the
explicitly approved older Releases and assets are removed. Source commits and Git
tags remain; subsequent releases accumulate normally. Historical entries below
document earlier behavior and are not current download instructions.

Mac remains ad-hoc signed and not notarized. Prior Apple Silicon connection was
user-confirmed; Intel real-account acceptance and browser-profile acceptance are
still separate from automated build/UI tests.

## 2026-11-16 Mac Follow-up

- macOS **0.4.5-alpha.1**: Apple Silicon and Intel experimental DMGs; native UI tests, compact metrics, small separate data dates, installation and next-launch guidance.
- User confirmed Apple Silicon connection after the shared-listener fix. Intel real-account acceptance remains pending. Publication of this follow-up was authorized; it is not notarized or promoted to stable.
- Windows **0.12.3 stable** and Chrome **0.3.1 experimental** remain available unchanged. Existing release binaries/tags are not overwritten.
- Each Mac DMG includes the three-language offline guide. Launch the installed application from Finder > Applications, not from the DMG.
- The new Mac release also includes the corresponding source archive and SHA256 checksums. Older releases below are historical records, not current installation advice.

## KEFEN Branding Correction

Windows 0.11.1-beta.1, Chrome 0.2.1 and macOS 0.3.1-alpha.1 are branding-only
corrections. The host name is org.kefen.codex_quota_sidebar; browser users must
update both components and register again. This patch is based on accepted
Windows 0.11.0, not a new claim of user acceptance or Mac support.

## Earlier Accepted Release

Author: KEFEN. Windows acceptance confirmed by the user on 2026-11-15.

| Platform | Version | Tag | Evidence boundary |
| --- | --- | --- | --- |
| Windows x64 | 0.11.0-beta.1 | windows/v0.11.0-beta.1 | Local automated checks and user acceptance |
| Chrome MV3 | 0.2.0 | chrome/v0.2.0 | Layout/native-host fixtures; real browser profile acceptance separate |
| macOS Apple Silicon | 0.3.0-alpha.1 | macos/v0.3.0-alpha.1 | Source only; no real-Mac acceptance or installable binary |

All are prereleases. Versions are retained from the accepted candidate, not
renamed to stable. No functional code changes accompany publication.
All three releases are published. Assets were downloaded again and SHA256
verified locally; see [the published asset record](releases/published-0.11.json).
Later documentation screenshots on main do not replace immutable release files.
GitHub release assets are built from the tagged source by the accepted-release
workflow, so binary hashes can differ from local test builds. Each release
includes the corresponding SHA256 file. No signing/notarization claim is made.

50 shared tests and six Windows native suites passed locally, together with
isolated install, upgrade, uninstall, rollback, restart-ownership and layout tests.
Public packaging runs build and extraction checks again. This is not an
independent security audit.
# 2026-11-16 Release Set

- Windows **0.12.3 stable**: user acceptance and public publication authorized.
- Chrome **0.3.1 experimental**: synchronized three-language interface and keyboard-focus fix.
- macOS **0.4.1-alpha.1**: native Intel and Apple Silicon DMGs; unsigned/not notarized; real-account acceptance pending.
- Mac publisher evidence: Actions run 43805495761, official bundle com.openai.codex, Team ID 2DC432GLL2. The audited official client is ARM-only.
- The Windows accepted UI is unchanged from 0.12.3-beta.1; only stable metadata was promoted.
- Final installer hardening: Unicode legacy shortcuts are inspected through an ASCII-named copy when WSH cannot read the original name. Foreign shortcuts remain untouched; English Windows CI covers both cases.
- Official Mac CLI and loopback CDP startup without an account passed in Actions run 43806636066. Authenticated quota retrieval is not covered.

