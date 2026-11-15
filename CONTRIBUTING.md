# Contributing

Use Node 24.16.0. Run `node --test test/*.test.mjs` before submitting changes.
Keep core logic in src, Windows host code in native and Mac code in mac.
Do not add direct credential access, chat/session reads, telemetry or remote-code
execution. Never include .runtime, local accounts, raw diagnostics or binaries in
commits. Add tests for missing/zero usage, date boundaries and partial RPC errors.

Update source-files.json for new source files and runtime-files.json for installed
files. Keep independent versions in versions.json and synchronize platform launch
labels when changing a version. Do not edit pinned vendor helper code silently.
New dependencies require a source, license, pin and security review.

The public GitHub repository has not been created yet. The prepared workflow runs
tests/builds only and has read-only repository permissions; it does not publish.
Before enabling releases, configure maintainer review, private vulnerability
reporting, dependency monitoring and signed build provenance. No pull request
workflow should have access to release signing credentials.
