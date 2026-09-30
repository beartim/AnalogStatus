# AnalogStatus 1.3-4+opt — iOS 9 device compatibility matrix

This matrix focuses on the iOS 9 phone hardware that can run the legacy `SBLockScreenViewController` / `SBFLockScreenDateView` implementation preserved by this project.

## Architecture coverage

The optimized package contains `armv7` and `arm64` slices.

| Device family | CPU ABI relevant to this package | Covered |
| --- | --- | --- |
| iPhone 4s | armv7 | Yes |
| iPhone 5 / 5c | armv7s hardware, armv7-compatible | Yes |
| iPhone 5s | arm64 | Yes |
| iPhone 6 / 6 Plus | arm64 | Yes |
| iPhone 6s / 6s Plus | arm64 | Yes |
| iPhone SE (1st generation) | arm64 | Yes |
| iPod touch 5th generation | armv7 | Expected |
| iPod touch 6th generation | arm64 | Expected |

The original 1.3-4 binary also shipped an armv7s slice. It is not required for iPhone 5/5c compatibility because those devices can execute the armv7 slice. Keeping only armv7 + arm64 reduces package/build complexity without excluding iOS 9 iPhones.

## UIKit point-space layout

AnalogStatus lays out the lock screen in UIKit points, not physical display pixels. The historical 1.3-4 behavior is preserved:

- overlay page origin: `x = pageWidth`;
- full clock: 200 pt diameter, y = 30 pt;
- notification clock: 119 pt diameter, y = 28.5 pt;
- full date y = 202 pt;
- notification date y = 121 pt;
- overlay is unclipped because the original compact date extends about 2 pt below its 140 pt container.

Expected logical portrait coordinate spaces:

| Device / mode | Logical points | Scale | Full-clock x inside lock page | Compact-clock x |
| --- | ---: | ---: | ---: | ---: |
| iPhone 4s | 320×480 | 2× | 60.0 | 100.5 |
| iPhone 5 / 5c / 5s / SE | 320×568 | 2× | 60.0 | 100.5 |
| iPhone 6 / 6s, Zoomed | 320×568 | 2× | 60.0 | 100.5 |
| iPhone 6 / 6s, Standard | 375×667 | 2× | 87.5 | 128.0 |
| iPhone 6 Plus / 6s Plus, Zoomed | 375×667 | 3× | 87.5 | 128.0 |
| iPhone 6 Plus / 6s Plus, Standard | 414×736 | 3× | 107.0 | 147.5 |

These x offsets are `(pageWidth - clockDiameter) / 2`, so the analog clock remains centered on every listed lock-screen page. Display Zoom changes the logical point space; it does not require a separate hard-coded device branch.

## iPhone 6s Plus assessment

The iPhone 6s Plus is a good match for the current build:

- arm64 slice is present;
- iOS 9-era SpringBoard classes match the implementation family used by 1.3-4;
- the 414×736 standard logical coordinate space centers the 200 pt clock at x = 107 pt within the active lock page;
- Display Zoom uses a smaller logical coordinate space and the same point-based formulas still center correctly;
- @3x rendering is supported by the renderer.

The main device-specific concern on Plus-class phones was memory rather than geometry. A 203.5 pt full-clock bitmap at @3x is roughly 1.4–1.5 MiB decoded. The cache is therefore now bounded to 8 objects and a 6 MiB total-cost budget instead of retaining as many as 24 minute variants.

## Remaining runtime risks

These are private SpringBoard APIs, so static compatibility cannot replace hardware testing. The most useful real-device checks are:

1. iPhone 4s / iOS 9.x (armv7, 320×480).
2. iPhone 5 or 5c / iOS 9.x (armv7 compatibility on armv7s hardware).
3. iPhone 5s or SE / iOS 9.x (small-screen arm64).
4. iPhone 6 or 6s in Standard and Display Zoom modes.
5. iPhone 6 Plus or 6s Plus in Standard and Display Zoom modes.
6. Repeated sleep/wake cycles.
7. Lock screen with and without notifications.
8. Media controls appearing/disappearing.
9. Charging UI appearing/disappearing.
10. Status-bar clock in SpringBoard and third-party UIKit apps.

The package may also work on iOS 9 iPads, but the current compatibility target is the iPhone/iPod-style lock-screen implementation. iPad rotation and lock-screen geometry should be treated as unverified unless tested on hardware.
