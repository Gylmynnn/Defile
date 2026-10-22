#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="${APP_NAME:-defile}"
DISPLAY_NAME="${DISPLAY_NAME:-Defile}"
VERSION="${VERSION:-0.0.0}"

HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
  x86_64 | amd64)
    HOST_APPIMAGE_ARCH="x86_64"
    FLUTTER_BUNDLE_ARCH="x64"
    ;;
  aarch64 | arm64)
    HOST_APPIMAGE_ARCH="aarch64"
    FLUTTER_BUNDLE_ARCH="arm64"
    ;;
  *)
    echo "Unsupported host architecture: $HOST_ARCH" >&2
    exit 1
    ;;
esac

ARCH="${ARCH:-$HOST_APPIMAGE_ARCH}"
if [ "$ARCH" != "$HOST_APPIMAGE_ARCH" ]; then
  echo "Cross-architecture packaging is not supported: host=$HOST_APPIMAGE_ARCH target=$ARCH" >&2
  exit 1
fi

BUNDLE="${BUNDLE:-build/linux/$FLUTTER_BUNDLE_ARCH/release/bundle}"
APPDIR="${APPDIR:-build/appimage/AppDir-$ARCH}"
OUT="${OUT:-build/appimage/${DISPLAY_NAME}-${VERSION}-${ARCH}.AppImage}"
TOOL_DIR="${TOOL_DIR:-build/appimage/tools}"
TOOL="$TOOL_DIR/appimagetool-$ARCH.AppImage"
ICON="macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  echo "==> flutter build linux --release"
  flutter build linux --release
fi

if [ ! -d "$BUNDLE" ]; then
  echo "Missing Flutter bundle: $BUNDLE" >&2
  echo "Run 'flutter build linux --release' first, or unset SKIP_BUILD." >&2
  exit 1
fi

echo "==> assembling AppDir"
rm -rf "$APPDIR"
mkdir -p \
  "$APPDIR/usr/bin" \
  "$APPDIR/usr/share/applications" \
  "$APPDIR/usr/share/icons/hicolor/512x512/apps"
cp -a "$BUNDLE/." "$APPDIR/usr/bin/"

cp "$ICON" "$APPDIR/$APP_NAME.png"
cp "$ICON" "$APPDIR/usr/share/icons/hicolor/512x512/apps/$APP_NAME.png"
ln -s "$APP_NAME.png" "$APPDIR/.DirIcon"

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
cp "$APPDIR/$APP_NAME.desktop" "$APPDIR/usr/share/applications/$APP_NAME.desktop"

if [ ! -x "$TOOL" ]; then
  echo "==> fetching appimagetool"
  mkdir -p "$TOOL_DIR"
  curl -fL -o "$TOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
  chmod +x "$TOOL"
fi

echo "==> packaging AppImage"
mkdir -p "$(dirname "$OUT")"
export APPIMAGE_EXTRACT_AND_RUN=1
ARCH="$ARCH" VERSION="$VERSION" "$TOOL" "$APPDIR" "$OUT"

echo "==> done: $OUT"
