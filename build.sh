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

echo "=== Build Complete: QuickMute.app created successfully! ==="
