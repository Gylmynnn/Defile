# defile-bin — AUR publishing

This repo ships the AUR recipe at `packaging/aur/defile-bin/PKGBUILD`.
The AUR itself lives outside GitHub (`https://aur.archlinux.org/packages/defile-bin`),
so publishing is a one-time manual step plus a per-release bump.

## First-time publish

```bash
git clone ssh://aur@aur.archlinux.org/defile-bin.git
cp packaging/aur/defile-bin/PKGBUILD defile-bin/
cd defile-bin
updpkgsums
makepkg --printsrcinfo > .SRCINFO
makepkg -si   # test install locally
git add PKGBUILD .SRCINFO
git commit -m "Initial import $VERSION"
git push
```

## New upstream release

1. Bump `pkgver` in `packaging/aur/defile-bin/PKGBUILD` (no leading `v`).
2. Regenerate checksums and metadata:
   ```bash
   cd packaging/aur/defile-bin
   updpkgsums
   makepkg --printsrcinfo > .SRCINFO
   ```
3. Push the same two files to the AUR repo.

## Notes

- `defile-bin` repackages the official release AppImage and installs the
  extracted Flutter bundle to `/opt/defile`, so it runs without FUSE.
- Runtime deps: `gtk3 mpv libepoxy hicolor-icon-theme`.
- Keep `pkgver` in sync with the GitHub release tag (`v<version>`).
