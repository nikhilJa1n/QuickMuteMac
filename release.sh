#!/bin/bash
set -e

# Production Versioning Defaults
VERSION="1.0.0"
BUILD_NUMBER="1"

# Read version and build arguments if provided
if [ ! -z "$1" ]; then
    VERSION="$1"
fi
if [ ! -z "$2" ]; then
    BUILD_NUMBER="$2"
fi

echo "=== Rebuilding QuickMute for Release (Version: $VERSION, Build: $BUILD_NUMBER) ==="
bash build.sh

# Setup temporary packaging directory
echo "=== Preparing Release Packages ==="
RELEASE_DIR="build/release_pkg"
rm -rf build/release_pkg
rm -f QuickMute.dmg QuickMute.zip
mkdir -p "$RELEASE_DIR"

# Copy the app bundle
cp -R QuickMute.app "$RELEASE_DIR/"

# Inject versioning into Info.plist using macOS plutil
echo "=== Injecting Production Version Info ==="
plutil -replace CFBundleShortVersionString -string "$VERSION" "$RELEASE_DIR/QuickMute.app/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$RELEASE_DIR/QuickMute.app/Contents/Info.plist"

# Detect Code Signing Identity (1. Explicit env variable, 2. Local self-signed certificate, 3. Ad-hoc fallback)
if [ ! -z "$CODESIGN_IDENTITY" ]; then
    IDENTITY="$CODESIGN_IDENTITY"
elif security find-certificate -c "QuickMuteDeveloper" > /dev/null 2>&1; then
    IDENTITY="QuickMuteDeveloper"
else
    IDENTITY="-"
fi

# Re-sign the app bundle inside the release directory to seal the updated Info.plist
echo "=== Re-signing versioned QuickMute.app (Identity: $IDENTITY) ==="
codesign --force --options runtime --sign "$IDENTITY" --entitlements Entitlements.plist "$RELEASE_DIR/QuickMute.app/Contents/MacOS/QuickMute"
codesign --force --options runtime --sign "$IDENTITY" "$RELEASE_DIR/QuickMute.app"

# Create symlink to /Applications inside the folder for easy drag-and-drop installation
ln -s /Applications "$RELEASE_DIR/Applications"

# Create Disk Image (.dmg)
echo "=== Creating Disk Image (QuickMute.dmg) ==="
hdiutil create -volname "QuickMute" -srcfolder "$RELEASE_DIR" -ov -format UDZO QuickMute.dmg

# Code-sign the DMG itself
if [ "$IDENTITY" != "-" ]; then
    echo "=== Code Signing QuickMute.dmg (Identity: $IDENTITY) ==="
    codesign --force --sign "$IDENTITY" QuickMute.dmg
fi

# Clean up DMG packaging directory
rm -rf build/release_pkg

# Create ZIP archive (.zip) as fallback
echo "=== Creating ZIP Archive (QuickMute.zip) ==="
zip -r -y -q QuickMute.zip QuickMute.app

# Summary
echo "=== Release Packages Created Successfully ==="
ls -lh QuickMute.dmg QuickMute.zip
