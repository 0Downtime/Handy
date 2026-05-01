#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

app_name="${HANDY_APP_NAME:-Handy}"
bundle_ids="${HANDY_BUNDLE_IDS:-com.pais.handy}"
tauri_config="${HANDY_TAURI_CONFIG:-}"
bundles="${HANDY_BUNDLES:-}"

for bundle_id in $bundle_ids; do
  osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null 2>&1 || true
done

build_args=(tauri build)
if [[ -n "$tauri_config" ]]; then
  build_args+=(--config "$tauri_config")
fi
if [[ -n "$bundles" ]]; then
  build_args+=(--bundles "$bundles")
fi

CMAKE_POLICY_VERSION_MINIMUM="${CMAKE_POLICY_VERSION_MINIMUM:-3.5}" bun run "${build_args[@]}"

app_path="$(find -L src-tauri/target -path "*/bundle/macos/$app_name.app" -type d -print 2>/dev/null | sort | tail -n 1)"

if [[ -z "$app_path" ]]; then
  echo "Could not find built $app_name.app under src-tauri/target" >&2
  exit 1
fi

open "$app_path"
echo "Launched $app_path"
