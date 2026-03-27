#!/bin/bash
# build.sh — Builds PagesMonitor.app and optionally installs to /Applications

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="PagesMonitor"
BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
MACOS_DIR="$BUNDLE/Contents/MacOS"
RESOURCES_DIR="$BUNDLE/Contents/Resources"
SWIFT_SOURCES="$SCRIPT_DIR/PagesMonitorGUI"

echo "==> Building $APP_NAME.app..."

# 1. Create bundle structure
rm -rf "$BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# 2. Compile Swift sources
SDK=$(xcrun --show-sdk-path)
swiftc "$SWIFT_SOURCES"/*.swift \
    -sdk "$SDK" \
    -framework AppKit \
    -framework Foundation \
    -O \
    -o "$MACOS_DIR/$APP_NAME"

echo "    Swift compilation done."

# 3. Write Info.plist
cat > "$BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>       <string>PagesMonitor</string>
    <key>CFBundleIdentifier</key>       <string>com.local.pagesmonitor</string>
    <key>CFBundleName</key>             <string>Pages Monitor</string>
    <key>CFBundlePackageType</key>      <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key>          <string>1</string>
    <key>LSMinimumSystemVersion</key>   <string>13.0</string>
    <key>NSPrincipalClass</key>         <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>  <true/>
    <key>CFBundleIconFile</key>         <string>AppIcon</string>
    <key>NSHumanReadableCopyright</key> <string></string>
</dict>
</plist>
PLIST

# 4. Copy shell script into bundle resources
cp "$SCRIPT_DIR/pages_to_docx_watcher.sh" "$RESOURCES_DIR/"
chmod +x "$RESOURCES_DIR/pages_to_docx_watcher.sh"

# 5. Build app icon from icon.png
ICON_SRC="$SCRIPT_DIR/icon.png"
if [ -f "$ICON_SRC" ]; then
    ICONSET="$SCRIPT_DIR/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z $size $size "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}.png"        > /dev/null
        double=$(( size * 2 ))
        sips -z $double $double "$ICON_SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
    done
    iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/AppIcon.icns"
    rm -rf "$ICONSET"
    echo "    App icon generated."
else
    echo "    Warning: icon.png not found, skipping icon."
fi

echo "    Resources copied."
echo ""
echo "Build complete: $BUNDLE"
echo ""

# 5. Optionally install to /Applications
read -r -p "Install to /Applications? (y/n): " ans
if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
    cp -rf "$BUNDLE" /Applications/
    # Remove quarantine so macOS doesn't block first launch
    xattr -rd com.apple.quarantine "/Applications/$APP_NAME.app" 2>/dev/null || true
    echo ""
    echo "Installed to /Applications/$APP_NAME.app"
    echo "Launch it from Spotlight (Cmd+Space) or the Finder."
else
    echo "Skipped installation. You can run it directly:"
    echo "  open \"$BUNDLE\""
fi
