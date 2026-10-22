ARCHS = arm64 arm64e
TARGET = iphone:clang:15.4:15.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CAPerfHUDOverlay

CAPerfHUDOverlay_FILES = Tweak.xm HUDOverlayWindow.m HUDOverlayView.m HUDPreferences.m HUDMetrics.m
CAPerfHUDOverlay_CFLAGS = -fobjc-arc
CAPerfHUDOverlay_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
