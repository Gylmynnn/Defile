#!/usr/bin/env bash
# Defile universal installer — one-liner:
#
#   curl -fsSL https://raw.githubusercontent.com/Gylmynnn/Defile/main/scripts/install.sh | bash
#
# What it does (in order):
#   Debian/Ubuntu and derivatives → installs the release .deb (system-wide)
#   Fedora/RHEL/openSUSE          → installs the release .rpm (system-wide)
#   Arch / CachyOS / Manjaro      → tries AUR helper (defile-bin), else AppImage
#   Anything else                 → installs the release AppImage to
#                                  ~/.local/opt/defile + ~/.local/bin/defile
#
# Options / env overrides:
#   bash install.sh [--appimage|--deb|--rpm|--aur] [--version X.Y.Z]
#   DEFIlE_METHOD=appimage|deb|rpm|aur  DEFIlE_VERSION=X.Y.Z  REPO=owner/name
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

install_aur() {
  if have yay; then
    msg "installing defile-bin via yay"
    yay -S --noconfirm defile-bin
    return
  fi
  if have paru; then
    msg "installing defile-bin via paru"
    paru -S --noconfirm defile-bin
    return
  fi
  echo "No AUR helper (yay/paru) found. Install manually:" >&2
  echo "  git clone https://aur.archlinux.org/defile-bin.git" >&2
  echo "  cd defile-bin && makepkg -si" >&2
  echo "Falling back to AppImage install." >&2
  install_appimage "$1"
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
      if have yay || have paru; then echo "aur"; else echo "appimage"; fi
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
