#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${XCODECACHEPROG_TOKEN:-}" ]]; then
  echo "XCODECACHEPROG_TOKEN is required for remote cache builds" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="${REPO_ROOT}/firefox-ios"
CREDENTIAL_NAME="${XCODECACHEPROG_CREDENTIAL_NAME:-firefox-ios}"
CONFIG_FILE="${PROJECT_DIR}/XcodeRemoteCache.xcconfig"
DERIVED_DATA_PATH="${FIREFOX_DERIVED_DATA_PATH:-${HOME}/DerivedData}"

run_xcodecacheprog() {
  (
    cd "$PROJECT_DIR"
    xcodecacheprog "$@"
  )
}

if [[ ! -d "${PROJECT_DIR}/Client.xcodeproj" ]]; then
  echo "Expected Firefox Xcode project at ${PROJECT_DIR}/Client.xcodeproj" >&2
  exit 1
fi

if [[ ! -f "${PROJECT_DIR}/.xcodecacheprog/project.json" ]]; then
  echo "Expected xcodecacheprog setup at ${PROJECT_DIR}/.xcodecacheprog/project.json" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Expected remote cache xcconfig at ${CONFIG_FILE}" >&2
  exit 1
fi

echo "Repository root: ${REPO_ROOT}"
echo "Xcode project root: ${PROJECT_DIR}"
echo "Remote cache xcconfig: ${CONFIG_FILE}"

echo "Configuring Xcode remote compilation cache"
run_xcodecacheprog sync \
  --credential-name "$CREDENTIAL_NAME" \
  --credential-env XCODECACHEPROG_TOKEN

echo "Removing Firefox DerivedData before build"
rm -rf "$DERIVED_DATA_PATH"
rm -rf "${HOME}/Library/Developer/Xcode/DerivedData"

echo "Remote cache status before build"
run_xcodecacheprog status

echo "=== Xcode selection ==="
xcode-select -p
xcodebuild -version

echo "=== Effective settings ==="
XCODE_XCCONFIG_FILE="$CONFIG_FILE" \
xcodebuild \
  -project "${PROJECT_DIR}/Client.xcodeproj" \
  -scheme "${FIREFOX_SCHEME:-Fennec}" \
  -configuration "${FIREFOX_CONFIGURATION:-Fennec_Testing}" \
  -destination 'generic/platform=iOS Simulator' \
  -showBuildSettings |
grep -E 'DT_TOOLCHAIN_DIR|TOOLCHAIN_DIR|HEADER_SEARCH_PATHS|SDKROOT'

echo "Resolving Swift package dependencies"
xcodebuild \
  -project "${PROJECT_DIR}/Client.xcodeproj" \
  -resolvePackageDependencies \
  -onlyUsePackageVersionsFromResolvedFile

echo "Running Firefox build-for-testing"
XCODE_XCCONFIG_FILE="$CONFIG_FILE" \
"${REPO_ROOT}/.github/scripts/run-firefox-build-for-testing.sh"

echo
echo "Remote cache status after build"
run_xcodecacheprog status
