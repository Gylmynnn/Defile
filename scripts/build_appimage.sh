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

# --- Bundle libmpv and its codec stack --------------------------------------
# libmedia_kit_video_plugin.so links against the host's libmpv. Without it the
# dynamic loader aborts before Flutter can create a window, which makes the
# AppImage unusable on systems where mpv is not installed. Ship libmpv plus
# every dependency the app does not already take from the host (GTK, X11, ...).
LIBS_DIR="$APPDIR/usr/bin/lib"

# Ask the plugin itself where its libmpv comes from (works with multiarch and
# custom prefixes); fall back to the dynamic linker cache. The soname depends on
# the build distribution (libmpv.so.2 on newer ones, libmpv.so.1 on Ubuntu
# 22.04), so match any of them instead of hard-coding a version.
if [ -z "${MPV_LIB:-}" ]; then
  MPV_LIB="$(ldd "$LIBS_DIR/libmedia_kit_video_plugin.so" 2>/dev/null |
    awk '$1 ~ /^libmpv\.so\./ && !found { print $3; found = 1 }')"
fi
MPV_LIB="${MPV_LIB:-$(ldconfig -p 2>/dev/null | awk '$1 ~ /^libmpv\.so\./ && !found { print $NF; found = 1 }')}"
if [ -z "$MPV_LIB" ] || [ ! -e "$MPV_LIB" ]; then
  echo "libmpv not found." >&2
  echo "Install mpv with its development files (e.g. libmpv-dev) and retry." >&2
  exit 1
fi

# Ship it under the name the plugin actually asks the loader for.
MPV_SONAME="$(readelf -d "$MPV_LIB" 2>/dev/null |
  awk -F'[][]' '/SONAME/ && !found { print $2; found = 1 }')"
MPV_SONAME="${MPV_SONAME:-$(basename "$(readlink -f "$MPV_LIB")")}"

MPV_LDD="$(ldd "$MPV_LIB")"
if grep -q "not found" <<<"$MPV_LDD"; then
  echo "libmpv at $MPV_LIB has unresolved dependencies:" >&2
  grep "not found" <<<"$MPV_LDD" >&2
  exit 1
fi

echo "==> bundling libmpv ($MPV_LIB)"

# Libraries the Flutter bundle already expects from the host. The AppImage
# deliberately does not ship GTK/X11 (the Flutter Linux embedder never did),
# so those stay system-provided and must not be duplicated: mixing a bundled
# GLib with the host's GTK breaks at runtime.
declare -A HOST_LIBS=()
for so in "$LIBS_DIR"/*.so; do
  case "$(basename "$so")" in
    libmedia_kit_video_plugin.so) continue ;;
  esac
  while read -r name; do
    HOST_LIBS["$name"]=1
  done < <(ldd "$so" 2>/dev/null | awk '/=>/ { print $1 } /^\// { print $1 }')
done

# GL/EGL/DRM are tied to the host's GPU drivers; bundling them breaks more
# than it fixes. glibc and the C++ runtime are part of the base system too.
# X extension libraries (Xpresent, Xss, Xv, X11-xcb, ...) are not part of the
# base X11 set: libmpv needs them and minimal systems do not ship them, so
# they are bundled unless the Flutter bundle already pulls them from the host.
is_host_provided() {
  case "$1" in
    ld-linux* | libc.so.* | libm.so.* | libmvec* | libdl.so.* | libpthread*)
      return 0 ;;
    librt.so.* | libresolv* | libutil* | libnsl* | libanl* | libgcc_s* | libstdc++*)
      return 0 ;;
    libGL.so.* | libEGL.so.* | libGLX* | libGLdispatch* | libOpenGL* | libdrm.so.*)
      return 0 ;;
    libgbm* | libglapi*)
      return 0 ;;
    libsystemd* | libudev* | libdbus-1* | libselinux*)
      return 0 ;;
  esac

  return 1
}

should_bundle() {
  local name="$1"

  [ -n "${HOST_LIBS[$name]:-}" ] && return 1
  is_host_provided "$name" && return 1

  return 0
}

cp -L "$MPV_LIB" "$LIBS_DIR/$MPV_SONAME"

# media_kit's Dart FFI opens the unversioned "libmpv.so" before it tries the
# versioned sonames. Shipping only the soname made the loader skip the bundled
# copy on any system that has mpv installed, so a *second* libmpv was mapped
# from the host while libmedia_kit_video_plugin.so kept using the bundled one.
# The mpv handle was then created through one instance and the render API
# driven through the other, which aborts inside libmpv
# ("m_config_core.c: m_config_cache_from_shadow: Assertion `group_index >= 0'")
# as soon as a video preview starts. Expose the unversioned name as a symlink:
# the loader notices the shared inode and both paths reuse one instance.
ln -sf "$MPV_SONAME" "$LIBS_DIR/libmpv.so"

while read -r name path; do
  should_bundle "$name" || continue
  if [ ! -e "$path" ]; then
    echo "Missing dependency of libmpv: $name" >&2
    exit 1
  fi
  cp -L "$path" "$LIBS_DIR/$name"
done < <(printf '%s\n' "$MPV_LDD" | awk '/=> \// { print $1, $3 }')

cp "$ICON" "$APPDIR/$APP_NAME.png"
cp "$ICON" "$APPDIR/usr/share/icons/hicolor/512x512/apps/$APP_NAME.png"
ln -s "$APP_NAME.png" "$APPDIR/.DirIcon"

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
# Plugin libraries and the bundled mpv stack live in usr/bin/lib. RUNPATH only
# covers the executable's direct dependencies, so export the directory for the
# transitive loads instead.
export LD_LIBRARY_PATH="$HERE/usr/bin/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
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

# Fail early on libraries the AppImage still expects from the host but does not
# ship. The catalog test runs on a minimal system, so a single unresolved entry
# makes the whole AppImage unusable there.
echo "==> checking dependencies"
missing=0
while read -r elf; do
  while read -r name _; do
    # Host-provided libraries (GPU drivers, glibc, system integration) are
    # intentionally not shipped; anything else must resolve inside the AppImage.
    is_host_provided "$name" && continue
    echo "Unresolved dependency in ${elf#"$APPDIR"/}: $name" >&2
    missing=1
  done < <(LD_LIBRARY_PATH="$LIBS_DIR" ldd "$elf" 2>/dev/null | grep "not found" || true)
done < <(find "$APPDIR/usr/bin" -maxdepth 2 -type f \
  \( -name "$APP_NAME" -o -name '*.so' -o -name '*.so.*' \))
if [ "$missing" -ne 0 ]; then
  echo "The AppImage is not self-contained; bundle the libraries above." >&2
  exit 1
fi

if command -v objdump >/dev/null 2>&1; then
  glibc="$(
    find "$APPDIR/usr/bin" -maxdepth 2 -type f \
      \( -name "$APP_NAME" -o -name '*.so' -o -name '*.so.*' \) -print0 |
      xargs -0 -r objdump -T 2>/dev/null |
      grep -o 'GLIBC_[0-9.]*' | sed 's/^GLIBC_//' | sort -Vu | tail -n 1
  )"
  echo "==> highest glibc symbol version: ${glibc:-unknown}"

  # Release builds must stay compatible with the oldest system we support (and
  # with the AppImage catalog test environment, Ubuntu 22.04 / glibc 2.35).
  if [ -n "${MAX_GLIBC:-}" ]; then
    if [ -z "$glibc" ] ||
      [ "$(printf '%s\n%s\n' "$glibc" "$MAX_GLIBC" | sort -Vu | tail -n 1)" != "$MAX_GLIBC" ]; then
      echo "glibc baseline $glibc exceeds MAX_GLIBC=$MAX_GLIBC." >&2
      echo "Build on an older distribution instead of bundling newer libraries." >&2
      exit 1
    fi
  fi
fi

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
