#!/bin/bash
set -euo pipefail
root="$HOME/Library/Application Support/CodexSidebarMeter"
if [[ -d "$root/.runtime" ]]; then printf stop > "$root/.runtime/background-stop.request"; fi
echo 'Stop requested. Codex stays open. Allow up to 60 seconds for the current request to finish.'
