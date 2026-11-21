#!/bin/bash
set -euo pipefail
root="$HOME/Library/Application Support/CodexSidebarMeter"
app="$HOME/Applications/AI Usage Monitor.app"
if [[ -L "$root" || -L "$app" || ! -f "$root/installed-by-meter" ]]; then echo 'Not an owned install.'; exit 1; fi
if [[ "$(cat "$root/installed-by-meter")" != local-codex-sidebar-meter-0.5.4-alpha.5 ]]; then exit 1; fi
if [[ -f "$root/.runtime/mac.pid" ]]; then
  pid=$(cat "$root/.runtime/mac.pid")
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then echo 'Run Stop.command and wait before uninstalling.'; exit 1; fi
fi
# Move, rather than delete: user settings and any edited files remain recoverable.
backup="$HOME/.Trash/CodexSidebarMeter-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup"
mv "$root" "$backup/program"
if [[ -d "$app" ]]; then mv "$app" "$backup/AI Usage Monitor.app"; fi
echo "Moved to Trash: $backup"
