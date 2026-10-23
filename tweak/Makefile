# rootful (unc0ver / palera1n rootful): arm64 + arm64e, package arch iphoneos-arm64e
# rootless (Dopamine / palera1n rootless): arm64 only, paths remapped to /var/jb
# roothide: built with roothide/theos under the rootless scheme
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
ARCHS = arm64
else
ARCHS = arm64 arm64e
endif
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
