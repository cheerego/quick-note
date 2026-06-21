#!/bin/bash
# Package QuickNotes as a macOS .app bundle
set -e

cd "$(dirname "$0")/app"

APP_NAME="Quick Notes"
BUNDLE_ID="com.crush.quick-notes"
BUILD_DIR=".build/release"
APP_DIR="../dist/${APP_NAME}.app"

echo "Building release..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/QuickNotes" "$APP_DIR/Contents/MacOS/QuickNotes"

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>QuickNotes</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo ""
echo "Done! App bundle created at:"
echo "  $(cd .. && pwd)/dist/${APP_NAME}.app"
echo ""
echo "To install:"
echo "  cp -r \"dist/${APP_NAME}.app\" /Applications/"
echo ""
echo "To add to Login Items:"
echo "  System Settings > General > Login Items > add 'Quick Notes'"
