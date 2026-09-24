ARCHS = armv7 arm64
IOS_SDK_VERSION ?= 9.3
TARGET = iphone:clang:$(IOS_SDK_VERSION):7.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = analogprefs
analogprefs_FILES = APRootListController.m
analogprefs_FRAMEWORKS = UIKit
analogprefs_PRIVATE_FRAMEWORKS = Preferences
analogprefs_INSTALL_PATH = /Library/PreferenceBundles
analogprefs_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter

include $(THEOS_MAKE_PATH)/bundle.mk
