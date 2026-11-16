#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS build host required.'; exit 1; }
arch="${1:-arm64}"
case "$arch" in arm64) nodearch=arm64 ;; x86_64) nodearch=x64 ;; *) exit 2 ;; esac
version=$(node -p "JSON.parse(require('fs').readFileSync('versions.json')).macos")
nodeversion=$(node -p "JSON.parse(require('fs').readFileSync('dependency-pins.json')).nodeVersion")
stage="build/mac-$arch"
app="$stage/Codex Quota Sidebar.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
/usr/bin/xcrun swiftc -O -target "$arch-apple-macosx13.5" -framework AppKit mac/Localization.swift mac/Bootstrap.swift mac/QuotaSidebar.swift -o "$app/Contents/MacOS/QuotaSidebar"
cp ui/strings.json "$app/Contents/Resources/strings.json"
cp mac/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
cp assets/cqs.icns "$app/Contents/Resources/cqs.icns"
node mac/package-payload.mjs "$app/Contents/Resources/payload"
archive="node-v$nodeversion-darwin-$nodearch.tar.gz"
curl --fail --location --proto '=https' "https://nodejs.org/dist/v$nodeversion/$archive" -o "$stage/$archive"
curl --fail --location --proto '=https' "https://nodejs.org/dist/v$nodeversion/SHASUMS256.txt" -o "$stage/SHASUMS256.txt"
(cd "$stage"; grep "  $archive$" SHASUMS256.txt | shasum -a 256 -c -; tar -xzf "$archive")
mkdir -p "$app/Contents/Resources/payload/runtime"
cp "$stage/node-v$nodeversion-darwin-$nodearch/bin/node" "$app/Contents/Resources/payload/runtime/node"
cp "$stage/node-v$nodeversion-darwin-$nodearch/LICENSE" "$app/Contents/Resources/payload/runtime/LICENSE"
/usr/bin/codesign --force --sign - "$app/Contents/Resources/payload/runtime/node"
/usr/bin/codesign --force --sign - "$app"
/usr/bin/codesign --verify --deep --strict "$app"
file "$app/Contents/MacOS/QuotaSidebar" "$app/Contents/Resources/payload/runtime/node"
mkdir -p "build/dmg-$arch" dist
ditto "$app" "build/dmg-$arch/Codex Quota Sidebar.app"
ln -s /Applications "build/dmg-$arch/Applications"
hdiutil create -volname 'Codex Quota Sidebar Test' -srcfolder "build/dmg-$arch" -ov -format UDZO "dist/Codex-Quota-Sidebar-macOS-$version-$arch-unsigned-test.dmg"
echo 'Local, ad-hoc signed test build only. Not notarized; no production Mac package created.'
echo 'Verify the official Codex signing Team ID and complete RELEASE-CHECKLIST.md before distribution.'
