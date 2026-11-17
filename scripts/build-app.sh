#!/bin/bash
# Builds dist/FingerTap.app from the Swift package.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)}"
VERSION="${VERSION:-0.1.0}"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP="dist/FingerTap.app"

swift build -c release --product FingerTap
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/FingerTap "$APP/Contents/MacOS/FingerTap"
# Translations: macOS picks the one matching the system language, English otherwise.
cp -R Resources/*.lproj "$APP/Contents/Resources/"
# Icon drawn by scripts/make-art.swift.
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>FingerTap</string>
    <key>CFBundleDisplayName</key><string>FingerTap</string>
    <key>CFBundleIdentifier</key><string>local.fingertap.app</string>
    <key>CFBundleExecutable</key><string>FingerTap</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>fr</string></array>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

# Synced folders tag files with attributes that codesign rejects.
xattr -cr "$APP"
codesign --force --sign - "$APP"
echo "OK : $APP ($VERSION, build $BUILD)"
