#!/bin/bash
# Put a release's frameworks where the samples expect them: XCFrameworks/.
#
#   Scripts/fetch-xcframeworks.sh            the version Package.swift names
#   Scripts/fetch-xcframeworks.sh 1.2.3      a specific release
#
# The two XCFramework zips are checked against the checksums in Package.swift
# when the version matches, so the samples build against exactly what SwiftPM
# would download.
set -euo pipefail
cd "$(dirname "$0")/.."
PINNED="$(sed -n 's/^let version = "\(.*\)"$/\1/p' Package.swift)"
V="${1:-$PINNED}"
[ -n "$V" ] || { echo "no version given, and none found in Package.swift" >&2; exit 1; }
REPO="ComOfficeKit/ComOfficeKit-Apple"
BASE="https://github.com/$REPO/releases/download/$V"

rm -rf XCFrameworks; mkdir -p XCFrameworks
for a in DocumentCore.xcframework.zip AppleRender.xcframework.zip; do
  # Public releases download anonymously; `gh` is the fallback for a checkout
  # that can only see them signed in.
  if ! curl -fsSL -o "XCFrameworks/$a" "$BASE/$a"; then
    command -v gh >/dev/null 2>&1 && gh release download "$V" --repo "$REPO" --pattern "$a" --dir XCFrameworks --clobber \
      || { echo "could not download $a from $BASE" >&2; exit 1; }
  fi
  if [ "$V" = "$PINNED" ]; then
    case "$a" in
      DocumentCore.xcframework.zip|AppleRender.xcframework.zip)
        name="${a%.xcframework.zip}"
        want="$(sed -n "s/.*binaryTarget(name: \"$name\".*checksum: \"\([0-9a-f]*\)\".*/\1/p" Package.swift)"
        got="$(swift package compute-checksum "XCFrameworks/$a")"
        [ "$want" = "$got" ] || { echo "$a does not match Package.swift (expected $want, got $got)" >&2; exit 1; } ;;
    esac
  fi
  (cd XCFrameworks && unzip -q -o "$a" && rm "$a")
done
ls XCFrameworks
