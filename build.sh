#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting ImageMonitor build process..."

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode is required but not installed."
    echo "Please install Xcode from the App Store."
    exit 1
fi

# Create build directory
BUILD_DIR="build"
APP_NAME="ImageMonitor.app"
APP_BUNDLE="$BUILD_DIR/$APP_NAME"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📁 Creating app bundle structure..."
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Create Info.plist
echo "📝 Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.byteclub.imagemonitor</string>
    <key>CFBundleName</key>
    <string>ImageMonitor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "🔨 Compiling Swift files..."
swiftc \
    -o "$MACOS_DIR/ImageMonitor" \
    -target x86_64-apple-macosx11.0 \
    AppDelegate.swift \
    DirectoryMonitor.swift \
    DirectoryMonitorDelegate.swift \
    -sdk $(xcrun --show-sdk-path)

echo "✨ Setting executable permissions..."
chmod +x "$MACOS_DIR/ImageMonitor"

echo "✅ Build complete!"
echo "📦 Your application bundle is located at: $APP_BUNDLE"
echo ""
echo "To run the application:"
echo "1. Navigate to the build directory: cd $BUILD_DIR"
echo "2. Double click the app bundle or run: open $APP_NAME"
echo ""
echo "Note: Since this is an unsigned application, you might need to:"
echo "1. Right-click the app and select 'Open'"
echo "2. Confirm that you want to open the application"