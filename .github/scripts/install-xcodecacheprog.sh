#!/usr/bin/env bash

set -euo pipefail

VERSION="v0.1.1"

ARM64_SHA256="685c1a641e8f8ac9452b753427779428a0404f601c9ccab95d69f28a31d5ab6e"
X86_64_SHA256="4139dc2e67ecf6956dd1c50336226661544e95ccd23dccd5503dae350a29355d"

MACHINE_ARCH="$(uname -m)"

case "$MACHINE_ARCH" in
  arm64)
    RELEASE_ARCH="arm64"
    SHA256="$ARM64_SHA256"
    ;;
  x86_64)
    RELEASE_ARCH="x86_64"
    SHA256="$X86_64_SHA256"
    ;;
  *)
    echo "Unsupported architecture: $MACHINE_ARCH" >&2
    exit 1
    ;;
esac

ARCHIVE="xcodecacheprog-${VERSION}-macos-${RELEASE_ARCH}.tar.gz"
URL="https://github.com/sergioboi/xcodecache-alpha-releases/releases/download/${VERSION}/${ARCHIVE}"

INSTALL_DIR="${HOME}/.local/bin"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

DOWNLOAD="${TMP_DIR}/${ARCHIVE}"

echo "Installing xcodecacheprog ${VERSION} for ${RELEASE_ARCH}"

curl \
  --fail \
  --location \
  --silent \
  --show-error \
  "$URL" \
  --output "$DOWNLOAD"

echo "${SHA256}  ${DOWNLOAD}" | shasum -a 256 -c -

tar \
  -xzf "$DOWNLOAD" \
  -C "$TMP_DIR"

mkdir -p "$INSTALL_DIR"

install \
  -m 0755 \
  "${TMP_DIR}/xcodecacheprog" \
  "${INSTALL_DIR}/xcodecacheprog"

"${INSTALL_DIR}/xcodecacheprog" --help >/dev/null

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$INSTALL_DIR" >> "$GITHUB_PATH"
fi

echo "Installed ${INSTALL_DIR}/xcodecacheprog"
