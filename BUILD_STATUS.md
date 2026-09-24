# Build status

## Local execution environment

The iOS 9 compatibility audit and source corrections are complete. The current ChatGPT execution environment itself does not contain Theos or an iPhoneOS SDK, so it still cannot link an installable iOS tweak locally.

The earlier local build attempt stopped before compilation with:

```text
Makefile:4: /opt/theos/makefiles/common.mk: No such file or directory
make: *** No rule to make target '/opt/theos/makefiles/common.mk'.  Stop.
```

## GitHub Actions path now included

This source tree now includes `.github/workflows/build.yml`, which provisions Theos in a GitHub Ubuntu runner, uses the maintained patched iPhoneOS 9.3 SDK, builds a classic/rootful `armv7 + arm64` package and uploads the resulting `.deb` plus logs.

The workflow also validates the Debian metadata, expected payload paths and both Mach-O architecture slices before considering the package verified.

## What is ready

- `Tweak.xm`: audited iOS 9 lock-screen/status-bar implementation.
- `ASAnalogRenderer.*`: optimized minute-aware rendering/cache.
- `analogprefs`: preference bundle source.
- `Makefile`: armv7 + arm64, default iPhoneOS 9.3 SDK, iOS 7.0 deployment target.
- `build-ios9.sh`: one-command local/CI build with an SDK override option.
- `.github/workflows/build.yml`: GitHub Actions build and artifact upload.
- `scripts/verify-package.sh`: DEB structure/metadata verification.
- `scripts/check-fat-mach-o.py`: armv7 + arm64 fat-Mach-O validation.
- `docs/GITHUB_ACTIONS.md`: repository setup and CI troubleshooting.
- `docs/ios9-device-compat-audit.md`: device-oriented audit and hardware test matrix.

## Commands

GitHub Actions uses the default maintained SDK:

```sh
THEOS=/path/to/theos IOS_SDK_VERSION=9.3 ./build-ios9.sh
```

A local historical 9.2 SDK remains supported when present:

```sh
THEOS=/path/to/theos IOS_SDK_VERSION=9.2 ./build-ios9.sh
```

The expected output package version is `1.3-4+opt`.
