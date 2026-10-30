#!/usr/bin/env bash
# Build a Debian package (.deb) from the Flutter Linux release bundle.
#
#   VERSION=0.6.12 ARCH=x86_64 SKIP_BUILD=1 bash scripts/build_deb.sh
#   SKIP_BUILD=1            reuse existing Flutter bundle, skip `flutter build`
#   BUNDLE=...              override Flutter bundle directory
#   OUT=...                 override output .deb path
#
# Layout inside the package:
#   /opt/defile/                    Flutter bundle (defile binary, lib/, data/)
#   /usr/bin/defile                 symlink -> /opt/defile/defile
#   /usr/share/applications/defile.desktop
#   /usr/share/icons/hicolor/512x512/apps/defile.png
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="${APP_NAME:-defile}"
DISPLAY_NAME="${DISPLAY_NAME:-Defile}"
VERSION="${VERSION:-$(grep -m1 '^version:' pubspec.yaml | cut -d':' -f2 | cut -d'+' -f1 | tr -d ' ')}"
MAINTAINER="${MAINTAINER:-Defile Maintainers <https://github.com/Gylmynnn/Defile>}"
DESCRIPTION="${DESCRIPTION:-Minimalist modern file manager for Linux}"

HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
  x86_64 | amd64)
    HOST_ARCH_NORM="x86_64"
    FLUTTER_BUNDLE_ARCH="x64"
    ;;
  aarch64 | arm64)
    HOST_ARCH_NORM="aarch64"
    FLUTTER_BUNDLE_ARCH="arm64"
    ;;
  *)
    echo "Unsupported host architecture: $HOST_ARCH" >&2
    exit 1
    ;;
esac

ARCH="${ARCH:-$HOST_ARCH_NORM}"
if [ "$ARCH" != "$HOST_ARCH_NORM" ]; then
  echo "Cross-architecture packaging is not supported: host=$HOST_ARCH_NORM target=$ARCH" >&2
  exit 1
fi

case "$ARCH" in
  x86_64) DEB_ARCH="amd64" ;;
  aarch64) DEB_ARCH="arm64" ;;
  *)
    echo "Unsupported target architecture: $ARCH" >&2
    exit 1
    ;;
esac

BUNDLE="${BUNDLE:-build/linux/$FLUTTER_BUNDLE_ARCH/release/bundle}"
STAGEDIR="${STAGEDIR:-build/deb/${APP_NAME}_${VERSION}_${DEB_ARCH}}"
OUT="${OUT:-build/deb/${APP_NAME}_${VERSION}_${DEB_ARCH}.deb}"
ICON_SRC="${ICON_SRC:-macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png}"
DESKTOP_SRC="${DESKTOP_SRC:-packaging/defile.desktop}"

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  echo "==> flutter build linux --release"
  flutter build linux --release
fi

if [ ! -x "$BUNDLE/$APP_NAME" ]; then
  echo "Missing Flutter bundle binary: $BUNDLE/$APP_NAME" >&2
  echo "Run 'flutter build linux --release' first, or set SKIP_BUILD=1 with an existing bundle." >&2
  exit 1
fi

if ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "dpkg-deb not found. Install it first:" >&2
  echo "  sudo apt-get install dpkg-dev" >&2
  exit 1
fi

echo "==> staging .deb in $STAGEDIR"
rm -rf "$STAGEDIR"
mkdir -p \
  "$STAGEDIR/DEBIAN" \
  "$STAGEDIR/opt/$APP_NAME" \
  "$STAGEDIR/usr/bin" \
  "$STAGEDIR/usr/share/applications" \
  "$STAGEDIR/usr/share/icons/hicolor/512x512/apps"

cp -a "$BUNDLE/." "$STAGEDIR/opt/$APP_NAME/"
chmod 755 "$STAGEDIR/opt/$APP_NAME/$APP_NAME"
ln -s "/opt/$APP_NAME/$APP_NAME" "$STAGEDIR/usr/bin/$APP_NAME"

if [ -f "$DESKTOP_SRC" ]; then
  cp "$DESKTOP_SRC" "$STAGEDIR/usr/share/applications/$APP_NAME.desktop"
else
  cat > "$STAGEDIR/usr/share/applications/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$DISPLAY_NAME
Comment=$DESCRIPTION
Exec=/usr/bin/$APP_NAME
Icon=$APP_NAME
Categories=Utility;FileManager;
Terminal=false
StartupWMClass=$APP_NAME
EOF
fi

if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "$STAGEDIR/usr/share/icons/hicolor/512x512/apps/$APP_NAME.png"
fi
chmod 644 "$STAGEDIR/usr/share/applications/$APP_NAME.desktop"
[ -f "$STAGEDIR/usr/share/icons/hicolor/512x512/apps/$APP_NAME.png" ] \
  && chmod 644 "$STAGEDIR/usr/share/icons/hicolor/512x512/apps/$APP_NAME.png"

INSTALLED_SIZE="$(du -sk "$STAGEDIR/opt/$APP_NAME" | cut -f1)"

cat > "$STAGEDIR/DEBIAN/control" <<EOF
Package: $APP_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $DEB_ARCH
Maintainer: $MAINTAINER
Description: $DESCRIPTION
 A minimalist modern file manager for Linux.
Installed-Size: $INSTALLED_SIZE
Depends: libgtk-3-0 | libgtk-3-0t64, libmpv2 | libmpv1 | libmpv2t64, libepoxy0 | libepoxy0t64, libstdc++6, libc6
EOF

echo "==> building $OUT"
mkdir -p "$(dirname "$OUT")"
dpkg-deb --build "$STAGEDIR" "$OUT"
echo "==> done: $OUT"
ls -lh "$OUT"
