# defile

A minimalist modern file manager for Linux.

<img width="2752" height="1536" alt="defile" src="https://github.com/user-attachments/assets/4ecf372a-cb6e-48f6-ae4d-07b49e427fbd" />

## Install

One-liner (auto-detects your distro and installs `.deb` / `.rpm`, or falls
back to the AppImage on Arch and other distros):

```bash
curl -fsSL https://raw.githubusercontent.com/Gylmynnn/Defile/main/scripts/install.sh | bash
```

Force a specific method:

```bash
curl -fsSL https://raw.githubusercontent.com/Gylmynnn/Defile/main/scripts/install.sh | bash -s -- --deb
curl -fsSL https://raw.githubusercontent.com/Gylmynnn/Defile/main/scripts/install.sh | bash -s -- --rpm
curl -fsSL https://raw.githubusercontent.com/Gylmynnn/Defile/main/scripts/install.sh | bash -s -- --appimage
```

### Debian / Ubuntu (`.deb`)

Download `defile_<version>_amd64.deb` (or `_arm64.deb`) from the
[releases page](https://github.com/Gylmynnn/Defile/releases), then:

```bash
sudo apt install ./defile_0.6.12_amd64.deb
```

Requires: `libgtk-3-0 | libgtk-3-0t64`, `libmpv2 | libmpv2t64`, `libepoxy0`.

### Fedora / RHEL / openSUSE (`.rpm`)

Download `defile-<version>-x86_64.rpm` (or `-aarch64.rpm`) from the
[releases page](https://github.com/Gylmynnn/Defile/releases), then:

```bash
# Fedora / RHEL
sudo dnf install ./defile-0.6.12-x86_64.rpm
# openSUSE
sudo zypper install ./defile-0.6.12-x86_64.rpm
```

Requires: `gtk3`, `mpv-libs`, `libepoxy`.

### Arch Linux (AUR)

```bash
yay -S defile-bin
# or: paru -S defile-bin
```

The `defile-bin` recipe lives in [`packaging/aur/defile-bin/PKGBUILD`](packaging/aur/defile-bin/PKGBUILD)
and repackages the official release AppImage (see
[`packaging/aur/README.md`](packaging/aur/README.md) for publishing notes).

### AppImage (any distro)

The installer falls back to the AppImage when no system package applies.
It installs to `~/.local/opt/defile`, links `~/.local/bin/defile`, and
registers the launcher entry. Requires `curl`, `mpv` (libmpv), and FUSE
(`libfuse2` on Debian/Ubuntu, `fuse2` on Arch).

```bash
sudo pacman -S curl mpv fuse2
```

## Packaging from source

```bash
make build          # AppImage (needs flutter + rust)
make deb            # .deb from the Flutter bundle
make rpm            # .rpm from the Flutter bundle
make packages       # AppImage + .deb + .rpm (reuses the bundle)
```

CI (`.github/workflows/linux-appimage.yml`) builds all three artifacts on
every push for `x86_64` and `aarch64`; pushing a tag (e.g. `v0.6.12`)
publishes them to the GitHub release.
