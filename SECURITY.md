# Security and Privacy

Unofficial local utility, not an OpenAI extension. Public release is pending
maintainer approval. No independent security audit has been completed.

## Trust boundary

The sidebar uses Chrome DevTools Protocol (CDP), which grants much more access
than reading quota. Other local processes may reach its loopback listener.
Do not use this on an untrusted/shared machine. Never forward its port.
Stopping the meter removes its widget but does NOT close the app's debug port.
Save work, fully quit Codex, then relaunch from its official launcher to close it.
The first Windows launch requires explicit consent before opening CDP.

The launcher verifies the signed Store application and listener owner. App files
are not patched. A running app without CDP is never restarted without confirmation;
unsaved work can be lost if restart is accepted. The CLI attach command is an
advanced diagnostic interface: its caller must establish listener ownership first.

## Data

Only read-only account quota/usage RPCs are issued. The CLI itself handles its
existing authentication/network behavior. This utility does not directly read
auth.json, cookies, conversations, session databases or passwords, and adds no
analytics or upload endpoint. CLI and desktop accounts may differ: verify them.

Local .runtime stores settings, diagnostic state, startup logs and up to 45
date-availability observations (dates/times, not token totals or credentials).
Observations describe this installation, not a verified account identity. Clear
them and review membership settings after switching accounts. No cloud sync.
Startup diagnostics may contain local paths; review/redact before sharing.

## Distribution

Source bundles use an explicit manifest; .runtime and local build outputs are
excluded. Third-party Node binaries are checked against official SHA256 hashes;
vendor helper code is pinned. Checksums detect corruption, not malicious authors.
The custom Windows binaries are unsigned. Never disable antivirus or Gatekeeper
to install this tool. macOS has experimental ad-hoc signed Intel/Apple Silicon
DMGs, not Developer ID signed or notarized. Native UI/build tests and publisher
verification do not establish real-account connection acceptance, which is still
pending. Signing/notarization and fresh-user install acceptance remain follow-ups.

## Reporting

After the public repository is approved, enable GitHub private vulnerability
reporting and use its Security tab. Until then, report privately to the maintainer;
do not post credentials or sensitive reproduction material in public issues.
## Browser companion boundary

Author: KEFEN. The optional Chrome companion grants only sidePanel and
nativeMessaging. The local helper accepts one bounded read operation from the
explicitly registered extension ID. It reads a fixed snapshot file and projects
only quota numbers, token totals and timestamps. No cookies or credentials are
returned. No network listener is added. A hostile process running as the same
OS user can still change local files; this is not a sandbox against that user.
Unregister the host before uninstalling. Mac registration remains unverified.
