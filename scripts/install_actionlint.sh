#!/usr/bin/env bash
# Pinned actionlint binary. The reviewdog action cannot read the event
# file on this self-hosted runner.
set -euo pipefail

VERSION="1.7.12"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/.tools/actionlint"

if [ -x "$DEST" ] && "$DEST" -version 2>/dev/null | grep -q "$VERSION"; then
  exit 0
fi

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$(uname -m)" in
  x86_64) arch="amd64" ;;
  aarch64 | arm64) arch="arm64" ;;
  *)
    echo "install_actionlint: unsupported architecture $(uname -m)" >&2
    exit 1
    ;;
esac
case "$os" in
  linux | darwin) ;;
  *)
    echo "install_actionlint: unsupported OS $os" >&2
    exit 1
    ;;
esac

asset="actionlint_${VERSION}_${os}_${arch}.tar.gz"
base="https://github.com/rhysd/actionlint/releases/download/v${VERSION}"
mkdir -p "$ROOT/.tools"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$base/$asset" -o "$tmp/actionlint.tar.gz"
curl -fsSL "$base/actionlint_${VERSION}_checksums.txt" -o "$tmp/checksums.txt"
expected="$(awk -v name="$asset" '$2 == name { print $1 }' "$tmp/checksums.txt")"
if [ -z "$expected" ]; then
  echo "install_actionlint: no checksum for $asset" >&2
  exit 1
fi
if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "$tmp/actionlint.tar.gz" | awk '{print $1}')"
else
  actual="$(shasum -a 256 "$tmp/actionlint.tar.gz" | awk '{print $1}')"
fi
if [ "$actual" != "$expected" ]; then
  echo "install_actionlint: checksum mismatch for $asset" >&2
  exit 1
fi
tar -xzf "$tmp/actionlint.tar.gz" -C "$tmp" actionlint
install -m 0755 "$tmp/actionlint" "$DEST"
