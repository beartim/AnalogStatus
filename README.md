# AnalogStatus 1.3-4 optimized reimplementation

This source tree is reconstructed from behavioral/static analysis of the supplied AnalogStatus 1.3-4 and 3.1 packages. It is **not the original author's source code**.

Goals:

- preserve the 1.3-4 iOS 9-era Status Bar analog clock;
- preserve the 1.3-4 Lock Screen large analog clock and date;
- remove the unsafe private-ivar dereferences found in the old binary;
- scope the status-bar width override to the time item only;
- avoid removing Apple's Lock Screen labels from their superview;
- stop/restart the Lock Screen timer with the view lifecycle;
- redraw the clock bitmap only when the minute or Lock Screen layout state changes;
- use a real minute/configuration-aware image cache;
- conditionally initialize SpringBoard-only hooks instead of probing them in every UIKit process;
- add preference-change notifications while keeping the original Respring button.

## Intended target

The Lock Screen hooks intentionally target the private classes used by the original 1.3-4 release (`SBLockScreenViewController` and `SBFLockScreenDateView`). They are therefore aimed at the same iOS 9-era environment. The 3.1 iPhone X/iOS 11 status-bar rewrite is documented in `docs/analysis.md` but is not mixed into this legacy Lock Screen implementation.

The package is classic/rootful, builds `armv7 + arm64`, uses an iOS 7.0 deployment target, and declares compatibility below iOS 10.

## GitHub Actions build

A ready-to-use workflow is included at:

```text
.github/workflows/build.yml
```

Push this directory as the repository root, then either push to `main`/`master` or use **Actions → Build AnalogStatus iOS 9 DEB → Run workflow**. The job downloads Theos, the Linux iOS toolchain, and the historical iPhoneOS 9.2 SDK pinned to a fixed GitHub commit, builds the tweak, verifies the package and both architecture slices, and uploads the `.deb` and logs as the `AnalogStatus-1.3-4-opt-ios9` artifact.

See `docs/GITHUB_ACTIONS.md` for setup and troubleshooting details.

## Local build

Install Theos with a patched iOS SDK, then run:

```sh
THEOS=/opt/theos ./build-ios9.sh
```

The default SDK is iPhoneOS 9.2. This is intentional for Linux: the 9.3 patched SDK can fail with legacy `.tbd` stubs such as `/usr/lib/system/liblaunch.dylib`, while the historical Theos Linux guidance recommends the 9.2 SDK for this toolchain generation.

```sh
THEOS=/opt/theos IOS_SDK_VERSION=9.2 ./build-ios9.sh
```

The package id is deliberately changed to `com.faz.analog.optimized` so it does not silently overwrite the historical package while testing. It still reads the historical preference domain `com.faz.analogprefs` for compatibility.

## iOS 9 compatibility audit

See `docs/ios9-device-compat-audit.md`. The supplied historical 1.3-4 dylib was checked directly for architectures, classes, ivars/selectors and package metadata before the optimized hooks were finalized.
