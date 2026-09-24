#!/usr/bin/env bash
set -euo pipefail

: "${THEOS:?Set THEOS to your Theos directory}"
IOS_SDK_VERSION="${IOS_SDK_VERSION:-9.3}"
SDK_PATH="$THEOS/sdks/iPhoneOS${IOS_SDK_VERSION}.sdk"

if [[ ! -d "$SDK_PATH" ]]; then
  echo "error: required SDK not found: $SDK_PATH" >&2
  echo "available iPhoneOS SDKs:" >&2
  find "$THEOS/sdks" -maxdepth 1 -type d -name 'iPhoneOS*.sdk' -printf '  %f\n' 2>/dev/null | sort >&2 || true
  exit 1
fi

echo "THEOS=$THEOS"
echo "IOS_SDK_VERSION=$IOS_SDK_VERSION"
echo "SDK_PATH=$SDK_PATH"
echo "ARCHS=armv7 arm64"
echo "DEPLOYMENT_TARGET=7.0"

make clean
make package FINALPACKAGE=1 IOS_SDK_VERSION="$IOS_SDK_VERSION"

echo "Built packages:"
find packages -maxdepth 1 -type f -name '*.deb' -print | sort
