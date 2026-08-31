#!/usr/bin/env bash

set -euo pipefail

VERSION="v0.1.0"

ARM64_SHA256="63db7d57c7a2a5b36a1313bf0858c60a58897336ba851de9376cb931ac94373c"
X86_64_SHA256="01563e8cbb842baa00cd1a0f99bc8300bd4f1b8aece033bfd406fd3e9de5caaa"

case "$(uname -m)" in
  arm64)
    ARCH="arm64"
    SHA256="$ARM64_SHA256"
    ;;
  x86_64)
    ARCH="x86_64"
    SHA256="$X86_64_SHA256"
    ;;
  *)
    echo "Unsupported macOS architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

ARCHIVE="cas-build-cache-${VERSION}-macos-${ARCH}.tar.gz"
URL="https://github.com/sergioboi/xcodecache-alpha-releases/releases/download/${VERSION}/${ARCHIVE}"

INSTALL_DIR="${HOME}/.local/bin"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

DOWNLOAD="${TMP_DIR}/${ARCHIVE}"

echo "Downloading CASBuildCache ${VERSION} for ${ARCH}"

curl \
  --fail \
  --location \
  --silent \
  --show-error \
  "$URL" \
  --output "$DOWNLOAD"

echo "${SHA256}  ${DOWNLOAD}" | shasum -a 256 -c -

tar -xzf "$DOWNLOAD" -C "$TMP_DIR"

mkdir -p "$INSTALL_DIR"

install -m 0755 "${TMP_DIR}/cas-cache-server" "${INSTALL_DIR}/cas-cache-server"
install -m 0755 "${TMP_DIR}/cas-cache-cli" "${INSTALL_DIR}/cas-cache-cli"

"${INSTALL_DIR}/cas-cache-server" --help >/dev/null
"${INSTALL_DIR}/cas-cache-cli" --help >/dev/null

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$INSTALL_DIR" >> "$GITHUB_PATH"
fi

echo "Installed CASBuildCache ${VERSION} (${ARCH})"
