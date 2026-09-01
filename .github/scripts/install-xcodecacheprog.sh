#!/usr/bin/env bash

set -euo pipefail

VERSION="v0.1.0"

ARM64_SHA256="d7bf11c526ae7d943db91f195fc532be304be8ae3b858938bba451c84bfc32ec"
X86_64_SHA256="2d5cacda2556a302f6915a642fec8a61da4a99f02e4f73d34cb432f07a5fb6a7"

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
