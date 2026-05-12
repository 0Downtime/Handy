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

build_args=(build)
if [[ -n "$tauri_config" ]]; then
  build_args+=(--config "$tauri_config")
fi
if [[ -n "$bundles" ]]; then
  build_args+=(--bundles "$bundles")
fi

if [[ ! -x node_modules/.bin/tauri ]]; then
  bun install --frozen-lockfile
fi

clang_runtime_dir="$(xcrun clang --print-runtime-dir 2>/dev/null || true)"
if [[ -f "$clang_runtime_dir/libclang_rt.osx.a" ]]; then
  export RUSTFLAGS="${RUSTFLAGS:-} -L native=$clang_runtime_dir"
fi

if [[ -z "${APPLE_CERTIFICATE:-}" && -z "${HANDY_SIGNING_IDENTITY:-}" ]]; then
  signing_dir="${HANDY_SIGNING_DIR:-$HOME/.cache/handy/signing}"
  signing_name="Apple Development: Handy Custom Local (HANDYCSTM1)"
  signing_p12="$signing_dir/handy-custom-local.p12"
  signing_password_file="$signing_dir/handy-custom-local.password"

  mkdir -p "$signing_dir"
  chmod 700 "$signing_dir"

  if [[ ! -f "$signing_p12" || ! -f "$signing_password_file" ]]; then
    password="$(openssl rand -hex 32)"
    openssl_config="$signing_dir/handy-custom-local.openssl.cnf"
    cert_pem="$signing_dir/handy-custom-local.cert.pem"
    key_pem="$signing_dir/handy-custom-local.key.pem"

    cat >"$openssl_config" <<EOF
[req]
distinguished_name = dn
x509_extensions = codesign_ext
prompt = no

[dn]
CN = $signing_name
OU = HANDYCSTM1
O = Handy Custom Local
C = US

[codesign_ext]
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
basicConstraints = critical,CA:false
subjectKeyIdentifier = hash
EOF

    openssl req -new -x509 -nodes -newkey rsa:2048 -days 3650 \
      -keyout "$key_pem" \
      -out "$cert_pem" \
      -config "$openssl_config" \
      -extensions codesign_ext >/dev/null 2>&1

    openssl pkcs12 -export \
      -legacy \
      -inkey "$key_pem" \
      -in "$cert_pem" \
      -out "$signing_p12" \
      -name "$signing_name" \
      -password "pass:$password" >/dev/null 2>&1

    printf '%s' "$password" >"$signing_password_file"
    chmod 600 "$signing_p12" "$signing_password_file" "$key_pem"
  fi

  export APPLE_CERTIFICATE="$(base64 <"$signing_p12" | tr -d '\n')"
  export APPLE_CERTIFICATE_PASSWORD="$(cat "$signing_password_file")"
  export APPLE_SIGNING_IDENTITY="$signing_name"
elif [[ -z "${APPLE_SIGNING_IDENTITY:-}" && -n "${HANDY_SIGNING_IDENTITY:-}" ]]; then
  export APPLE_SIGNING_IDENTITY="$HANDY_SIGNING_IDENTITY"
fi

CMAKE_POLICY_VERSION_MINIMUM="${CMAKE_POLICY_VERSION_MINIMUM:-3.5}" node_modules/.bin/tauri "${build_args[@]}"

app_path="$(find -L src-tauri/target -path "*/bundle/macos/$app_name.app" -type d -print 2>/dev/null | sort | tail -n 1)"

if [[ -z "$app_path" ]]; then
  echo "Could not find built $app_name.app under src-tauri/target" >&2
  exit 1
fi

open "$app_path"
echo "Launched $app_path"
