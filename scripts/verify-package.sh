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
PREF_BUNDLE="$TMP/root/Library/PreferenceBundles/analogprefs.bundle"
PREFS="$PREF_BUNDLE/analogprefs"
PREF_INFO="$PREF_BUNDLE/Info.plist"
PREF_ROOT="$PREF_BUNDLE/Root.plist"
FILTER="$TMP/root/Library/MobileSubstrate/DynamicLibraries/AnalogStatus.plist"
PREF_ENTRY="$TMP/root/Library/PreferenceLoader/Preferences/analogprefs.plist"

for f in "$TWEAK" "$PREFS" "$PREF_INFO" "$PREF_ROOT" "$FILTER" "$PREF_ENTRY"; do
  [[ -e "$f" ]] || { echo "error: expected package file missing: ${f#"$TMP/root"}" >&2; exit 1; }
done

echo "== Preference bundle metadata/resource check =="
python3 - "$PREF_INFO" "$PREF_ROOT" <<'PY'
import plistlib
import sys

info_path, root_path = sys.argv[1:3]

with open(info_path, "rb") as f:
    info = plistlib.load(f)

expected_info = {
    "CFBundleExecutable": "analogprefs",
    "CFBundleIdentifier": "com.faz.analogprefs",
    "NSPrincipalClass": "APRootListController",
}

for key, expected in expected_info.items():
    actual = info.get(key)
    if actual != expected:
        raise SystemExit(
            f"error: {info_path}: {key}={actual!r}, expected {expected!r}"
        )

with open(root_path, "rb") as f:
    root = plistlib.load(f)

items = root.get("items")
if not isinstance(items, list) or not items:
    raise SystemExit(f"error: {root_path}: missing/non-empty items array")

cells = [item.get("cell") for item in items if isinstance(item, dict)]
if "PSSwitchCell" not in cells:
    raise SystemExit(f"error: {root_path}: no PSSwitchCell entries found")
if "PSButtonCell" not in cells:
    raise SystemExit(f"error: {root_path}: no PSButtonCell entries found")

print(f"{info_path}: executable/principal class OK")
print(f"{root_path}: {len(items)} preference specifiers OK")
PY

echo "== Mach-O architecture check =="
file "$TWEAK" "$PREFS" || true
python3 "$ROOT_DIR/scripts/check-fat-mach-o.py" "$TWEAK"
python3 "$ROOT_DIR/scripts/check-fat-mach-o.py" "$PREFS"

echo "== Package file list =="
dpkg-deb -c "$DEB"

echo "verification passed: $DEB"
