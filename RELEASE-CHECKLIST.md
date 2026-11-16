# Release Gates

Current candidate review and evidence: [RELEASE-REVIEW.md](RELEASE-REVIEW.md).

## Before public browser Beta

- Verify load-unpacked installation and Native Messaging registration in a clean
  Chrome profile, including wrong ID, stopped monitor, stale data and uninstall.
- Confirm the local CLI account is the intended account; no browser identity is read.
- Keep only sidePanel/nativeMessaging permissions; review the exact extension ZIP.
- Decide distribution identity and document unregister-before-uninstall.
- Mac host and browser registration need real Apple Silicon acceptance.

## Before public Windows Beta

- Confirm repository owner, MIT copyright notice and README with the maintainer.
- Run shared tests, UI layouts, native preferences and lifecycle tests.
- Verify compiled installer extraction, hashes, clean install, upgrade, rollback,
  uninstall and first-run consent on a fresh Windows user profile.
- Manually accept settings and day selection in an actual Codex desktop session.
- Inspect the exact source archive for secrets and unintended files.
- Review current Node/vendor advisories; fixed hashes are not a vulnerability scan.
- Enable GitHub private vulnerability reporting, code review and dependency alerts.
- Run the prepared CI remotely; local results do not mean CI has executed.
- Decide on Windows code signing. Publish unsigned status clearly until signed.
- Add source/build provenance to releases; checksums alone do not establish origin.
- Obtain explicit approval before creating a public repository or uploading assets.

## macOS Experimental Status And Remaining Beta Gates

The 0.4.1-alpha.1 DMGs are explicitly experimental. Publisher verification and
native compilation/UI smoke tests have passed on Actions for both architectures;
real-account, clean-user upgrade, and native-host profile acceptance remain open.
The list below remains the gate for removing experimental status.

- Verify official Codex bundle ID and Developer ID Team ID on a real Apple Silicon Mac.
- Fill the reviewed publisher pin in mac/trust.json; never bypass this guard to ship.
- Implement and test consent, optional date settings, account-change guidance and stop UI.
- Replace/check legacy PID-file lifecycle for PID reuse and startup races.
- Validate actual CLI path, auth behavior, CDP ownership and narrow rail selectors.
- Verify native ARM Node execution, installation/upgrade preserving preferences,
  cancellation, uninstall and file permissions on a fresh user account.
- Assess Developer ID signing/notarization and Gatekeeper behavior.
- Verify all dates/usage states without claiming an undocumented service timezone.

The release workflow generates architecture-specific DMGs. Shared tests or a
successful Mach-O header check do not satisfy the remaining platform acceptance gates.
