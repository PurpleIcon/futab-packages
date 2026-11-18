#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Mateus Rocha de Paula and the OxiGuitar contributors
# Copyright (C) 2026 the FuTab contributors
#
# Builds FuTab's Flatpak repository from the single-file bundles in BUNDLES:
# FuTab's (FuTab-VERSION-ARCH.flatpak, from FuTab's releases) and, as they
# come, its plugins' extensions (io.github.purpleicon.FuTab.Plugin.NAME).
# Writes, in OUT:
#
#   repo/                               the OSTree repository, its commits
#                                       and summary signed
#   futab.flatpakrepo                   adds the repository
#   io.github.purpleicon.FuTab.flatpakref
#                                       installs the app, adding the
#                                       repository and, for the runtime,
#                                       Flathub
#
# build-import-bundle keeps each bundle's commit as it is, so the same
# releases give the same commits: the repository is made from scratch each
# time and clients see an update only when a release changed. The runtime is
# not in it: it comes from Flathub.
#
# Based on oxiguitar-packages' scripts/flatpak-repo.sh
# (mateusrdp/oxiguitar-packages@070d367).
#
# Usage: scripts/flatpak-repo.sh BUNDLES OUT
# Environment:
#   GPG_KEY_ID           the signing key, in the keyring GNUPGHOME points at
#   GPG_PASSPHRASE_FILE  its passphrase, if it has one (default: none)
#   SITE_URL             where the site is served (default
#                        https://purpleicon.github.io/futab-packages)
set -euo pipefail
trap 'echo "::error::flatpak-repo.sh line $LINENO: $BASH_COMMAND"' ERR

bundles="$(cd "${1:?usage: flatpak-repo.sh BUNDLES OUT}" && pwd)"
out="${2:?}"
key="${GPG_KEY_ID:?GPG_KEY_ID is required}"
homedir="${GNUPGHOME:-$HOME/.gnupg}"
url="${SITE_URL:-https://purpleicon.github.io/futab-packages}"
app=io.github.purpleicon.FuTab
branch=stable
homepage=https://github.com/PurpleIcon/futab
flathub=https://dl.flathub.org/repo/flathub.flatpakrepo

shopt -s nullglob
files=("$bundles"/*.flatpak)
[[ ${#files[@]} -gt 0 ]] || { echo "flatpak-repo.sh: no bundle in $bundles" >&2; exit 1; }

# Flatpak signs through gpg-agent, which can't ask for a passphrase here:
# it is given to the agent beforehand.
if [[ -n "${GPG_PASSPHRASE_FILE:-}" ]]; then
    echo allow-preset-passphrase >> "$homedir/gpg-agent.conf"
    gpgconf --homedir "$homedir" --kill gpg-agent
    preset="$(gpgconf --list-dirs libexecdir)/gpg-preset-passphrase"
    gpg --homedir "$homedir" --with-colons --with-keygrip --list-secret-keys "$key" \
        | awk -F: '$1 == "grp" { print $10 }' \
        | while read -r grip; do
            "$preset" --homedir "$homedir" --preset "$grip" < "$GPG_PASSPHRASE_FILE"
        done
fi
sign=(--gpg-sign="$key" --gpg-homedir="$homedir")

rm -rf "$out"
mkdir -p "$out"
repo="$out/repo"
ostree --repo="$repo" init --mode=archive-z2
for bundle in "${files[@]}"; do
    echo "Importing $(basename "$bundle")"
    # (Flatpak 1.14 prints GLib warnings about the bundle's missing origin
    # remote; they are harmless.)
    flatpak build-import-bundle --no-update-summary "${sign[@]}" "$repo" "$bundle" 2>&1 \
        | grep -v -e 'CRITICAL' -e '^$' || true
done
flatpak build-update-repo "${sign[@]}" \
    --title=FuTab --comment="FuTab and its plugins" \
    --homepage="$homepage" --default-branch="$branch" \
    "$repo"

refs="$(ostree --repo="$repo" refs | grep -E '^(app|runtime)/' | sort)"
[[ -n "$refs" ]] || { echo "flatpak-repo.sh: the repository holds nothing" >&2; exit 1; }
gpgkey="$(gpg --homedir "$homedir" --export "$key" | base64 -w 0)"

cat > "$out/futab.flatpakrepo" << REPO
[Flatpak Repo]
Title=FuTab
Url=$url/flatpak/repo/
Homepage=$homepage
Comment=FuTab and its plugins
Description=FuTab, a guitar tablature viewer, editor and player, and its plugins. The runtime comes from Flathub.
GPGKey=$gpgkey
REPO

if grep -q "^app/$app/" <<< "$refs"; then
    cat > "$out/$app.flatpakref" << REF
[Flatpak Ref]
Title=FuTab
Name=$app
Branch=$branch
Url=$url/flatpak/repo/
SuggestRemoteName=futab
Homepage=$homepage
IsRuntime=false
RuntimeRepo=$flathub
GPGKey=$gpgkey
REF
else
    echo "::notice::No FuTab bundle among the releases: no $app.flatpakref."
fi

echo "Refs in the Flatpak repository:"
while IFS= read -r ref; do echo "  $ref"; done <<< "$refs"
echo "Size: $(du -sh "$repo" | cut -f1)"
