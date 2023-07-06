THEOS_DEVICE_IP = 192.168.1.10
TARGET := iphone:clang:12.4

include $(THEOS)/makefiles/common.mk

TOOL_NAME = ReceivePNR

ReceivePNR_FILES = main.m
ReceivePNR_CFLAGS = -fobjc-arc
ReceivePNR_CODESIGN_FLAGS = -Sentitlements.plist
ReceivePNR_INSTALL_PATH = /usr/local/bin
ReceivePNR_LIBRARIES = mryipc

include $(THEOS_MAKE_PATH)/tool.mk
