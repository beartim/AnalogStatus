# GitHub Actions build guide

The repository includes `.github/workflows/build.yml`. It builds the classic/rootful AnalogStatus package for iOS 9 and uploads the `.deb` plus build/verification logs as a GitHub Actions artifact.

## Why the workflow uses the iPhoneOS 9.3 SDK

The historical local build notes used iPhoneOS 9.2. For CI, the workflow intentionally uses the patched `iPhoneOS9.3.sdk` from the official `theos/sdks` repository instead of depending on an unmaintained third-party 9.2 SDK mirror.

The deployment target stays at iOS 7.0 and the package itself is restricted to firmware below iOS 10, so using the 9.3 SDK does not make iOS 9.3 the minimum runtime version. The tweak still builds both `armv7` and `arm64` slices.

## How to use

1. Create a GitHub repository.
2. Put the contents of this source directory at the repository root. `.github/workflows/build.yml` must therefore be present exactly at that path.
3. Push to `main` or `master`, create a pull request, push a tag beginning with `v`, or open **Actions → Build AnalogStatus iOS 9 DEB → Run workflow**.
4. Open the completed workflow run and download the artifact named `AnalogStatus-1.3-4-opt-ios9`.
5. The artifact contains the generated `.deb`, `build.log`, and `verify.log`.

No Apple SDK files are stored in this repository. The CI job obtains Theos and the patched SDK from their upstream repositories during setup.

## What CI verifies

The workflow fails the verification stage unless all of the following are true:

- package id is `com.faz.analog.optimized`;
- version is `1.3-4+opt`;
- Debian architecture is `iphoneos-arm`;
- the MobileSubstrate tweak dylib exists;
- the PreferenceLoader entry and preference bundle exist;
- both the tweak dylib and preference bundle executable are universal Mach-O files containing ARM (`armv7`) and ARM64 slices.

## SDK override

For a local/alternate Theos environment, the Makefiles and `build-ios9.sh` accept an SDK override:

```sh
IOS_SDK_VERSION=9.2 THEOS=/opt/theos ./build-ios9.sh
```

That only works if `$THEOS/sdks/iPhoneOS9.2.sdk` actually exists. The included GitHub workflow deliberately stays on the official patched 9.3 SDK.

## Build command used by CI

```sh
THEOS="$GITHUB_WORKSPACE/theos" IOS_SDK_VERSION=9.3 ./build-ios9.sh
```

The build itself ultimately runs:

```sh
make package FINALPACKAGE=1 IOS_SDK_VERSION=9.3
```

## If Actions fails

Check `build.log` first. Common classes of failure are:

- upstream Theos/action changes;
- GitHub runner image changes;
- SDK checkout/network failures;
- actual Objective-C/Logos compile or link errors.

If compilation succeeds but verification fails, inspect `verify.log`; it deliberately catches accidental single-architecture packages and missing package payload files.
