#!/usr/bin/env bash
# Download a pinned gitleaks binary into .tools/. No pipe to a shell.
set -euo pipefail

VERSION="8.30.1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/.tools/gitleaks"

if [ -x "$DEST" ] && "$DEST" version 2>/dev/null | grep -q "$VERSION"; then
  exit 0
fi

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$(uname -m)" in
  x86_64) arch="x64" ;;
  aarch64 | arm64) arch="arm64" ;;
  *)
    echo "install_gitleaks: unsupported architecture $(uname -m)" >&2
    exit 1
    ;;
esac
case "$os" in
  linux | darwin) ;;
  *)
    echo "install_gitleaks: unsupported OS $os" >&2
    exit 1
    ;;
esac

asset="gitleaks_${VERSION}_${os}_${arch}.tar.gz"
base="https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}"
mkdir -p "$ROOT/.tools"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$base/$asset" -o "$tmp/gitleaks.tar.gz"
curl -fsSL "$base/gitleaks_${VERSION}_checksums.txt" -o "$tmp/checksums.txt"
expected="$(awk -v name="$asset" '$2 == name { print $1 }' "$tmp/checksums.txt")"
if [ -z "$expected" ]; then
  echo "install_gitleaks: no checksum for $asset" >&2
  exit 1
fi
actual="$(sha256sum "$tmp/gitleaks.tar.gz" 2>/dev/null | awk '{print $1}' || true)"
if [ -z "$actual" ]; then
  actual="$(shasum -a 256 "$tmp/gitleaks.tar.gz" | awk '{print $1}')"
fi
if [ "$actual" != "$expected" ]; then
  echo "install_gitleaks: checksum mismatch for $asset" >&2
  exit 1
fi
tar -xzf "$tmp/gitleaks.tar.gz" -C "$tmp" gitleaks
install -m 0755 "$tmp/gitleaks" "$DEST"
