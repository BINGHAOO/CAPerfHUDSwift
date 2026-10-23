#!/bin/bash

set -e

cd "$(dirname "$0")"

WORKING_LOCATION="$(pwd)"
APPLICATION_NAME=CAPerfHUDSwift
PLATFORM=iOS
SDK=iphoneos
if [[ $* == *--debug* ]]; then
    TARGET=Debug
else
    TARGET=Release
fi

# Build flavors:
#   (default)      TrollStore edition  -> build/CAPerfHUD-TrollStore.tipa
#   --jailbreak    Jailbreak edition   -> build/CAPerfHUDSwift.app (bundled into the tweak .deb)
JAILBREAK=0
if [[ $* == *--jailbreak* ]]; then
    JAILBREAK=1
fi

if [ "$JAILBREAK" = "1" ]; then
    echo "[*] Building $APPLICATION_NAME ($TARGET) - Jailbreak edition..."
else
    echo "[*] Building $APPLICATION_NAME ($TARGET) - TrollStore edition..."
fi

if [ ! -d "build" ]; then
    mkdir build
fi

if [ "$JAILBREAK" = "1" ]; then
    DD_PATH="DerivedDataJB"
    EXTRA_SETTINGS="SWIFT_ACTIVE_COMPILATION_CONDITIONS=JAILBREAK"
else
    DD_PATH="DerivedDataApp"
    EXTRA_SETTINGS=""
fi

cd build

xcodebuild -project "$WORKING_LOCATION/$APPLICATION_NAME.xcodeproj" \
    -scheme "$APPLICATION_NAME" \
    -configuration "$TARGET" \
    -derivedDataPath "$WORKING_LOCATION/build/$DD_PATH" \
    -destination "generic/platform=$PLATFORM" \
    clean build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO" \
    $EXTRA_SETTINGS

DD_APP_PATH="$WORKING_LOCATION/build/$DD_PATH/Build/Products/$TARGET-$SDK/$APPLICATION_NAME.app"
TARGET_APP="$WORKING_LOCATION/build/$APPLICATION_NAME.app"
rm -rf "$TARGET_APP"
cp -r "$DD_APP_PATH" "$TARGET_APP"

echo "[*] Removing code signature"
codesign --remove "$TARGET_APP" 2>/dev/null || true
if [ -e "$TARGET_APP/_CodeSignature" ]; then
    rm -rf "$TARGET_APP/_CodeSignature"
fi
if [ -e "$TARGET_APP/embedded.mobileprovision" ]; then
    rm -rf "$TARGET_APP/embedded.mobileprovision"
fi

# Add entitlements (com.apple.QuartzCore.debug – required to control the system HUD)
echo "[*] Adding entitlements"
ENTITLEMENTS_FILE=$(find "$WORKING_LOCATION/$APPLICATION_NAME" -maxdepth 1 -name "*.entitlements" | head -n 1)
if [ -z "$ENTITLEMENTS_FILE" ]; then
    echo "[!] No entitlements file found, skipping"
else
    echo "[*] Using entitlements: $ENTITLEMENTS_FILE"
    ldid -S"$ENTITLEMENTS_FILE" "$TARGET_APP/$APPLICATION_NAME"
fi

if [ "$JAILBREAK" = "1" ]; then
    # Jailbreak edition: use a distinct bundle id so it can coexist with the
    # TrollStore edition, then keep the .app for the theos .deb packaging step.
    echo "[*] Jailbreak edition: adjusting bundle identifier"
    PLIST="$TARGET_APP/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.binghaoo.CAPerfHUDJB" "$PLIST" \
        || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.binghaoo.CAPerfHUDJB" "$PLIST"
    echo "[*] Build complete: $TARGET_APP"
    echo "[*] (The tweak Makefile bundles this .app into the .deb at /Applications)"
    exit 0
fi

# TrollStore edition: package into .tipa
echo "[*] Packaging..."
mkdir Payload
cp -r $APPLICATION_NAME.app Payload/$APPLICATION_NAME.app

if [[ $* != *--debug* ]]; then
    strip Payload/$APPLICATION_NAME.app/$APPLICATION_NAME
fi

zip -vr CAPerfHUD-TrollStore.tipa Payload
rm -rf $APPLICATION_NAME.app
rm -rf Payload

echo "[*] Build complete: $WORKING_LOCATION/build/CAPerfHUD-TrollStore.tipa"
ls -la "$WORKING_LOCATION/build/CAPerfHUD-TrollStore.tipa"
