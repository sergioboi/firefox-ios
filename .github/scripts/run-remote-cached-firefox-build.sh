#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${XCODECACHEPROG_TOKEN:-}" ]]; then
  echo "XCODECACHEPROG_TOKEN is required for remote cache builds" >&2
  exit 1
fi

WORKSPACE="${GITHUB_WORKSPACE:-$(pwd)}"
CREDENTIAL_NAME="${XCODECACHEPROG_CREDENTIAL_NAME:-firefox-ios}"
CONFIG_DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/xcodecacheprog"
CONFIG_FILE="${CONFIG_DIR}/XcodeRemoteCache.xcconfig"
DERIVED_DATA_PATH="${HOME}/DerivedData"

mkdir -p "$CONFIG_DIR"

echo "Configuring Xcode remote compilation cache"
xcodecacheprog sync \
  --credential-name "$CREDENTIAL_NAME" \
  --credential-env XCODECACHEPROG_TOKEN

echo "Writing remote cache xcconfig: ${CONFIG_FILE}"
xcodecacheprog config > "$CONFIG_FILE"

echo "Removing Firefox DerivedData before build"
rm -rf "$DERIVED_DATA_PATH"
rm -rf "${HOME}/Library/Developer/Xcode/DerivedData"

echo "Remote cache status before build"
xcodecacheprog status

echo "=== Xcode selection ==="
xcode-select -p
xcodebuild -version

echo "=== Effective settings ==="
XCODE_XCCONFIG_FILE="$CONFIG_FILE" \
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
XCODE_XCCONFIG_FILE="$CONFIG_FILE" \
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
  -skipMacroValidation

echo
echo "Remote cache status after build"
xcodecacheprog status
