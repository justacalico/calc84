#!/usr/bin/env bash
# Package a built Flutter Linux bundle as a .deb for Debian/Ubuntu.
# Installs to /opt/calc84 with a /usr/bin/calc84 symlink, a desktop entry and
# an icon.
#
# Usage: scripts/build-deb.sh <bundle-dir> <version> <deb-arch> <output-file>
#   deb-arch: amd64 or arm64
set -euo pipefail

BUNDLE_DIR="${1:?usage: build-deb.sh <bundle-dir> <version> <deb-arch> <output-file>}"
VERSION="${2:?usage: build-deb.sh <bundle-dir> <version> <deb-arch> <output-file>}"
ARCH="${3:?usage: build-deb.sh <bundle-dir> <version> <deb-arch> <output-file>}"
OUT="${4:?usage: build-deb.sh <bundle-dir> <version> <deb-arch> <output-file>}"

if ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "build-deb: dpkg-deb not found (install the dpkg-dev package)" >&2
  exit 1
fi
if [ ! -d "$BUNDLE_DIR" ]; then
  echo "build-deb: bundle dir not found: $BUNDLE_DIR" >&2
  exit 1
fi
if [ "$ARCH" != "amd64" ] && [ "$ARCH" != "arm64" ]; then
  echo "build-deb: unsupported arch: $ARCH" >&2
  exit 1
fi

PKGDIR="$(mktemp -d)"
trap 'rm -rf "$PKGDIR"' EXIT
mkdir -p "$PKGDIR/opt/calc84" "$PKGDIR/usr/bin" "$PKGDIR/DEBIAN" \
  "$PKGDIR/usr/share/applications" \
  "$PKGDIR/usr/share/icons/hicolor/256x256/apps"

cp -r "$BUNDLE_DIR/." "$PKGDIR/opt/calc84/"
ln -sf /opt/calc84/calc84 "$PKGDIR/usr/bin/calc84"
install -m 644 "$BUNDLE_DIR/data/flutter_assets/assets/icon/app_icon.png" \
  "$PKGDIR/usr/share/icons/hicolor/256x256/apps/calc84.png"

cat > "$PKGDIR/usr/share/applications/calc84.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=CALC-84
Comment=Skeuomorphic graphing calculator
Exec=/usr/bin/calc84
Icon=calc84
Categories=Utility;Science;Math;
Terminal=false
EOF

cat > "$PKGDIR/DEBIAN/control" <<EOF
Package: calc84
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: HttpAnimations <noreply@gitlab.com>
Description: Skeuomorphic graphing calculator
 A graphing calculator built with Flutter that reproduces the feel of a
 classic physical handheld.
EOF

dpkg-deb --build "$PKGDIR" "$OUT" >/dev/null
echo "build-deb: $OUT"
