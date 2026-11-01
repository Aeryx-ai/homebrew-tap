#!/usr/bin/env bash
# Tests for scripts/update.sh against fake manifests and tag tarballs served over file://.
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

tarball() { # dir repo version: a fake GitHub tag tarball, prints its sha256
  local d=$1/$2/archive/refs/tags
  mkdir -p "$d" "$work/src/$2-$3"
  echo "$2 $3" >"$work/src/$2-$3/README"
  tar -czf "$d/v$3.tar.gz" -C "$work/src" "$2-$3"
  shasum -a 256 "$d/v$3.tar.gz" | cut -d' ' -f1
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
want=$(tarball "$srv" sock-cli 0.3.0)
tap=$(newtap)
if GITHUB_ARCHIVE_URL="file://$srv" "$tap/scripts/update.sh" formula sock 0.3.0; then
  f=$tap/Formula/sock.rb
  if [ -f "$f" ]; then
    contains "$f" 'class Sock < Formula' "formula sock"
    contains "$f" 'url "https://github.com/Aeryx-ai/sock-cli/archive/refs/tags/v0.3.0.tar.gz"' "formula sock"
    contains "$f" "sha256 \"$want\"" "formula sock"
    contains "$f" 'license "MIT"' "formula sock"
    contains "$f" 'head "https://github.com/Aeryx-ai/sock-cli.git", branch: "main"' "formula sock"
    contains "$f" 'depends_on "go" => :build' "formula sock"
    contains "$f" 'system "go", "build", *std_go_args(ldflags: "-s -w -X main.version=#{version}"), "./cmd/sock"' "formula sock"
    contains "$f" '--version' "formula sock"
    ! grep -q 'on_macos\|bin.install\|downloads.joinsock' "$f" || fail "formula sock: binary leftovers"
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
want=$(tarball "$srv" sock-mcp 1.2.3)
tap=$(newtap)
if GITHUB_ARCHIVE_URL="file://$srv" "$tap/scripts/update.sh" formula sock-mcp 1.2.3; then
  f=$tap/Formula/sock-mcp.rb
  contains "$f" 'class SockMcp < Formula' "formula sock-mcp"
  contains "$f" 'url "https://github.com/Aeryx-ai/sock-mcp/archive/refs/tags/v1.2.3.tar.gz"' "formula sock-mcp"
  contains "$f" "sha256 \"$want\"" "formula sock-mcp"
  contains "$f" 'head "https://github.com/Aeryx-ai/sock-mcp.git", branch: "main"' "formula sock-mcp"
  contains "$f" '"./cmd/sock-mcp"' "formula sock-mcp"
  contains "$f" 'outbound-only' "formula sock-mcp"
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
  contains "$f" 'url "https://downloads.example/releases/mac/#{version}/Sock-#{version}.dmg"' "cask sock"
  contains "$f" 'strategy :sparkle, &:short_version' "cask sock"
  contains "$f" 'app "Sock.app"' "cask sock"
  contains "$f" 'depends_on macos: :tahoe' "cask sock"
  contains "$f" 'auto_updates true' "cask sock"
  check_ruby "$f"
  pass "cask sock"
else
  fail "cask sock: exit $?"
fi

# missing tarball: nothing written, existing file untouched
tap=$(newtap)
mkdir -p "$tap/Formula"
echo keep >"$tap/Formula/sock.rb"
if GITHUB_ARCHIVE_URL="file://$work/nowhere" "$tap/scripts/update.sh" formula sock 0.3.0 2>/dev/null; then
  fail "missing tarball: exited 0"
elif [ "$(cat "$tap/Formula/sock.rb")" != keep ]; then
  fail "missing tarball: overwrote formula"
else
  pass "missing tarball"
fi

# missing or bad formula version is refused before any download
srv=$work/srv1
for v in "" v0.3.0 0.3 0.3.0-rc1 latest; do
  tap=$(newtap)
  if GITHUB_ARCHIVE_URL="file://$srv" "$tap/scripts/update.sh" formula sock ${v:+"$v"} 2>/dev/null || [ -e "$tap/Formula/sock.rb" ]; then
    fail "bad version [$v]"
  else
    pass "bad version [$v]"
  fi
done

# missing mac manifest
tap=$(newtap)
if DOWNLOADS_URL="file://$work/nowhere" "$tap/scripts/update.sh" cask sock 2>/dev/null || [ -e "$tap/Casks/sock.rb" ]; then
  fail "missing mac manifest"
else
  pass "missing mac manifest"
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
if "$tap/scripts/update.sh" formula nope 1.0.0 2>/dev/null; then
  fail "unknown target"
else
  pass "unknown target"
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
