#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Mateus Rocha de Paula and the OxiGuitar contributors
# Copyright (C) 2026 the FuTab contributors
#
# Installs FuTab and plugins from the Flatpak repository SITE/flatpak
# (scripts/flatpak-repo.sh) the way a user would, for this user only, and
# checks them in the sandbox:
#
#   - futab.flatpakrepo adds the repository and lists the app;
#   - the app from io.github.purpleicon.FuTab.flatpakref, which adds the
#     repository as `futab` (signatures checked with the key it carries) and
#     Flathub, its RuntimeRepo, for the runtime;
#   - each PLUGIN, REMOTE:ID, installed from REMOTE, whose .oxp files must
#     appear in the app's plugin folder for its extension point:
#       futab:io.github.purpleicon.FuTab.Plugin.NAME      /app/lib/futab/plugins
#       oxiguitar:io.github.mateusrdp.OxiGuitar.Plugin.NAME
#                                                       /app/lib/oxiguitar/plugins
#     The remote `oxiguitar` is OxiGuitar's own repository, added from its
#     published .flatpakrepo, as a FuTab user adds it for OxiGuitar's plugins;
#   - with SAMPLE, a score file, `futab-cli detect` must find a plugin that
#     reads it, in the sandbox.
#
# The FuTab files' Url is the published site's; here it is replaced by SITE's
# own folder. Needs flatpak and bubblewrap working (on Ubuntu 24.04 runners:
# sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0) and
# dbus-run-session. Changes this user's Flatpak installation: for CI.
#
# Based on oxiguitar-packages' scripts/test-flatpak.sh
# (mateusrdp/oxiguitar-packages@070d367).
#
# Usage: scripts/test-flatpak.sh SITE SAMPLE|- [REMOTE:ID...]
set -euo pipefail
trap 'echo "::error::test-flatpak.sh line $LINENO: $BASH_COMMAND"' ERR

site="$(cd "${1:?usage: test-flatpak.sh SITE SAMPLE|- [REMOTE:ID...]}" && pwd)"
sample="${2:?}"
shift 2
app=io.github.purpleicon.FuTab
oxiguitar_repo=https://mateusrdp.github.io/oxiguitar-packages/flatpak/oxiguitar.flatpakrepo
dir="$site/flatpak"
local_url="file://$dir/repo/"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

[[ -f "$dir/$app.flatpakref" ]] || { echo "test-flatpak.sh: no $app.flatpakref in $dir" >&2; exit 1; }
sed "s|^Url=.*|Url=$local_url|" "$dir/$app.flatpakref" > "$tmp/$app.flatpakref"
sed "s|^Url=.*|Url=$local_url|" "$dir/futab.flatpakrepo" > "$tmp/futab.flatpakrepo"
grep -qx "RuntimeRepo=https://dl.flathub.org/repo/flathub.flatpakrepo" "$tmp/$app.flatpakref"

echo "== The repository file"
flatpak --user remote-add --if-not-exists --from futab-check "$tmp/futab.flatpakrepo"
flatpak --user remote-ls --all futab-check | tee "$tmp/listed.txt"
grep -q "$app" "$tmp/listed.txt"
flatpak --user remote-delete futab-check

echo "== The app, from its .flatpakref"
flatpak --user install -y --noninteractive --from "$tmp/$app.flatpakref"
flatpak --user remotes -d
flatpak --user remotes --columns=name,url | grep -E "^futab\s+$local_url" > /dev/null \
    || { echo "::error::the .flatpakref didn't add the remote futab"; exit 1; }
flatpak --user remotes --columns=name | grep -qx flathub \
    || { echo "::error::the .flatpakref's RuntimeRepo didn't add Flathub"; exit 1; }
flatpak --user info "$app"

run() { dbus-run-session -- flatpak run "$@"; }
for spec in "$@"; do
    remote="${spec%%:*}"
    id="${spec#*:}"
    case "$id" in
        "$app.Plugin."*) folder=/app/lib/futab/plugins ;;
        io.github.mateusrdp.OxiGuitar.Plugin.*) folder=/app/lib/oxiguitar/plugins ;;
        *) echo "test-flatpak.sh: $id is no plugin extension FuTab knows" >&2; exit 2 ;;
    esac
    if [[ "$remote" == oxiguitar ]]; then
        flatpak --user remote-add --if-not-exists --from oxiguitar "$oxiguitar_repo"
    fi
    echo "== Plugin $id, from $remote"
    flatpak --user install -y --noninteractive "$remote" "$id"
    flatpak --user info "$id"
    # Its files, linked into the app's plugin folder for its extension point.
    files="$(flatpak --user info --show-location "$id")/files/plugins"
    for f in "$files"/*.oxp; do
        run --command=test "$app" -s "$folder/$(basename "$f")" \
            || { echo "::error::$(basename "$f") isn't in $folder"; exit 1; }
    done
done
run --command=sh "$app" -c 'ls -l /app/lib/futab/plugins /app/lib/oxiguitar/plugins 2> /dev/null || true'

if [[ "$sample" != - ]]; then
    echo "== Opening $(basename "$sample") in the sandbox"
    sample="$(cd "$(dirname "$sample")" && pwd)/$(basename "$sample")"
    out="$(run --filesystem="$(dirname "$sample"):ro" --command=futab-cli "$app" detect "$sample")"
    echo "$out"
    grep -q 'read by' <<< "$out" || { echo "::error::no plugin read $(basename "$sample")"; exit 1; }
fi
echo "Installed from the repository and checked: $app $*"
