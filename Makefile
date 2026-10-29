# Build & install Defile as an AppImage locally — no git tag / GitHub
# release needed for testing.
#
#   make                build + install (kills running instances first,
#                       then restarts xdg-desktop-portal)
#   make build          only build build/appimage/Defile-<ver>-x86_64.AppImage
#   make install        install (builds first; add SKIP_BUILD=1 to reuse the
#                       last release bundle without recompiling)
#   make run            launch the installed AppImage
#   make stop           kill every running Defile instance
#   make portal-restart revive the portal daemon (kill stale process, start
#                       the unit, verify FileChooser is exported)
#   make test           flutter analyze + flutter test
#   make check          flutter analyze only
#   make clean          remove AppImage artifacts (keeps the debug bundle —
#                       widget tests load its .so)

VERSION ?= $(shell grep -m1 '^version:' pubspec.yaml | cut -d':' -f2 | cut -d'+' -f1 | tr -d ' ')
ARCH ?= x86_64
APPIMAGE := build/appimage/Defile-$(VERSION)-$(ARCH).AppImage
INSTALL_DIR ?= $(HOME)/.local/opt/defile
INSTALL_PATH := $(INSTALL_DIR)/Defile.AppImage
PORTAL_UNIT := xdg-desktop-portal

.DEFAULT_GOAL := install
.PHONY: all build install run stop portal-restart test check clean

all: install

build:
	VERSION="$(VERSION)" SKIP_BUILD="$(SKIP_BUILD)" bash scripts/build_appimage.sh

# Kill every instance BEFORE touching the AppImage file: the squashfs mount
# reads pages lazily, so replacing the file under a live process ends in a
# SIGBUS crash the moment it touches a not-yet-cached page. A daemon-activated
# backend runs as /tmp/.mount_XXXXX/usr/bin/defile --dbus-portal — its cmdline
# never mentions the AppImage path, hence the extra patterns. Brackets ([.],
# [--]) keep pkill from matching the recipe's own command line.
stop:
	-pkill -f "Defile[.]AppImage" 2>/dev/null
	-pkill -f "defile [--]dbus-portal" 2>/dev/null
	-pkill -f "/tmp/[.]mount_Defile" 2>/dev/null
	-pkill -f "bundle/[d]efile" 2>/dev/null
	@sleep 1
	@echo "==> semua instance Defile dihentikan"

# Recovery for the portal daemon: after a session crash it can end up
# running OUTSIDE any systemd unit (spawned directly by dbus-daemon), so
# `systemctl --user restart` only starts a second instance that loses the
# name race and exits while the stale daemon stays in place. Kill the
# process first, then start the unit fresh. The anchored pattern (^...$)
# spares xdg-desktop-portal-gtk / -hyprland.
portal-restart:
	-/usr/bin/pkill -f "^/usr/lib/xdg-desktop-portal$$" 2>/dev/null
	@sleep 1
	systemctl --user start $(PORTAL_UNIT)
	@sleep 3
	@echo "==> FileChooser terekspor: $$(gdbus introspect --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop 2>/dev/null | grep -c 'org.freedesktop.portal.FileChooser')"

install: build
	@$(MAKE) --no-print-directory stop
	@mkdir -p "$(INSTALL_DIR)"
	install -m 755 "$(APPIMAGE)" "$(INSTALL_PATH)"
	@echo "==> terpasang: $(INSTALL_PATH)"
	@$(MAKE) --no-print-directory portal-restart
	@echo "==> selesai. Portal siap; test via app dengan GTK_USE_PORTAL=1"

run:
	"$(INSTALL_PATH)"

test:
	flutter analyze
	flutter test

check:
	flutter analyze

clean:
	rm -rf build/appimage
