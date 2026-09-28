#!/bin/bash
#
# Build OpenClaw.app bundle for macOS (Apple Silicon & Intel)
#
set -e
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
BREW_PREFIX="$(brew --prefix)"
CORES="$(sysctl -n hw.ncpu)"
APP_DIR="${SCRIPT_DIR}/Build_Release/OpenClaw.app"

echo "==========================================="
echo " Building OpenClaw.app for macOS"
echo "==========================================="

echo ">>> 1. Ensuring build dependencies..."
brew list --versions cmake sdl2 sdl2_image sdl2_mixer sdl2_ttf sdl2_gfx >/dev/null 2>&1 \
  || brew install cmake sdl2 sdl2_image sdl2_mixer sdl2_ttf sdl2_gfx

echo ">>> 2. Building OpenClaw binary..."
mkdir -p build
cd build
cmake \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_EXE_LINKER_FLAGS="-L${BREW_PREFIX}/lib" \
  -DCMAKE_CXX_FLAGS="-O2 -g -I${BREW_PREFIX}/include" \
  ..
make -j"${CORES}"

cd "${SCRIPT_DIR}/Build_Release"

echo ">>> 3. Recreating ASSETS.ZIP..."
rm -f ASSETS.ZIP
( cd ASSETS && zip -qr ../ASSETS.ZIP . )

echo ">>> 4. Creating macOS .icns App Icon..."
ICON_TMP="/tmp/OpenClaw_icon_build"
rm -rf "${ICON_TMP}"
mkdir -p "${ICON_TMP}/OpenClaw.iconset"

sips -s format png "${SCRIPT_DIR}/ClawLauncher/launcher_icon.ico" --out "${ICON_TMP}/icon_source.png" >/dev/null

sips -z 16 16     "${ICON_TMP}/icon_source.png" --out "${ICON_TMP}/OpenClaw.iconset/icon_16x16.png" >/dev/null
sips -z 32 32     "${ICON_TMP}/icon_source.png" --out "${ICON_TMP}/OpenClaw.iconset/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "${ICON_TMP}/icon_source.png" --out "${ICON_TMP}/OpenClaw.iconset/icon_32x32.png" >/dev/null
sips -z 64 64     "${ICON_TMP}/icon_source.png" --out "${ICON_TMP}/OpenClaw.iconset/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "${ICON_TMP}/icon_source.png" --out "${ICON_TMP}/OpenClaw.iconset/icon_128x128.png" >/dev/null
sips -z 256 256   "${ICON_TMP}/icon_source.png" --out "${ICON_TMP}/OpenClaw.iconset/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "${ICON_TMP}/icon_source.png" --out "${ICON_TMP}/OpenClaw.iconset/icon_256x256.png" >/dev/null
sips -z 512 512   "${ICON_TMP}/icon_source.png" --out "${ICON_TMP}/OpenClaw.iconset/icon_256x256@2x.png" >/dev/null

iconutil -c icns "${ICON_TMP}/OpenClaw.iconset" -o "${SCRIPT_DIR}/Build_Release/OpenClaw.icns"
rm -rf "${ICON_TMP}"

echo ">>> 5. Assembling OpenClaw.app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy binary
cp -f openclaw "${APP_DIR}/Contents/MacOS/openclaw-bin"
chmod +x "${APP_DIR}/Contents/MacOS/openclaw-bin"

# Copy Icon
cp -f "${SCRIPT_DIR}/Build_Release/OpenClaw.icns" "${APP_DIR}/Contents/Resources/OpenClaw.icns"

# Copy Game Assets and Config
cp -f ASSETS.ZIP "${APP_DIR}/Contents/Resources/"
cp -f clacon.ttf "${APP_DIR}/Contents/Resources/"
cp -f console02.tga "${APP_DIR}/Contents/Resources/"
[ -f MENU.xml ] && cp -f MENU.xml "${APP_DIR}/Contents/Resources/"
[ -f SAVES.XML ] && cp -f SAVES.XML "${APP_DIR}/Contents/Resources/"
[ -f config.xml ] && cp -f config.xml "${APP_DIR}/Contents/Resources/"
[ -f startup_commands.txt ] && cp -f startup_commands.txt "${APP_DIR}/Contents/Resources/"

# If CLAW.REZ already exists in Build_Release, copy it inside the app
if [ -f CLAW.REZ ]; then
  echo ">>> Found CLAW.REZ! Embedding inside OpenClaw.app..."
  cp -f CLAW.REZ "${APP_DIR}/Contents/Resources/CLAW.REZ"
fi

# Create Info.plist
cat > "${APP_DIR}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OpenClaw</string>
    <key>CFBundleIconFile</key>
    <string>OpenClaw</string>
    <key>CFBundleIdentifier</key>
    <string>com.openclaw.game</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OpenClaw</string>
    <key>CFBundleDisplayName</key>
    <string>Captain Claw</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# Create macOS launcher script
cat > "${APP_DIR}/Contents/MacOS/OpenClaw" << 'EOF'
#!/bin/bash
BUNDLE_DIR="$(cd "$(dirname "$0")/../Resources" && pwd)"
cd "${BUNDLE_DIR}"

# Check for CLAW.REZ
if [ ! -f "CLAW.REZ" ]; then
    # Also check if it exists in ~/.config/openclaw/CLAW.REZ
    if [ -f "$HOME/.config/openclaw/CLAW.REZ" ]; then
        cp "$HOME/.config/openclaw/CLAW.REZ" "${BUNDLE_DIR}/CLAW.REZ"
    elif [ -f "$(dirname "$0")/../../../../CLAW.REZ" ]; then
        cp "$(dirname "$0")/../../../../CLAW.REZ" "${BUNDLE_DIR}/CLAW.REZ"
    fi
fi

if [ ! -f "CLAW.REZ" ]; then
    echo "!!! CLAW.REZ is missing from: ${BUNDLE_DIR}" >&2
    echo "!!! Please copy your original CLAW.REZ into this directory." >&2
    osascript -e "display dialog \"ملف CLAW.REZ غير موجود داخل حزمة اللعبة!\n\nيرجى نسخ ملف CLAW.REZ الخاص بلعبة Captain Claw الأصلية داخل مجلد Resources للتطبيق:\n${BUNDLE_DIR}\" with title \"Captain Claw (OpenClaw)\" buttons {\"فتح المجلد\", \"إلغاء\"} default button \"فتح المجلد\" with icon stop" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        open "${BUNDLE_DIR}"
    fi
    exit 1
fi

exec "$(dirname "$0")/openclaw-bin" "$@"
EOF
chmod +x "${APP_DIR}/Contents/MacOS/OpenClaw"

echo ">>> 6. Signing application bundle (ad-hoc)..."
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

echo "==========================================="
echo " SUCCESS! OpenClaw.app created at:"
echo " ${APP_DIR}"
echo "==========================================="
