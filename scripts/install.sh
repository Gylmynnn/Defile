#!/usr/bin/env bash
set -euo pipefail

REPO="Gylmynnn/Defile"
APP="defile"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$HOME/.local/opt/$APP"
BIN_DIR="$HOME/.local/bin"
ICON_DIR="$DATA_HOME/icons/hicolor/512x512/apps"
DESKTOP_DIR="$DATA_HOME/applications"
ICON_URL="https://raw.githubusercontent.com/$REPO/main/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"

case "$(uname -m)" in
  x86_64 | amd64) ARCH="x86_64" ;;
  aarch64 | arm64) ARCH="aarch64" ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

echo "==> resolving latest release"
URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -oE "https://[^\"]*Defile-[^\"]*-$ARCH\\.AppImage" \
  | head -n 1 || true)"

if [ -z "$URL" ]; then
  echo "No $ARCH AppImage found in the latest release." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> downloading $URL"
curl -fL --retry 3 -o "$TMP/Defile.AppImage" "$URL"
chmod +x "$TMP/Defile.AppImage"

mkdir -p "$APP_DIR" "$BIN_DIR" "$ICON_DIR" "$DESKTOP_DIR"
mv "$TMP/Defile.AppImage" "$APP_DIR/Defile.AppImage"
ln -sf "$APP_DIR/Defile.AppImage" "$BIN_DIR/$APP"

echo "==> installing icon"
curl -fsSL -o "$ICON_DIR/$APP.png" "$ICON_URL"

cat > "$DESKTOP_DIR/$APP.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Defile
Comment=Modern file explorer
Exec="$APP_DIR/Defile.AppImage"
Icon=$APP
Terminal=false
Categories=Utility;FileManager;
StartupWMClass=defile
EOF

update-desktop-database -q "$DESKTOP_DIR" 2>/dev/null || true

echo "==> installed: $APP_DIR/Defile.AppImage"
echo "==> launcher entry: $DESKTOP_DIR/$APP.desktop"
echo "==> command: $BIN_DIR/$APP"
