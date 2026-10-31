#!/usr/bin/env bash
# Defile universal installer — one-liner:
#
#   curl -fsSL https://raw.githubusercontent.com/Gylmynnn/Defile/main/scripts/install.sh | bash
#
# What it does (in order):
#   Debian/Ubuntu and derivatives → installs the release .deb (system-wide)
#   Fedora/RHEL/openSUSE          → installs the release .rpm (system-wide)
#   Arch / CachyOS / Manjaro      → AUR (defile-bin) when it is published and an
#                                  AUR helper exists; otherwise AppImage
#   Anything else                 → installs the release AppImage to
#                                  ~/.local/opt/defile + ~/.local/bin/defile
#
# Options / env overrides:
#   bash install.sh [--appimage|--deb|--rpm|--aur] [--version X.Y.Z]
#   DEFIlE_METHOD=appimage|deb|rpm|aur  DEFIlE_VERSION=X.Y.Z  REPO=owner/name
#   AUR_PACKAGE=defile-bin  (package name to probe on the AUR)
set -euo pipefail

REPO="${REPO:-Gylmynnn/Defile}"
APP="defile"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$HOME/.local/opt/$APP"
BIN_DIR="$HOME/.local/bin"
ICON_DIR="$DATA_HOME/icons/hicolor/512x512/apps"
DESKTOP_DIR="$DATA_HOME/applications"
ICON_URL="https://raw.githubusercontent.com/$REPO/main/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"

METHOD="${DEFIlE_METHOD:-auto}"
PINNED_VERSION="${DEFIlE_VERSION:-}"

usage() {
  echo "Usage: install.sh [--appimage|--deb|--rpm|--aur] [--version X.Y.Z]" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --appimage) METHOD="appimage"; shift ;;
    --deb) METHOD="deb"; shift ;;
    --rpm) METHOD="rpm"; shift ;;
    --aur) METHOD="aur"; shift ;;
    --version) PINNED_VERSION="${2:-}"; shift 2 ;;
    --version=*) PINNED_VERSION="${1#*=}"; shift ;;
    -h | --help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

case "$(uname -m)" in
  x86_64 | amd64) ARCH="x86_64"; DEB_ARCH="amd64"; RPM_ARCH="x86_64" ;;
  aarch64 | arm64) ARCH="aarch64"; DEB_ARCH="arm64"; RPM_ARCH="aarch64" ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

msg() { echo "==> $*"; }
have() { command -v "$1" >/dev/null 2>&1; }

resolve_version() {
  if [ -n "$PINNED_VERSION" ]; then
    echo "${PINNED_VERSION#v}"
    return
  fi
  local tag
  tag="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | head -n 1 | grep -oE 'v?[0-9][^"]*' || true)"
  if [ -z "$tag" ]; then
    echo "Could not resolve latest release for $REPO." >&2
    exit 1
  fi
  echo "${tag#v}"
}

need_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    return 0
  fi
  if have sudo; then
    return 0
  fi
  echo "sudo is required for system packages but was not found. Re-run as root or use --appimage." >&2
  exit 1
}

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

download() {
  local url="$1" dest="$2"
  msg "downloading $url"
  curl -fL --retry 3 -o "$dest" "$url"
}

install_appimage() {
  local ver="$1"
  local url="https://github.com/$REPO/releases/download/v${ver}/Defile-${ver}-${ARCH}.AppImage"
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  download "$url" "$tmp/Defile.AppImage"
  chmod +x "$tmp/Defile.AppImage"

  mkdir -p "$APP_DIR" "$BIN_DIR" "$ICON_DIR" "$DESKTOP_DIR"
  mv "$tmp/Defile.AppImage" "$APP_DIR/Defile.AppImage"
  ln -sf "$APP_DIR/Defile.AppImage" "$BIN_DIR/$APP"

  msg "installing icon"
  curl -fsSL -o "$ICON_DIR/$APP.png" "$ICON_URL"

  cat > "$DESKTOP_DIR/$APP.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Defile
Comment=Minimalist modern file manager for Linux
Exec="$APP_DIR/Defile.AppImage"
Icon=$APP
Terminal=false
Categories=Utility;FileManager;
StartupWMClass=defile
EOF

  update-desktop-database -q "$DESKTOP_DIR" 2>/dev/null || true
  trap - EXIT
  rm -rf "$tmp"

  msg "installed: $APP_DIR/Defile.AppImage"
  msg "launcher entry: $DESKTOP_DIR/$APP.desktop"
  msg "command: $BIN_DIR/$APP"
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "NOTE: $BIN_DIR is not in PATH. Add: export PATH=\"\$HOME/.local/bin:\$PATH\"" >&2 ;;
  esac
}

install_deb() {
  local ver="$1"
  local url="https://github.com/$REPO/releases/download/v${ver}/defile_${ver}_${DEB_ARCH}.deb"
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  need_sudo
  download "$url" "$tmp/defile.deb"
  msg "installing .deb (system-wide)"
  if have apt-get; then
    run_root apt-get update
    run_root apt-get install -y "$tmp/defile.deb"
  else
    run_root dpkg -i "$tmp/defile.deb"
  fi
  trap - EXIT
  rm -rf "$tmp"
  msg "installed: /usr/bin/$APP"
}

install_rpm() {
  local ver="$1"
  local url="https://github.com/$REPO/releases/download/v${ver}/defile-${ver}-${RPM_ARCH}.rpm"
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  need_sudo
  download "$url" "$tmp/defile.rpm"
  msg "installing .rpm (system-wide)"
  if have dnf; then
    run_root dnf install -y "$tmp/defile.rpm"
  elif have zypper; then
    run_root zypper --non-interactive install "$tmp/defile.rpm"
  elif have yum; then
    run_root yum install -y "$tmp/defile.rpm"
  else
    run_root rpm -Uvh "$tmp/defile.rpm"
  fi
  trap - EXIT
  rm -rf "$tmp"
  msg "installed: /usr/bin/$APP"
}

# Is the package published to the AUR yet? The recipe ships from this repo but
# publishing to aur.archlinux.org is a separate manual step, so the package may
# legitimately not exist. Returns non-zero when it cannot be confirmed.
aur_available() {
  local pkg="${AUR_PACKAGE:-defile-bin}"
  local body
  body="$(curl -fsSL --max-time 15 \
    "https://aur.archlinux.org/rpc/v5/info/$pkg" 2>/dev/null || true)"
  case "$body" in
    *'"resultcount":0'* | "") return 1 ;;
    *'"Name":"'"$pkg"'"'*) return 0 ;;
    *) return 1 ;;
  esac
}

install_aur() {
  local ver="$1"

  # AUR not ready → fall back to the AppImage (same files, no system package).
  if ! aur_available; then
    msg "defile-bin is not published on the AUR yet"
    msg "falling back to AppImage install"
    install_appimage "$ver"
    return 0
  fi

  local helper=""
  if have yay; then helper="yay"
  elif have paru; then helper="paru"
  fi

  if [ -z "$helper" ]; then
    msg "no AUR helper (yay/paru) found — falling back to AppImage install"
    install_appimage "$ver"
    return 0
  fi

  msg "installing defile-bin via $helper"
  # A failed helper run (helper itself broken, user aborted, PKGBUILD error)
  # must not leave the machine without Defile: fall through to AppImage.
  if "$helper" -S --noconfirm "${AUR_PACKAGE:-defile-bin}"; then
    return 0
  fi
  msg "AUR install via $helper failed — falling back to AppImage install"
  install_appimage "$ver"
}

detect_method() {
  local id="" like=""
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-}"
    like="${ID_LIKE:-}"
  fi
  case " $id $like " in
    *"debian"* | *"ubuntu"* | *"linuxmint"* | *"pop"* | *"neon"* | *"zorin"* | *"kali"* | *"raspbian"*)
      echo "deb"
      ;;
    *"fedora"* | *"rhel"* | *"centos"* | *"rocky"* | *"alma"* | *"ol"* | *"opensuse"* | *"suse"*)
      echo "rpm"
      ;;
    *"arch"* | *"cachyos"* | *"manjaro"* | *"endeavouros"*)
      # Arch only uses the AUR path once defile-bin is actually published;
      # until then the AppImage install is the supported route.
      if { have yay || have paru; } && aur_available; then
        echo "aur"
      else
        echo "appimage"
      fi
      ;;
    *)
      if have apt-get; then echo "deb"
      elif have dnf || have yum || have zypper || have rpm; then echo "rpm"
      elif have pacman; then echo "appimage"
      else echo "appimage"
      fi
      ;;
  esac
}

main() {
  local ver
  ver="$(resolve_version)"
  msg "latest release: v$ver ($ARCH)"

  local method="$METHOD"
  if [ "$method" = "auto" ]; then
    method="$(detect_method)"
  fi
  msg "install method: $method"

  case "$method" in
    deb) install_deb "$ver" ;;
    rpm) install_rpm "$ver" ;;
    aur) install_aur "$ver" ;;
    appimage) install_appimage "$ver" ;;
    *)
      echo "Unknown method: $method (expected deb|rpm|aur|appimage)" >&2
      exit 1
      ;;
  esac
}

main "$@"
