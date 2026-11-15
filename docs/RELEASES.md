# Release Record

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
