#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

osascript -e 'tell application id "com.pais.handy" to quit' >/dev/null 2>&1 || true

CMAKE_POLICY_VERSION_MINIMUM="${CMAKE_POLICY_VERSION_MINIMUM:-3.5}" bun run tauri build

app_path="$(
  find src-tauri/target -path '*/bundle/macos/Handy.app' -type d -print 2>/dev/null |
    sort |
    tail -n 1
)"

if [[ -z "$app_path" ]]; then
  echo "Could not find built Handy.app under src-tauri/target" >&2
  exit 1
fi

open "$app_path"
echo "Launched $app_path"
