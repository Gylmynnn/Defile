#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="defile"
DISPLAY_NAME="Defile"
ARCH="$(uname -m)"

BUNDLE="build/linux/$([ "$ARCH" = "aarch64" ] && echo arm64 || echo x64)/release/bundle"
APPDIR="build/appimage/${DISPLAY_NAME}.AppDir"
TOOL_DIR="/tmp/opencode/appimagetool"
TOOL="$TOOL_DIR/appimagetool-$ARCH.AppImage"

echo "==> flutter build linux --release"
flutter build linux --release

echo "==> assembling AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/icons/hicolor/256x256/apps"
cp -a "$BUNDLE/." "$APPDIR/usr/bin/"

cp macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png "$APPDIR/$APP_NAME.png"
cp "$APPDIR/$APP_NAME.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$APP_NAME.png"

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
exec "$HERE/usr/bin/defile" "$@"
EOF
chmod +x "$APPDIR/AppRun"

cat > "$APPDIR/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$DISPLAY_NAME
Comment=Modern file explorer
Exec=$APP_NAME
Icon=$APP_NAME
Categories=Utility;FileManager;
Terminal=false
EOF

if [ ! -x "$TOOL" ]; then
  echo "==> fetching appimagetool"
  mkdir -p "$TOOL_DIR"
  curl -fL -o "$TOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
  chmod +x "$TOOL"
fi

echo "==> packaging AppImage"
export APPIMAGE_EXTRACT_AND_RUN=1
"$TOOL" "$APPDIR" "build/appimage/${DISPLAY_NAME}-${ARCH}.AppImage"

echo "==> done: build/appimage/${DISPLAY_NAME}-${ARCH}.AppImage"
