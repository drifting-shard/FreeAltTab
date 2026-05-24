APP_NAME := SpaceWindowSwitcher
SRC_DIR := SpaceWindowSwitcher
BUILD_DIR := build
PACKAGE_DIR := dist
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
SOURCES := $(wildcard $(SRC_DIR)/*.swift)
INSTALL_DIR := $(HOME)/Applications
INSTALLED_APP := $(INSTALL_DIR)/$(APP_NAME).app
INSTALLED_EXECUTABLE := $(INSTALLED_APP)/Contents/MacOS/$(APP_NAME)
LAUNCH_AGENT_ID := local.spaceswitcher.$(APP_NAME)
LAUNCH_AGENT_PLIST := $(HOME)/Library/LaunchAgents/$(LAUNCH_AGENT_ID).plist
PACKAGE_ZIP := $(PACKAGE_DIR)/$(APP_NAME).zip

.PHONY: build run install autolaunch uninstall-autolaunch package clean

build:
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	cp "$(SRC_DIR)/Info.plist" "$(CONTENTS_DIR)/Info.plist"
	xcrun swiftc -swift-version 5 -O \
		-framework SwiftUI \
		-framework AppKit \
		-framework Carbon \
		-framework CoreGraphics \
		-framework ApplicationServices \
		$(SOURCES) \
		-o "$(MACOS_DIR)/$(APP_NAME)"
	codesign --force --sign - "$(APP_BUNDLE)" >/dev/null

run: build
	open "$(APP_BUNDLE)"

install: build
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALLED_APP)"
	cp -R "$(APP_BUNDLE)" "$(INSTALLED_APP)"

autolaunch: install
	mkdir -p "$(HOME)/Library/LaunchAgents"
	launchctl bootout "gui/$$(id -u)" "$(LAUNCH_AGENT_PLIST)" 2>/dev/null || true
	printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'    <key>Label</key>' \
		'    <string>$(LAUNCH_AGENT_ID)</string>' \
		'    <key>ProgramArguments</key>' \
		'    <array>' \
		'        <string>$(INSTALLED_EXECUTABLE)</string>' \
		'    </array>' \
		'    <key>RunAtLoad</key>' \
		'    <true/>' \
		'    <key>KeepAlive</key>' \
		'    <false/>' \
		'</dict>' \
		'</plist>' > "$(LAUNCH_AGENT_PLIST)"
	launchctl bootstrap "gui/$$(id -u)" "$(LAUNCH_AGENT_PLIST)"
	launchctl enable "gui/$$(id -u)/$(LAUNCH_AGENT_ID)"

uninstall-autolaunch:
	launchctl bootout "gui/$$(id -u)" "$(LAUNCH_AGENT_PLIST)" 2>/dev/null || true
	rm -f "$(LAUNCH_AGENT_PLIST)"

package: build
	mkdir -p "$(PACKAGE_DIR)"
	rm -f "$(PACKAGE_ZIP)"
	ditto -c -k --keepParent "$(APP_BUNDLE)" "$(PACKAGE_ZIP)"

clean:
	rm -rf "$(BUILD_DIR)" "$(PACKAGE_DIR)"
