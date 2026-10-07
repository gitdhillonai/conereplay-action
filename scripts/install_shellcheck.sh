#!/usr/bin/env bash
# Pinned shellcheck 0.11.0. The release has no checksum file, so the
# expected sha256 values are the GitHub asset digests recorded here.
set -euo pipefail

VERSION="0.11.0"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/.tools/shellcheck"

if [ -x "$DEST" ] && "$DEST" --version 2>/dev/null | grep -q "$VERSION"; then
  exit 0
fi

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$(uname -m)" in
  x86_64) arch="x86_64" ;;
  aarch64 | arm64) arch="aarch64" ;;
  *)
    echo "install_shellcheck: unsupported architecture $(uname -m)" >&2
    exit 1
    ;;
esac
case "$os" in
  linux | darwin) ;;
  *)
    echo "install_shellcheck: unsupported OS $os" >&2
    exit 1
    ;;
esac

asset="shellcheck-v${VERSION}.${os}.${arch}.tar.gz"
case "$asset" in
  shellcheck-v0.11.0.darwin.aarch64.tar.gz)
    expected="339b930feb1ea764467013cc1f72d09cd6b869ebf1013296ba9055ab2ffbd26f"
    ;;
  shellcheck-v0.11.0.darwin.x86_64.tar.gz)
    expected="c2c15e08df0e8fbc374c335b230a7ee958c313fa5714817a59aa59f1aa594f51"
    ;;
  shellcheck-v0.11.0.linux.aarch64.tar.gz)
    expected="68a8133197a50beb8803f8d42f9908d1af1c5540d4bb05fdfca8c1fa47decefc"
    ;;
  shellcheck-v0.11.0.linux.x86_64.tar.gz)
    expected="b7af85e41cc99489dcc21d66c6d5f3685138f06d34651e6d34b42ec6d54fe6f6"
    ;;
  *)
    echo "install_shellcheck: no pinned checksum for $asset" >&2
    exit 1
    ;;
esac

base="https://github.com/koalaman/shellcheck/releases/download/v${VERSION}"
mkdir -p "$ROOT/.tools"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$base/$asset" -o "$tmp/shellcheck.tar.gz"
if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "$tmp/shellcheck.tar.gz" | awk '{print $1}')"
else
  actual="$(shasum -a 256 "$tmp/shellcheck.tar.gz" | awk '{print $1}')"
fi
if [ "$actual" != "$expected" ]; then
  echo "install_shellcheck: checksum mismatch for $asset" >&2
  exit 1
fi
tar -xzf "$tmp/shellcheck.tar.gz" -C "$tmp"
bin="$(find "$tmp" -type f -name shellcheck -print -quit)"
if [ -z "$bin" ]; then
  echo "install_shellcheck: archive has no shellcheck binary" >&2
  exit 1
fi
install -m 0755 "$bin" "$DEST"
