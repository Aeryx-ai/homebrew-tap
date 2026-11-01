#!/usr/bin/env bash
# Tests for scripts/update.sh against fake manifests served over file://.
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

sha() { printf '%064d' "$1"; }

manifest() { # dir platform version file sha
  mkdir -p "$1/latest"
  printf '{"platform":"%s","version":"%s","file":"%s","url":"https://downloads.example/releases/%s/%s/%s","sha256":"%s","bytes":1,"publishedAt":"2026-11-01T00:00:00Z"}\n' \
    "$2" "$3" "$4" "$2" "$3" "$4" "$5" >"$1/latest/$2.json"
}

binaries() { # dir prefix fileprefix version
  local n=1 p
  for p in darwin-arm64 darwin-amd64 linux-arm64 linux-amd64; do
    manifest "$1" "$2-$p" "$4" "$3-$p.tar.gz" "$(sha "$n")"
    n=$((n + 1))
  done
}

newtap() { # fresh tap copy, prints its path
  local t
  t=$(mktemp -d "$work/tap.XXXX")
  mkdir -p "$t/scripts"
  cp "$root/scripts/update.sh" "$t/scripts/"
  echo "$t"
}

fail() {
  echo "FAIL: $*"
  failures=$((failures + 1))
}
pass() { echo "ok: $*"; }

contains() { grep -qF -- "$2" "$1" || fail "$3: missing [$2]"; }

check_ruby() {
  ruby -c "$1" >/dev/null || fail "ruby -c $1"
}

# formula sock
srv=$work/srv1
binaries "$srv" cli sock 0.3.0
tap=$(newtap)
if DOWNLOADS_URL="file://$srv" "$tap/scripts/update.sh" formula sock; then
  f=$tap/Formula/sock.rb
  if [ -f "$f" ]; then
    contains "$f" 'class Sock < Formula' "formula sock"
    contains "$f" 'version "0.3.0"' "formula sock"
    contains "$f" 'url "https://downloads.example/releases/cli-darwin-arm64/0.3.0/sock-darwin-arm64.tar.gz"' "formula sock"
    contains "$f" "sha256 \"$(sha 4)\"" "formula sock"
    contains "$f" 'on_macos do' "formula sock"
    contains "$f" 'on_linux do' "formula sock"
    contains "$f" 'on_arm do' "formula sock"
    contains "$f" 'on_intel do' "formula sock"
    contains "$f" 'bin.install "sock"' "formula sock"
    contains "$f" '--version' "formula sock"
    check_ruby "$f"
    [ "$(find "$tap" -type f ! -path "$tap/scripts/*" | wc -l | tr -d ' ')" = 1 ] || fail "formula sock wrote more than one file"
    pass "formula sock"
  else
    fail "formula sock: no file"
  fi
else
  fail "formula sock: exit $?"
fi

# formula sock-mcp
srv=$work/srv2
binaries "$srv" mcp sock-mcp 1.2.3
tap=$(newtap)
if DOWNLOADS_URL="file://$srv" "$tap/scripts/update.sh" formula sock-mcp; then
  f=$tap/Formula/sock-mcp.rb
  contains "$f" 'class SockMcp < Formula' "formula sock-mcp"
  contains "$f" 'version "1.2.3"' "formula sock-mcp"
  contains "$f" 'url "https://downloads.example/releases/mcp-linux-amd64/1.2.3/sock-mcp-linux-amd64.tar.gz"' "formula sock-mcp"
  contains "$f" 'bin.install "sock-mcp"' "formula sock-mcp"
  check_ruby "$f"
  pass "formula sock-mcp"
else
  fail "formula sock-mcp: exit $?"
fi

# cask sock
srv=$work/srv3
manifest "$srv" mac 1.4 Sock-1.4.dmg "$(sha 9)"
tap=$(newtap)
if DOWNLOADS_URL="file://$srv" "$tap/scripts/update.sh" cask sock; then
  f=$tap/Casks/sock.rb
  contains "$f" 'cask "sock" do' "cask sock"
  contains "$f" 'version "1.4"' "cask sock"
  contains "$f" "sha256 \"$(sha 9)\"" "cask sock"
  contains "$f" 'url "https://downloads.example/releases/mac/1.4/Sock-1.4.dmg"' "cask sock"
  contains "$f" 'app "Sock.app"' "cask sock"
  contains "$f" 'depends_on macos: :tahoe' "cask sock"
  contains "$f" 'auto_updates true' "cask sock"
  check_ruby "$f"
  pass "cask sock"
else
  fail "cask sock: exit $?"
fi

# missing manifest: one platform absent, nothing written, existing file untouched
srv=$work/srv4
binaries "$srv" cli sock 0.3.0
rm "$srv/latest/cli-linux-arm64.json"
tap=$(newtap)
mkdir -p "$tap/Formula"
echo keep >"$tap/Formula/sock.rb"
if DOWNLOADS_URL="file://$srv" "$tap/scripts/update.sh" formula sock 2>/dev/null; then
  fail "missing manifest: exited 0"
elif [ "$(cat "$tap/Formula/sock.rb")" != keep ]; then
  fail "missing manifest: overwrote formula"
else
  pass "missing manifest"
fi

# missing mac manifest
tap=$(newtap)
if DOWNLOADS_URL="file://$work/nowhere" "$tap/scripts/update.sh" cask sock 2>/dev/null || [ -e "$tap/Casks/sock.rb" ]; then
  fail "missing mac manifest"
else
  pass "missing mac manifest"
fi

# version mismatch across platforms
srv=$work/srv5
binaries "$srv" cli sock 0.3.0
manifest "$srv" cli-linux-amd64 0.3.1 sock-linux-amd64.tar.gz "$(sha 7)"
tap=$(newtap)
if DOWNLOADS_URL="file://$srv" "$tap/scripts/update.sh" formula sock 2>/dev/null || [ -e "$tap/Formula/sock.rb" ]; then
  fail "version mismatch"
else
  pass "version mismatch"
fi

# malformed sha256 is refused
srv=$work/srv6
manifest "$srv" mac 1.4 Sock-1.4.dmg nothex
tap=$(newtap)
if DOWNLOADS_URL="file://$srv" "$tap/scripts/update.sh" cask sock 2>/dev/null || [ -e "$tap/Casks/sock.rb" ]; then
  fail "bad sha256"
else
  pass "bad sha256"
fi

# unknown target is refused
tap=$(newtap)
if "$tap/scripts/update.sh" formula nope 2>/dev/null; then
  fail "unknown target"
else
  pass "unknown target"
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
