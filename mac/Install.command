#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -m)" != arm64 ]]; then echo 'Apple Silicon Mac required.'; exit 1; fi
dest="$HOME/Library/Application Support/CodexSidebarMeter"
app="$HOME/Applications/Codex Quota Sidebar.app"
if [[ ! -x runtime/node || ! -d 'build/Codex Quota Sidebar.app' ]]; then
  echo 'Build the native app with mac/Build.command and supply a verified arm64 Node runtime first.'
  exit 1
fi
if [[ -e "$dest" || -e "$app" ]]; then
  echo 'Existing installation found. Stop and uninstall it first; no files changed.'
  exit 1
fi
mkdir -p "$HOME/Applications" "$HOME/Library/Application Support"
stage=$(mktemp -d "$HOME/Library/Application Support/CodexSidebarMeter-install.XXXXXX")
cleanup() {
  case "$stage" in "$HOME/Library/Application Support/CodexSidebarMeter-install."*)
    if [[ -d "$stage" ]]; then rm -rf -- "$stage"; fi;;
  esac
}
trap cleanup EXIT
cp -R src mac browser runtime assets ui package.json versions.json README.md LICENSE SECURITY.md THIRD_PARTY_NOTICES.md "$stage/"
chmod 755 "$stage/runtime/node"
if ! "$stage/runtime/node" --version; then
  echo 'Node could not run. Check macOS version/security policy; installation incomplete.'
  exit 1
fi
cp -R 'build/Codex Quota Sidebar.app' "$stage/Codex Quota Sidebar.app"
printf '%s\n' 'local-codex-sidebar-meter-0.4.6-alpha.1' > "$stage/installed-by-meter"
mv "$stage/Codex Quota Sidebar.app" "$app"
mv "$stage" "$dest"
echo 'Installed. Open ~/Applications/Codex Quota Sidebar.app.'
echo 'This Mac build has not been tested on a real Mac. No Codex app files were changed.'
