#!/bin/bash
set -e

echo "=== Compiling QuickMute Swift Source ==="
swiftc -O main.swift AppDelegate.swift HotKeyManager.swift MicrophoneManager.swift HUDWindow.swift -o QuickMute

echo "=== Packaging QuickMute.app Bundle ==="
rm -rf QuickMute.app
mkdir -p QuickMute.app/Contents/MacOS
mkdir -p QuickMute.app/Contents/Resources

mv QuickMute QuickMute.app/Contents/MacOS/
cp Info.plist QuickMute.app/Contents/Info.plist
if [ -f AppIcon.icns ]; then
    cp AppIcon.icns QuickMute.app/Contents/Resources/
fi

# Detect Code Signing Identity (1. Explicit env variable, 2. Local self-signed certificate, 3. Ad-hoc fallback)
if [ ! -z "$CODESIGN_IDENTITY" ]; then
    IDENTITY="$CODESIGN_IDENTITY"
elif security find-certificate -c "QuickMuteDeveloper" > /dev/null 2>&1; then
    IDENTITY="QuickMuteDeveloper"
else
    IDENTITY="-"
fi

echo "=== Code Signing QuickMute.app (Identity: $IDENTITY) ==="
codesign --force --options runtime --sign "$IDENTITY" --entitlements Entitlements.plist QuickMute.app/Contents/MacOS/QuickMute
codesign --force --options runtime --sign "$IDENTITY" QuickMute.app

echo "=== Build Complete: QuickMute.app created successfully! ==="
