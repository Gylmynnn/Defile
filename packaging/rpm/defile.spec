# RPM spec for Defile. Built by scripts/build_rpm.sh, which passes the
# Flutter bundle location and metadata as --define overrides:
#
#   rpmbuild -bb packaging/rpm/defile.spec \
#     --define "_topdir $PWD/build/rpm" \
#     --define "_version 0.6.12" \
#     --define "_release 1" \
#     --define "_appname defile" \
#     --define "_displayname Defile" \
#     --define "_summary Minimalist modern file manager for Linux" \
#     --define "_bundle $PWD/build/linux/x64/release/bundle" \
#     --define "_icon $PWD/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png" \
#     --define "_desktop $PWD/packaging/defile.desktop"
#
# Upstream publishes no SPDX license identifier yet; keep the tag honest
# until one is chosen (see https://github.com/Gylmynnn/Defile).

Name:           %{?_appname}%{!?_appname:defile}
Version:        %{?_version}%{!?_version:0.0.0}
Release:        %{?_release}%{!?_release:1}%{?dist}
Summary:        %{?_summary}%{!?_summary:Minimalist modern file manager for Linux}
License:        Unknown
URL:            https://github.com/Gylmynnn/Defile
ExclusiveArch:  x86_64 aarch64

# Runtime: Flutter GTK app using libmpv for previews.
Requires:       gtk3
Requires:       mpv-libs
Requires:       libepoxy

BuildArch:      %{_target_cpu}
BuildRoot:      %{_topdir}/BUILDROOT/%{name}-%{version}-%{release}.%{_target_cpu}

%description
A minimalist modern file manager for Linux.

%install
rm -rf "%{buildroot}"
mkdir -p "%{buildroot}/opt/%{name}"
mkdir -p "%{buildroot}/usr/bin"
mkdir -p "%{buildroot}/usr/share/applications"
mkdir -p "%{buildroot}/usr/share/icons/hicolor/512x512/apps"

cp -a "%{_bundle}/." "%{buildroot}/opt/%{name}/"
chmod 755 "%{buildroot}/opt/%{name}/%{name}"
ln -s "/opt/%{name}/%{name}" "%{buildroot}/usr/bin/%{name}"

# Desktop entry: prefer the repo template, fall back to an inline one so a
# missing --define or file never breaks the build.
if [ -n "%{_desktop}" ] && [ -f "%{_desktop}" ]; then
  cp "%{_desktop}" "%{buildroot}/usr/share/applications/%{name}.desktop"
else
  cat > "%{buildroot}/usr/share/applications/%{name}.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Defile
Comment=Minimalist modern file manager for Linux
Exec=/usr/bin/defile
Icon=defile
Categories=Utility;FileManager;
Terminal=false
StartupWMClass=defile
EOF
fi
chmod 644 "%{buildroot}/usr/share/applications/%{name}.desktop"

if [ -n "%{_icon}" ] && [ -f "%{_icon}" ]; then
  cp "%{_icon}" "%{buildroot}/usr/share/icons/hicolor/512x512/apps/%{name}.png"
  chmod 644 "%{buildroot}/usr/share/icons/hicolor/512x512/apps/%{name}.png"
fi

%files
/opt/%{name}/
/usr/bin/%{name}
/usr/share/applications/%{name}.desktop
/usr/share/icons/hicolor/512x512/apps/%{name}.png

%changelog
* Fri Oct 30 2026 Defile Maintainers <https://github.com/Gylmynnn/Defile> - 0.6.12-1
- Package Flutter Linux bundle as .rpm alongside .deb and AppImage
