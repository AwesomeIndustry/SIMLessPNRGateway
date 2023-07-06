
THEOS_DEVICE_IP = 192.168.1.10
ARCHS = arm64

TARGET := iphone:clang:12.4
INSTALL_TARGET_PROCESSES = imagent Preferences identityservicesd SpringBoard CommCenter CoreTelephony MobileSMS IMCore IMDaemonCore backboardd
SYSROOT = $(THEOS)/sdks/iPhoneOS12.4.sdk


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PNRSender

PNRSender_FILES = Tweak.x
PNRSender_PROCESSES = CommCenter identityservicesd CoreTelephony SpringBoard springboard backboardd
PNRSender_CFLAGS = -fobjc-arc -Wno-nullability-completeness -Wno-deprecated-declarations -fblocks
PNRSender_FRAMEWORKS = UIKit Foundation
PNRSender_LIBRARIES = mryipc
PNRSender_PRIVATE_FRAMEWORKS = IMCore
CODESIGN_ENTITLEMENT = entitlements.xml
PNRSender_CODESIGN_FLAGS = -S$(CODESIGN_ENTITLEMENT)




include $(THEOS_MAKE_PATH)/tweak.mk
