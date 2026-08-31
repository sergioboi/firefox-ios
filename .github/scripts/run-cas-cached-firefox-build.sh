#!/usr/bin/env bash

set -euo pipefail

WORKSPACE="${GITHUB_WORKSPACE:-$(pwd)}"
CACHE_DIR="${WORKSPACE}/.ci/cas-build-cache"
STATE_DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/cas-build-cache"
CONFIG_FILE="${STATE_DIR}/config.toml"
SOCKET_PATH="${HOME}/.local/state/cas-build-cache/cache.sock"
EXPORT_DIR="${STATE_DIR}/exports"
SERVER_LOG="${STATE_DIR}/server.log"
DERIVED_DATA_PATH="${HOME}/DerivedData"

mkdir -p "$CACHE_DIR"
mkdir -p "$STATE_DIR"
mkdir -p "$(dirname "$SOCKET_PATH")"
mkdir -p "$EXPORT_DIR"

cat > "$CONFIG_FILE" <<EOF
[server]
socket_path = "${SOCKET_PATH}"
enable_write_to_disk = true
export_dir = "${EXPORT_DIR}"

[storage]
base_dir = "${CACHE_DIR}"
cas_backend = "file"
kv_backend = "sqlite"
cas_directory_levels = 2
verify_on_read = false
sqlite_wal_mode = true

[eviction]
max_size = "8 GB"
high_water_mark = 0.95
low_water_mark = 0.85
kv_ttl_seconds = 2592000
cas_ttl_seconds = 0
check_interval_seconds = 300
max_evict_per_cycle = 10000

[logging]
level = "debug"
format = "pretty"
EOF

echo "CAS storage: ${CACHE_DIR}"
echo "CAS socket:  ${SOCKET_PATH}"
echo "CAS config:  ${CONFIG_FILE}"

RUST_LOG=cas_build_cache=debug \
  cas-cache-server \
  --config "$CONFIG_FILE" \
  --foreground \
  --verbose \
  >"$SERVER_LOG" 2>&1 &

SERVER_PID=$!

stop_server() {
  if kill -0 "$SERVER_PID" 2>/dev/null; then
    kill -INT "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}

trap stop_server EXIT

for _ in $(seq 1 100); do
  if [[ -S "$SOCKET_PATH" ]]; then
    break
  fi

  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "CASBuildCache server exited before creating its socket" >&2
    cat "$SERVER_LOG" >&2 || true
    exit 1
  fi

  sleep 0.1
done

if [[ ! -S "$SOCKET_PATH" ]]; then
  echo "CASBuildCache socket was not created: ${SOCKET_PATH}" >&2
  cat "$SERVER_LOG" >&2 || true
  exit 1
fi

echo "Removing Firefox DerivedData before build"
rm -rf "$DERIVED_DATA_PATH"
rm -rf "${HOME}/Library/Developer/Xcode/DerivedData"

echo "Cache status before build"
cas-cache-cli --config "$CONFIG_FILE" status

echo "=== Xcode selection ==="
xcode-select -p
xcodebuild -version

echo "=== Effective settings ==="
xcodebuild \
  -project firefox-ios/Client.xcodeproj \
  -scheme Fennec \
  -configuration Fennec_Testing \
  -destination 'generic/platform=iOS Simulator' \
  -showBuildSettings |
grep -E 'DT_TOOLCHAIN_DIR|TOOLCHAIN_DIR|HEADER_SEARCH_PATHS|SDKROOT'

echo "Resolving Swift package dependencies"
xcodebuild \
  -project "${WORKSPACE}/firefox-ios/Client.xcodeproj" \
  -resolvePackageDependencies \
  -onlyUsePackageVersionsFromResolvedFile

echo "Running Firefox build-for-testing"
xcodebuild \
  -project "${WORKSPACE}/firefox-ios/Client.xcodeproj" \
  -scheme Fennec \
  -configuration Fennec_Testing \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=26.2" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build-for-testing \
  CODE_SIGN_IDENTITY= \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -skipMacroValidation \
  COMPILATION_CACHE_ENABLE_CACHING=YES \
  COMPILATION_CACHE_ENABLE_PLUGIN=YES \
  COMPILATION_CACHE_REMOTE_SERVICE_PATH="$SOCKET_PATH"

stop_server
trap - EXIT

echo
echo "Cache status after build"
cas-cache-cli --config "$CONFIG_FILE" status

echo
echo "CASBuildCache request summary"
echo "KV hits:       $(grep -c 'GetValue: hit' "$SERVER_LOG" || true)"
echo "KV misses:     $(grep -c 'GetValue: miss' "$SERVER_LOG" || true)"
echo "CAS Get hits:  $(grep -c 'Get: hit' "$SERVER_LOG" || true)"
echo "CAS Get miss:  $(grep -c 'Get: miss' "$SERVER_LOG" || true)"
echo "CAS Load hits: $(grep -c 'Load: hit' "$SERVER_LOG" || true)"
echo "CAS Load miss: $(grep -c 'Load: miss' "$SERVER_LOG" || true)"
echo "KV puts:       $(grep -c 'PutValue: success' "$SERVER_LOG" || true)"
echo "CAS puts:      $(grep -c 'Put: success' "$SERVER_LOG" || true)"
echo "CAS saves:     $(grep -c 'Save: success' "$SERVER_LOG" || true)"

echo
echo "Recent cache requests:"
grep -E \
  'GetValue: (hit|miss)|Get: (hit|miss)|Load: (hit|miss)|PutValue: success|Put: success|Save: success' \
  "$SERVER_LOG" \
  | tail -n 100 \
  || true
