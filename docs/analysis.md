# Binary comparison: AnalogStatus 1.3-4 vs 3.1

## What changed in 3.1

The supplied packages show that the Lock Screen feature was removed from 3.1 rather than merely hidden in Settings.

### 1.3-4

- Main tweak binary: `analog.dylib`, universal armv7s/armv7/arm64.
- Preference `Root.plist` exposes both `SBEnabled` and `LSEnabled`.
- Main binary contains `LSEnabled`, `SBLockScreenViewController`, `SBFLockScreenDateView`, `_timeLabel`, `_legibilityTimeLabel`, `_legibilityDateLabel`, and the Lock Screen timer/update code.
- Lock Screen implementation hooks `viewDidLoad`, `viewDidDisappear:`, charging-view methods, and `SBFLockScreenDateView.layoutSubviews`.

### 3.1

- Main tweak binary: `AnalogStatus.dylib`, arm64 only.
- The package no longer contains a preference `Root.plist`; its preference controller dynamically creates only support/report/donation entries.
- Main tweak binary contains no `LSEnabled`, no `SBLockScreenViewController`, no `SBFLockScreenDateView`, and none of the old Lock Screen label ivars.
- It introduces `FZAnalogLabel` and hooks the newer status-bar implementation. On iPhone10,3 / iPhone10,6 (iPhone X) it hooks `_UIStatusBarTimeItem`, `_UIStatusBarBackgroundActivityView`, `_UIStatusBarAnimation`, and `_UIStatusBarRoundedCornerView`; on other devices it still hooks `UIStatusBarTimeItemView.contentsImage`.
- It contains identifiers for `_UIStatusBarTimeItem.shortTimeDisplayIdentifier` and `_UIStatusBarTimeItem.pillTimeDisplayIdentifier`, confirming that the rewrite concentrated on the iPhone X/iOS 11 status-bar model.

No public changelog located during this analysis states the author's motivation. The most defensible conclusion is therefore: **3.1 deliberately dropped the Lock Screen implementation during its iOS 11/iPhone X status-bar rewrite.** The likely engineering reason is that the 1.3-4 Lock Screen code depended directly on iOS 9 SpringBoard private classes and ivars that were not stable across the iOS 10/11 Lock Screen/Cover Sheet redesign.

## Problems found in the 1.3-4 binary

1. **Unsafe ivar access.** It uses `class_getInstanceVariable` / `ivar_getOffset`, but if an ivar is absent it can still dereference a null address. This is a crash risk on changed private classes.
2. **Over-broad status item sizing.** The `_frameForItemView:startPosition:` hook forces the returned width to 20 points while the tweak is enabled without first proving the item is the time item.
3. **Bitmap regeneration every second on the Lock Screen.** The analog image only contains hour/minute hands, so a full redraw every second is unnecessary.
4. **Broken/no-op image cache.** The old drawing routine sends `objectForKey:` / `setObject:forKey:` to a nil cache object; caching is effectively disabled.
5. **Destructive Lock Screen label handling.** The original date/time labels are removed from their superview, which makes later restoration and compatibility harder.
6. **Timer lifecycle weakness.** The timer is created from `viewDidLoad` and invalidated on `viewDidDisappear:`. If the same controller is reused, the timer may not be recreated on a later appearance.
7. **SpringBoard hooks initialized through a UIKit-wide injection.** The old constructor attempts Lock Screen class hooks in processes where those classes do not exist, producing needless nil-class Logos paths/logging.
8. **Hard-coded private implementation assumptions.** The code relies on `_timeString`, `_dateLabel`, `_timeLabel`, `_legibilityTimeLabel`, and `_legibilityDateLabel` with no graceful fallback.

## Changes in this reimplementation

- Safe KVC with exception protection for private ivars.
- Conditional Logos groups: Lock Screen hooks are initialized only inside SpringBoard and only when the target class exists.
- Associated objects keep Lock Screen views/timers tied to the owning controller rather than process-global UI objects.
- Original Lock Screen labels are hidden, never removed.
- Timer is restarted in `viewWillAppear:` and stopped in `viewDidDisappear:`.
- The 1-second timer performs only a cheap state check; image rendering occurs only when the minute changes or notification layout changes.
- Real `NSCache` keyed by minute, geometry, line width and color.
- The 20-point layout correction is applied only to `UIStatusBarTimeItemView`.
- Lock Screen layout uses the historical 200-point full clock and 119-point notification clock geometry, but centers it from the current screen width instead of assuming a fixed device width.
