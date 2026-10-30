#!/usr/bin/env bash
# Build an RPM package (.rpm) from the Flutter Linux release bundle.
#
#   VERSION=0.6.12 ARCH=x86_64 SKIP_BUILD=1 bash scripts/build_rpm.sh
#   SKIP_BUILD=1            reuse existing Flutter bundle, skip `flutter build`
#   BUNDLE=...              override Flutter bundle directory
#   OUT=...                 override output .rpm path
#
# Uses the spec template in packaging/rpm/defile.spec via rpmbuild.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="${APP_NAME:-defile}"
DISPLAY_NAME="${DISPLAY_NAME:-Defile}"
VERSION="${VERSION:-$(grep -m1 '^version:' pubspec.yaml | cut -d':' -f2 | cut -d'+' -f1 | tr -d ' ')}"
RELEASE="${RELEASE:-1}"
SUMMARY="${SUMMARY:-Minimalist modern file manager for Linux}"

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
  x86_64) RPM_ARCH="x86_64" ;;
  aarch64) RPM_ARCH="aarch64" ;;
  *)
    echo "Unsupported target architecture: $ARCH" >&2
    exit 1
    ;;
esac

BUNDLE="${BUNDLE:-build/linux/$FLUTTER_BUNDLE_ARCH/release/bundle}"
SPEC="${SPEC:-packaging/rpm/defile.spec}"
RPM_TOPDIR="${RPM_TOPDIR:-$ROOT/build/rpm}"
OUT="${OUT:-$RPM_TOPDIR/RPMS/$RPM_ARCH/${APP_NAME}-${VERSION}-${RELEASE}.$RPM_ARCH.rpm}"
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

if ! command -v rpmbuild >/dev/null 2>&1; then
  echo "rpmbuild not found. Install it first:" >&2
  echo "  Fedora/RHEL:   sudo dnf install rpm-build" >&2
  echo "  openSUSE:      sudo zypper install rpm-build" >&2
  echo "  Debian/Ubuntu: sudo apt-get install rpm" >&2
  echo "  Arch:          sudo pacman -S base-devel rpm-tools" >&2
  exit 1
fi

if [ ! -f "$SPEC" ]; then
  echo "Missing RPM spec: $SPEC" >&2
  exit 1
fi

# rpmbuild wants an absolute _topdir and absolute source paths passed as defines.
BUNDLE_ABS="$(cd "$BUNDLE" && pwd)"
ICON_ABS=""
if [ -f "$ICON_SRC" ]; then
  ICON_ABS="$(cd "$(dirname "$ICON_SRC")" && pwd)/$(basename "$ICON_SRC")"
fi
DESKTOP_ABS=""
if [ -f "$DESKTOP_SRC" ]; then
  DESKTOP_ABS="$(cd "$(dirname "$DESKTOP_SRC")" && pwd)/$(basename "$DESKTOP_SRC")"
fi

mkdir -p "$RPM_TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS,BUILDROOT}

echo "==> building rpm $APP_NAME-$VERSION-$RELEASE.$RPM_ARCH"
rpmbuild -bb "$SPEC" \
  --define "_topdir $RPM_TOPDIR" \
  --define "_version $VERSION" \
  --define "_release $RELEASE" \
  --define "_appname $APP_NAME" \
  --define "_displayname $DISPLAY_NAME" \
  --define "_summary $SUMMARY" \
  --define "_bundle $BUNDLE_ABS" \
  --define "_icon $ICON_ABS" \
  --define "_desktop $DESKTOP_ABS" \
  --target "$RPM_ARCH"

# rpmbuild appends %{dist} to the release in the filename; resolve the real artifact.
BUILT="$(ls -t "$RPM_TOPDIR"/RPMS/"$RPM_ARCH"/${APP_NAME}-${VERSION}-${RELEASE}*.$RPM_ARCH.rpm 2>/dev/null | head -n 1 || true)"
if [ -z "${BUILT:-}" ]; then
  echo "rpmbuild finished but no .rpm found in $RPM_TOPDIR/RPMS/$RPM_ARCH" >&2
  exit 1
fi

if [ "$BUILT" != "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  cp "$BUILT" "$OUT"
fi

echo "==> done: $OUT"
ls -lh "$OUT"
