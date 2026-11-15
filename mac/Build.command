#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || { echo 'Build on an Apple Silicon Mac.'; exit 1; }
app="build/Codex Quota Sidebar.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
/usr/bin/xcrun swiftc -O -target arm64-apple-macosx13.5 -framework AppKit mac/QuotaSidebar.swift -o "$app/Contents/MacOS/QuotaSidebar"
cp mac/Info.plist "$app/Contents/Info.plist"
cp assets/cqs.icns "$app/Contents/Resources/cqs.icns"
/usr/bin/codesign --force --sign - "$app"
echo 'Local, ad-hoc signed test build only. Not notarized; no production Mac package created.'
echo 'Verify the official Codex signing Team ID and complete RELEASE-CHECKLIST.md before distribution.'
