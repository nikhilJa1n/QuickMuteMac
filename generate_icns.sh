#!/bin/bash
set -e

INPUT_IMAGE="quickmute_logo.jpg"
ICONSET_DIR="QuickMute.iconset"

if [ ! -f "$INPUT_IMAGE" ]; then
    echo "Error: Input image not found at $INPUT_IMAGE"
    exit 1
fi

echo "=== Generating macOS AppIcon.icns ==="
mkdir -p "$ICONSET_DIR"

# Resize helper function using sips
resize_icon() {
    local size=$1
    local name=$2
    sips -s format png -z "$size" "$size" "$INPUT_IMAGE" --out "$ICONSET_DIR/$name.png" > /dev/null 2>&1
}

# Generate required Apple icon sizes (both standard and retina)
resize_icon 16 "icon_16x16"
resize_icon 32 "icon_16x16@2x"
resize_icon 32 "icon_32x32"
resize_icon 64 "icon_32x32@2x"
resize_icon 128 "icon_128x128"
resize_icon 256 "icon_128x128@2x"
resize_icon 256 "icon_256x256"
resize_icon 512 "icon_256x256@2x"
resize_icon 512 "icon_512x512"
resize_icon 1024 "icon_512x512@2x"

# Compile to .icns format
iconutil -c icns "$ICONSET_DIR" -o AppIcon.icns

# Clean up temporary iconset directory
rm -rf "$ICONSET_DIR"

echo "=== AppIcon.icns generated successfully! ==="
