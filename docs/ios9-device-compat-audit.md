# iOS 9 device-compatibility audit — AnalogStatus 1.3-4+opt

This is a **static, device-oriented compatibility audit** of the reconstructed source. No physical iOS device is attached to the current build environment, so runtime behavior on hardware still requires installation testing.

## Baseline verified from the supplied 1.3-4 package

The supplied historical `analogstatus_1.3-4.deb` provides the strongest compatibility baseline:

- package metadata explicitly tags the release `compatible::ios9`;
- the tweak dylib is a fat Mach-O containing `armv7s`, `armv7`, and `arm64` slices;
- the dylib contains the exact iOS 9-era private classes used by this reconstruction:
  - `SBLockScreenViewController`
  - `SBFLockScreenDateView`
  - `UIStatusBarTimeItemView`
  - `UIStatusBarLayoutManager`
- the historical binary contains the exact lock-screen selectors retained here:
  - `viewDidLoad`
  - `viewDidDisappear:`
  - `_shouldShowChargingText`
  - `_addBatteryChargingViewAndShowBattery:`
  - `_removeBatteryChargingView`
  - `layoutSubviews`
- it also contains `_timeString`, `_timeLabel`, `_dateLabel`, `hasNotifications`, `isShowingMediaControls`, and `scrollView`, which confirms that the reconstructed access paths match the old implementation family.

The optimized build keeps `armv7` + `arm64`. An additional `armv7s` slice is not required for iPhone 5/5c because those devices execute armv7 binaries, while removing it simplifies the build without reducing the supported iOS 9 hardware set.

## Changes made during this audit

### 1. Lock-screen controller tracking

The current lock-screen controller is now remembered even while `LSEnabled` is off. This avoids an edge case where enabling the preference after SpringBoard has already created the lock-screen controller would otherwise require the controller to be recreated before the analog clock can be installed.

### 2. Preference callback thread safety

Darwin preference notifications no longer touch UIKit directly from the notification callback. UI restoration/installation is dispatched to the main queue first, then the new preferences are loaded and applied.

### 3. Native label restoration

The previous reconstruction hid the native time/date labels when enabled, but restored them with `hidden = NO`. That could make a label visible even when SpringBoard itself had intentionally kept it hidden. The optimized code now snapshots each native label's original hidden state with an associated object and restores that exact state when the tweak is disabled.

### 4. Date-label fallback

Date text is read from `_dateLabel` first and falls back to `_legibilityDateLabel`. This covers the two label paths visible in the historical 1.3-4 binary and avoids an empty custom date if one implementation path is absent.

### 5. Host-view geometry

The large clock now uses the actual lock-screen host view/superview width when available, falling back to `UIScreen` only when necessary. This is safer on iPad and for any non-default SpringBoard geometry.

### 6. Status-bar return-type safety

If `_UILegibilityImageSet` is unavailable, `contentsImage` now returns the original implementation instead of returning a raw `UIImage` object to a path that normally expects a legibility image set.

### 7. Rendering and timer behavior

The one-second timer is retained because notification/media/charging visibility can change independently of the minute. The expensive analog-clock bitmap is not rebuilt every second: it is regenerated only when the minute changes, notification layout state changes, or a forced refresh is requested. A real `NSCache` stores generated images.

### 8. Legacy compiler compatibility

Lightweight Objective-C generics/nullability syntax was removed from the small renderer API so older iOS 9-era Linux clang toolchains are less likely to reject the source. The project retains an iOS 7.0 deployment target and now defaults to the maintained patched iPhoneOS 9.3 SDK for GitHub Actions. A locally installed iPhoneOS 9.2 SDK can still be selected with `IOS_SDK_VERSION=9.2`; both choices remain within the iOS 9 SDK generation targeted by this compatibility audit.

## iOS 9 runtime test matrix still required on hardware

At minimum, verify these scenarios after installation:

1. armv7 device: iPhone 4s / iPhone 5 / iPhone 5c on iOS 9.x.
2. arm64 device: iPhone 5s or newer on iOS 9.x.
3. Status-bar analog clock in SpringBoard and third-party apps.
4. 12-hour and 24-hour system time formats.
5. Lock screen with no notifications (large ~200 pt clock).
6. Lock screen with notifications (compact ~119 pt clock).
7. Incoming/removing notifications while the screen remains locked.
8. Media controls appearing/disappearing on the lock screen.
9. Charger connected/disconnected and battery charging view transitions.
10. Repeated lock/unlock cycles to confirm timer recreation and no retained controller.
11. Toggling both preferences followed by respring.
12. Midnight/date change while the lock screen remains visible.
13. iPad iOS 9 geometry if iPad support matters.

## Remaining private-API risks

- SpringBoard private implementation details can differ between iOS 9.0, 9.1, 9.2, and 9.3.x even when class names remain present.
- Other lock-screen tweaks may replace/hide the same labels or move the date view and can conflict with AnalogStatus.
- The reconstruction intentionally preserves the historical white lock-screen clock instead of trying to replicate every legibility-color transition; this favors 1.3-4 behavior over a broader visual rewrite.
- Because this environment has no attached iOS device, crash-free hardware behavior cannot be claimed until the matrix above is exercised.
