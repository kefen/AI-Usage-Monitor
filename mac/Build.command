#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo 'macOS build host required.'; exit 1; }
arch="${1:-$(uname -m)}"
case "$arch" in arm64) nodearch=arm64 ;; x86_64) nodearch=x64 ;; *) exit 2 ;; esac
version=$(node -p "JSON.parse(require('fs').readFileSync('versions.json')).macos")
nodeversion=$(node -p "JSON.parse(require('fs').readFileSync('dependency-pins.json')).nodeVersion")
mkdir -p build dist
stage=$(mktemp -d "build/mac-$arch-$version.XXXXXX")
app="$stage/AI Usage Monitor.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
/usr/bin/xcrun swiftc -O -target "$arch-apple-macosx13.5" -framework AppKit mac/Localization.swift mac/Bootstrap.swift mac/SettingsTransfer.swift mac/RuntimeProbe.swift mac/MetricPresentation.swift mac/QuotaSidebar.swift -o "$app/Contents/MacOS/QuotaSidebar"
sed "s/@MAC_VERSION@/$version/g" mac/READ-ME-FIRST.html > "$app/Contents/Resources/READ-ME-FIRST.html"
cp ui/strings.json "$app/Contents/Resources/strings.json"
cp mac/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version%%-*}" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CQSReleaseVersion string $version" "$app/Contents/Info.plist"
cp assets/cqs.icns "$app/Contents/Resources/cqs.icns"
node mac/package-payload.mjs "$app/Contents/Resources/payload"
archive="node-v$nodeversion-darwin-$nodearch.tar.gz"
curl --fail --location --proto '=https' "https://nodejs.org/dist/v$nodeversion/$archive" -o "$stage/$archive"
curl --fail --location --proto '=https' "https://nodejs.org/dist/v$nodeversion/SHASUMS256.txt" -o "$stage/SHASUMS256.txt"
(cd "$stage"; grep "  $archive$" SHASUMS256.txt | shasum -a 256 -c -; tar -xzf "$archive")
mkdir -p "$app/Contents/Resources/payload/runtime"
cp "$stage/node-v$nodeversion-darwin-$nodearch/bin/node" "$app/Contents/Resources/payload/runtime/node"
cp "$stage/node-v$nodeversion-darwin-$nodearch/LICENSE" "$app/Contents/Resources/payload/runtime/LICENSE"
# Preserve the upstream runtime exactly; signing our wrapper must not re-sign Node.
cmp "$stage/node-v$nodeversion-darwin-$nodearch/bin/node" "$app/Contents/Resources/payload/runtime/node"
/usr/bin/codesign -dv --verbose=2 "$app/Contents/Resources/payload/runtime/node" 2>&1 || true
/usr/bin/codesign --verify --strict -R '=anchor apple generic and identifier "node" and certificate leaf[subject.OU] = "HX7739G8FX"' "$app/Contents/Resources/payload/runtime/node"
/usr/bin/codesign --force --sign - "$app"
/usr/bin/codesign --verify --deep --strict "$app"
cmp "$stage/node-v$nodeversion-darwin-$nodearch/bin/node" "$app/Contents/Resources/payload/runtime/node"
if [[ "$(uname -m)" == "$arch" ]]; then
  /usr/bin/xcrun swiftc mac/MetricPresentation.swift test/MacMetricPresentationTest.swift -o "$stage/MetricPresentationTest"
  "$stage/MetricPresentationTest"
  /usr/bin/xcrun swiftc mac/MetricPresentation.swift test/MacV3PresentationTest.swift -o "$stage/V3PresentationTest"
  "$stage/V3PresentationTest"
  /usr/bin/xcrun swiftc mac/Bootstrap.swift test/MacUpdateAcknowledgementTest.swift -o "$stage/UpdateAcknowledgementTest"
  "$stage/UpdateAcknowledgementTest"
  /usr/bin/xcrun swiftc mac/RuntimeProbe.swift test/MacRuntimeProbeTest.swift -o "$stage/RuntimeProbeTest"
  "$stage/RuntimeProbeTest"
  "$app/Contents/Resources/payload/runtime/node" --version
  node --input-type=module -e 'import {spawnSync} from "node:child_process"; const r=spawnSync(process.argv[1],["--ui-smoke",process.argv[2]],{stdio:"inherit",timeout:120000}); if(r.error)console.error(r.error.message); process.exit(r.status??1);' "$app/Contents/MacOS/QuotaSidebar" "$PWD/verification/mac-$arch"
fi
file "$app/Contents/MacOS/QuotaSidebar" "$app/Contents/Resources/payload/runtime/node"
image="$stage/image"
mkdir "$image"
ditto "$app" "$image/AI Usage Monitor.app"
cp "$app/Contents/Resources/READ-ME-FIRST.html" "$image/READ-ME-FIRST.html"
ln -s /Applications "$image/Applications"
dmg="dist/AI-Usage-Monitor-macOS-$version-$arch-unsigned-test.dmg"
hdiutil create -size 512m -fs HFS+ -volname 'AI Usage Monitor' -srcfolder "$image" -ov -format UDZO "$dmg"
hdiutil verify "$dmg"
shasum -a 256 "$dmg"
echo 'Local, ad-hoc signed test build only. Not notarized; no production Mac package created.'
echo 'Official publisher verified; real-account connection acceptance is still pending.'
