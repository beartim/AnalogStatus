#!/usr/bin/env bash
set -euo pipefail

DEB="${1:-}"
if [[ -z "$DEB" || ! -f "$DEB" ]]; then
  echo "usage: $0 <package.deb>" >&2
  exit 2
fi

EXPECTED_VERSION="1.3-4+opt"
EXPECTED_PACKAGE="com.faz.analog.optimized"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== Debian metadata =="
dpkg-deb -I "$DEB"

pkg="$(dpkg-deb -f "$DEB" Package)"
ver="$(dpkg-deb -f "$DEB" Version)"
arch="$(dpkg-deb -f "$DEB" Architecture)"

[[ "$pkg" == "$EXPECTED_PACKAGE" ]] || { echo "error: Package=$pkg, expected $EXPECTED_PACKAGE" >&2; exit 1; }
[[ "$ver" == "$EXPECTED_VERSION" ]] || { echo "error: Version=$ver, expected $EXPECTED_VERSION" >&2; exit 1; }
[[ "$arch" == "iphoneos-arm" ]] || { echo "error: Architecture=$arch, expected iphoneos-arm" >&2; exit 1; }

dpkg-deb -x "$DEB" "$TMP/root"

TWEAK="$TMP/root/Library/MobileSubstrate/DynamicLibraries/AnalogStatus.dylib"
PREFS="$TMP/root/Library/PreferenceBundles/analogprefs.bundle/analogprefs"
FILTER="$TMP/root/Library/MobileSubstrate/DynamicLibraries/AnalogStatus.plist"
PREF_ENTRY="$TMP/root/Library/PreferenceLoader/Preferences/analogprefs.plist"

for f in "$TWEAK" "$PREFS" "$FILTER" "$PREF_ENTRY"; do
  [[ -e "$f" ]] || { echo "error: expected package file missing: ${f#"$TMP/root"}" >&2; exit 1; }
done

echo "== Mach-O architecture check =="
file "$TWEAK" "$PREFS" || true
python3 "$ROOT_DIR/scripts/check-fat-mach-o.py" "$TWEAK"
python3 "$ROOT_DIR/scripts/check-fat-mach-o.py" "$PREFS"

echo "== Package file list =="
dpkg-deb -c "$DEB"

echo "verification passed: $DEB"
