ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CAPerfHUDOverlay

CAPerfHUDOverlay_FILES = Tweak.xm HUDOverlayWindow.m HUDOverlayView.m HUDPreferences.m HUDMetrics.m
CAPerfHUDOverlay_CFLAGS = -fobjc-arc
CAPerfHUDOverlay_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

# Bundle the jailbreak edition app into the .deb.
# Build it first with: ./ipabuild.sh --jailbreak  (produces ../build/CAPerfHUDSwift.app)
JB_APP ?= ../build/CAPerfHUDSwift.app

after-stage::
	@mkdir -p "$(THEOS_STAGING_DIR)/Applications"
	@cp -R "$(JB_APP)" "$(THEOS_STAGING_DIR)/Applications/"
