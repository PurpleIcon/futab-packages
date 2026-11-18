#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Mateus Rocha de Paula and the OxiGuitar contributors
# Copyright (C) 2026 the FuTab contributors
#
# Makes small made-up packages, so CI can build the site and install from it
# without any release existing:
#
#   - futab-test, a made-up plugin: .deb for amd64 and arm64, .rpm for this
#     machine's processor, holding /usr/lib/futab/plugins/test.oxp;
#   - futab-testall, the same on every architecture (Architecture: all,
#     noarch), holding /usr/share/futab-testall/hello;
#   - io.github.purpleicon.FuTab.Plugin.test, the made-up plugin's Flatpak
#     extension for this machine's processor, attaching to FuTab's own
#     extension point (FuTab's docs/futab-design/package-repositories.md).
#
# Needs dpkg-deb, rpmbuild and flatpak (no SDK, no sandbox: files are only
# copied). Based on oxiguitar-packages' scripts/make-test-packages.sh and
# scripts/plugin-package/flatpak.sh (mateusrdp/oxiguitar-packages@070d367),
# without its packaging scripts.
#
# Usage: scripts/make-test-packages.sh OUT-DIR
set -euo pipefail
trap 'echo "::error::make-test-packages.sh line $LINENO: $BASH_COMMAND"' ERR

out="${1:?usage: make-test-packages.sh OUT-DIR}"
mkdir -p "$out/deb" "$out/rpm" "$out/flatpak"
out="$(cd "$out" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
version=0.0.1
head -c 4096 /dev/urandom > "$work/test.oxp"

# deb NAME ARCH FILE DEST: a .deb holding FILE at DEST.
deb() {
    local tree="$work/deb-$1-$2"
    mkdir -p "$tree/DEBIAN" "$tree$(dirname "$4")"
    install -m644 "$3" "$tree$4"
    printf 'Package: %s\nVersion: %s\nSection: sound\nPriority: optional\nArchitecture: %s\nMaintainer: Test <test@example.invalid>\nDescription: A made-up package\n It tests futab-packages.\n' \
        "$1" "$version" "$2" > "$tree/DEBIAN/control"
    dpkg-deb --root-owner-group -Zxz --build "$tree" "$out/deb/${1}_${version}_$2.deb" > /dev/null
}

# rpm NAME ARCH FILE DEST: an .rpm holding FILE at DEST. rpmbuild builds for
# the machine's own processor, or noarch.
rpm_() {
    local top="$work/rpm-$1"
    mkdir -p "$top"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    cat > "$top/SPECS/$1.spec" << SPEC
Name: $1
Version: $version
Release: 1
Summary: A made-up package
License: GPL-3.0-or-later
BuildArch: $2
%description
It tests futab-packages.
%global debug_package %{nil}
%install
install -D -m644 $3 %{buildroot}$4
%files
$4
SPEC
    rpmbuild -bb --target "$2" --define "_topdir $top" --define "_rpmdir $out/rpm" \
        --define "_build_name_fmt %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" \
        "$top/SPECS/$1.spec" > /dev/null
}

for arch in amd64 arm64; do
    deb futab-test "$arch" "$work/test.oxp" /usr/lib/futab/plugins/test.oxp
done
rpm_ futab-test "$(uname -m)" "$work/test.oxp" /usr/lib/futab/plugins/test.oxp

echo hello > "$work/hello"
deb futab-testall all "$work/hello" /usr/share/futab-testall/hello
rpm_ futab-testall noarch "$work/hello" /usr/share/futab-testall/hello

# The Flatpak extension: an extension of the app's stable branch, mounted at
# /app/lib/futab/test, its plugins/ folder merged into /app/lib/futab/plugins.
arch="$(flatpak --default-arch)"
id=io.github.purpleicon.FuTab.Plugin.test
build="$work/flatpak"
mkdir -p "$build/files/plugins"
install -m644 "$work/test.oxp" "$build/files/plugins/test.oxp"
cat > "$build/metadata" << METADATA
[Runtime]
name=$id

[ExtensionOf]
ref=app/io.github.purpleicon.FuTab/$arch/stable
METADATA
flatpak build-export --runtime --files=files --arch="$arch" \
    --subject="test $version" "$work/flatpak-repo" "$build" stable > /dev/null
flatpak build-bundle --runtime --arch="$arch" "$work/flatpak-repo" \
    "$out/flatpak/futab-test-$version-$arch.flatpak" "$id" stable

ls "$out/deb" "$out/rpm" "$out/flatpak"
