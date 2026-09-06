#!/usr/bin/env bash

set -euo pipefail

SCHEME="${FIREFOX_SCHEME:-Fennec}"
TEST_PLAN="${FIREFOX_TEST_PLAN:-UnitTest}"
DESTINATION="${FIREFOX_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=26.2}"
DERIVED_DATA_PATH="${HOME}/DerivedData"

PRODUCTS_DIR="${DERIVED_DATA_PATH}/Build/Products"

if [[ ! -d "$PRODUCTS_DIR" ]]; then
  echo "Build products not found: $PRODUCTS_DIR" >&2
  echo "Run build-for-testing first." >&2
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
  echo "No ${SCHEME}_${TEST_PLAN}_*.xctestrun found." >&2
  echo "Available .xctestrun files:" >&2

  find "$PRODUCTS_DIR" \
    -type f \
    -name '*.xctestrun' \
    -print >&2 || true

  exit 1
fi

RESULT_BUNDLE_PATH="${FIREFOX_RESULT_BUNDLE_PATH:-${RUNNER_TEMP:-/tmp}/firefox-${TEST_PLAN}.xcresult}"

rm -rf "$RESULT_BUNDLE_PATH"

echo "=== Firefox test-without-building ==="
echo "XCTest run:    $XCTESTRUN_FILE"
echo "Destination:   $DESTINATION"
echo "Result bundle: $RESULT_BUNDLE_PATH"

TEST_EXIT_CODE=0
xcodebuild \
  test-without-building \
  -xctestrun "$XCTESTRUN_FILE" \
  -destination "$DESTINATION" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 60 \
  -maximum-test-execution-time-allowance 60 \
  "$@" || TEST_EXIT_CODE=$?

if [[ -d "$RESULT_BUNDLE_PATH" ]]; then
  echo
  echo "=== Failed tests ==="
  if ! xcrun xcresulttool get test-results summary \
    --path "$RESULT_BUNDLE_PATH" \
    --compact |
    jq -r '
      .testFailures[]? |
      "FAILED \(.targetName)/\(.testIdentifierString)\n  \(.failureText)\n"
    '; then
    echo "Unable to parse test result bundle: $RESULT_BUNDLE_PATH" >&2
  fi
else
  echo "Test result bundle not found: $RESULT_BUNDLE_PATH" >&2
fi

exit "$TEST_EXIT_CODE"
