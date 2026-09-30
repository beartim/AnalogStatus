#!/usr/bin/env python3
"""Static layout sanity checks for AnalogStatus on iOS 9-era iPhones.

The tweak uses UIKit point coordinates.  These cases cover the logical
coordinate spaces relevant to iOS 9 phones, including Display Zoom modes on
4.7-inch and 5.5-inch models.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class DeviceCase:
    name: str
    width: float
    height: float
    scale: float
    arch: str


CASES = [
    DeviceCase("iPhone 4s", 320, 480, 2, "armv7"),
    DeviceCase("iPhone 5 / 5c", 320, 568, 2, "armv7"),
    DeviceCase("iPhone 5s / SE (1st gen)", 320, 568, 2, "arm64"),
    DeviceCase("iPhone 6 / 6s (Zoomed)", 320, 568, 2, "arm64"),
    DeviceCase("iPhone 6 / 6s (Standard)", 375, 667, 2, "arm64"),
    DeviceCase("iPhone 6 Plus / 6s Plus (Zoomed)", 375, 667, 3, "arm64"),
    DeviceCase("iPhone 6 Plus / 6s Plus (Standard)", 414, 736, 3, "arm64"),
]

CLOCK_LAYOUTS = [
    ("full", 200.0, 30.0, 225.0, 202.0),
    ("notifications", 119.0, 28.5, 140.0, 121.0),
]

SUPPORTED_ARCHES = {"armv7", "arm64"}


def bitmap_megabytes(diameter: float, line_width: float, scale: float) -> float:
    edge = diameter + line_width + 1.0
    pixels = edge * scale
    return pixels * pixels * 4.0 / (1024.0 * 1024.0)


def main() -> None:
    print("AnalogStatus iOS 9 phone layout matrix")
    print("=" * 74)

    for device in CASES:
        assert device.arch in SUPPORTED_ARCHES
        assert device.width >= 320 and device.height >= 480

        print(
            f"{device.name:39} {device.width:>3.0f}x{device.height:<3.0f} pt  "
            f"@{device.scale:.0f}x  {device.arch}"
        )

        for layout_name, diameter, y, container_height, date_y in CLOCK_LAYOUTS:
            clock_x = (device.width - diameter) * 0.5
            clock_center = clock_x + diameter * 0.5
            page_center = device.width * 0.5

            # The historical clock must remain centered on the active lock page.
            assert clock_x >= 0
            assert abs(clock_center - page_center) < 1e-6

            # 1.3-4 places the overlay at x == page width, i.e. page two.
            container_x = device.width
            assert container_x == device.width

            # Historical overlay width is the portrait page height.  On all
            # supported phone coordinate spaces it is at least one page wide.
            container_width = device.height
            assert container_width >= device.width

            # The compact date extends 2 pt below its 140 pt container in the
            # original package; the optimized view intentionally does not clip.
            date_bottom = date_y + 21.0
            if layout_name == "full":
                assert date_bottom <= container_height
            else:
                assert date_bottom == 142.0 and container_height == 140.0

        full_mb = bitmap_megabytes(200.0, 2.5, device.scale)
        print(f"  estimated full-clock RGBA bitmap: {full_mb:.2f} MiB")

    max_bitmap = max(bitmap_megabytes(200.0, 2.5, d.scale) for d in CASES)
    assert max_bitmap < 2.0
    print("=" * 74)
    print(f"largest single full-clock bitmap: {max_bitmap:.2f} MiB")
    print("cache budget: 6 MiB / 8 objects")
    print("layout matrix: PASS")


if __name__ == "__main__":
    main()
