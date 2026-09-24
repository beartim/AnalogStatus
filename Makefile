ARCHS = armv7 arm64
IOS_SDK_VERSION ?= 9.3
TARGET = iphone:clang:$(IOS_SDK_VERSION):7.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AnalogStatus
AnalogStatus_FILES = Tweak.xm ASAnalogRenderer.m
AnalogStatus_FRAMEWORKS = UIKit Foundation CoreGraphics
AnalogStatus_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += analogprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard 2>/dev/null || true"
