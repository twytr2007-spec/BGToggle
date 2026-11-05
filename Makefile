TARGET := iphone:clang:latest:13.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BGToggle
BGToggle_FILES = Tweak.m
BGToggle_LDFLAGS = -Wl,-headerpad_max_install_names
BGToggle_FRAMEWORKS = UIKit AVFoundation
BGToggle_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
