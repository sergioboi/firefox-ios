#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="${REPO_ROOT}/firefox-ios/Client.xcodeproj"

SCHEME="${FIREFOX_SCHEME:-Fennec}"
CONFIGURATION="${FIREFOX_CONFIGURATION:-Fennec_Testing}"
TEST_PLAN="${FIREFOX_TEST_PLAN:-UnitTest}"
DESTINATION="${FIREFOX_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=26.2}"
DERIVED_DATA_PATH="${FIREFOX_DERIVED_DATA_PATH:-${HOME}/DerivedData}"

if [[ ! -d "$PROJECT" ]]; then
  echo "Firefox project not found: $PROJECT" >&2
  exit 1
fi

echo "=== Firefox build-for-testing ==="
echo "Project:       $PROJECT"
echo "Scheme:        $SCHEME"
echo "Configuration: $CONFIGURATION"
echo "Test plan:     $TEST_PLAN"
echo "Destination:   $DESTINATION"
echo "DerivedData:   $DERIVED_DATA_PATH"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -testPlan "$TEST_PLAN" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -skipMacroValidation \
  build-for-testing \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGN_IDENTITY= \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  "$@"

PRODUCTS_DIR="${DERIVED_DATA_PATH}/Build/Products"

if [[ ! -d "$PRODUCTS_DIR" ]]; then
  echo "Build products not found after build: $PRODUCTS_DIR" >&2
  exit 1
fi

XCTESTRUN_FILE="$(
  find "$PRODUCTS_DIR" \
    -type f \
    -name "${SCHEME}_${TEST_PLAN}_*.xctestrun" \
    -print \
    -quit
)"

if [[ -z "$XCTESTRUN_FILE" ]]; then
  echo "Expected .xctestrun was not generated." >&2
  echo "Available .xctestrun files:" >&2

  find "$PRODUCTS_DIR" \
    -type f \
    -name '*.xctestrun' \
    -print >&2 || true

  exit 1
fi

echo
echo "Generated XCTest run file:"
echo "$XCTESTRUN_FILE"
