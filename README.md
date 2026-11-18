# futab-packages

Signed apt, dnf and Flatpak repositories for FuTab and its plugins.

Part of [FuTab](https://github.com/PurpleIcon/futab), a guitar tablature and
score viewer, editor and player written in Rust, forked from
[OxiGuitar](https://github.com/mateusrdp/oxiguitar). This repository holds
scripts and workflows only: the packages come from the published GitHub
releases of the repositories in [`repositories.txt`](repositories.txt), and
the repositories are served from <https://purpleicon.github.io/futab-packages>.
The plan behind it is FuTab's design note
[`docs/futab-design/package-repositories.md`](https://github.com/PurpleIcon/futab/blob/develop/docs/futab-design/package-repositories.md).

**Not live yet.** Until the first site build, install FuTab from the files on
its [releases page](https://github.com/PurpleIcon/futab/releases), as its
README explains.

## Using the repositories

The site's page repeats this, with the key's fingerprint. FuTab's plugins
from OxiGuitar (Guitar Pro, MIDI, ALSA, PipeWire and the others) are in
[OxiGuitar's repositories](https://github.com/mateusrdp/oxiguitar-packages),
so add both. Never install the `oxiguitar` app itself beside FuTab.

Debian, Ubuntu and relatives:

```sh
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL https://purpleicon.github.io/futab-packages/futab.gpg -o /etc/apt/keyrings/futab.gpg
sudo curl -fsSL https://purpleicon.github.io/futab-packages/futab.sources -o /etc/apt/sources.list.d/futab.sources
sudo curl -fsSL https://mateusrdp.github.io/oxiguitar-packages/oxiguitar.gpg -o /etc/apt/keyrings/oxiguitar.gpg
sudo curl -fsSL https://mateusrdp.github.io/oxiguitar-packages/oxiguitar.sources -o /etc/apt/sources.list.d/oxiguitar.sources
sudo apt update
sudo apt install futab
```

Fedora and relatives:

```sh
sudo curl -fsSL https://purpleicon.github.io/futab-packages/futab.repo -o /etc/yum.repos.d/futab.repo
sudo curl -fsSL https://mateusrdp.github.io/oxiguitar-packages/oxiguitar.repo -o /etc/yum.repos.d/oxiguitar.repo
sudo dnf install futab
```

`futab` recommends the Guitar Pro, MIDI, ALSA and PipeWire plugins, which apt
and dnf install with it from OxiGuitar's repository.

Any Linux, as Flatpaks (the runtime comes from Flathub):

```sh
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --if-not-exists futab https://purpleicon.github.io/futab-packages/flatpak/futab.flatpakrepo
flatpak remote-add --if-not-exists oxiguitar https://mateusrdp.github.io/oxiguitar-packages/flatpak/oxiguitar.flatpakrepo
flatpak install futab io.github.purpleicon.FuTab
flatpak install oxiguitar io.github.mateusrdp.OxiGuitar.Plugin.guitarpro io.github.mateusrdp.OxiGuitar.Plugin.midi io.github.mateusrdp.OxiGuitar.Plugin.pipewire
```

## How it works

1. A FuTab release (or a FuTab plugin's) is published. Its Publish workflow
   checks the files and sends the `plugin-published` event here, with the
   secret `PACKAGES_TOKEN`.
2. The **Site** workflow ([`site.yml`](.github/workflows/site.yml)) runs on
   `main`:
   - [`fetch-packages.sh`](scripts/fetch-packages.sh) downloads the `.deb`,
     `.rpm` and `.flatpak` files of the latest published release (never a
     draft or pre-release) of each repository in `repositories.txt`, and
     checks them against the release's `SHA256SUMS`;
   - [`build-site.sh`](scripts/build-site.sh) builds the apt repository
     (`apt-ftparchive`, signed `InRelease` and `Release.gpg`), the dnf
     repository (`rpmsign`, `createrepo_c`, signed `repomd.xml`) and, with
     [`flatpak-repo.sh`](scripts/flatpak-repo.sh), the Flatpak repository
     (OSTree, signed commits and summary), from scratch each time;
   - [`test-install.sh`](scripts/test-install.sh) installs `futab` from it
     with apt (Debian) and dnf (Fedora), signatures checked, and
     [`test-flatpak.sh`](scripts/test-flatpak.sh) installs the Flatpak with
     OxiGuitar's Guitar Pro plugin and opens a sample score in the sandbox;
   - the site is deployed to Pages.
3. Users get the new version on their next `apt upgrade`, `dnf upgrade` or
   `flatpak update`. Only the latest release is served; older ones stay on
   the GitHub releases.

The Site workflow can also be started by hand (Actions -> Site -> Run
workflow, on `main`), for the first build and after the key changes.

CI ([`ci.yml`](.github/workflows/ci.yml)) checks every pull request:
shellcheck, the sign-off check, and a whole site built from made-up packages
([`make-test-packages.sh`](scripts/make-test-packages.sh)) with a throwaway
key, then installed from with apt and dnf.

## The signing key

One key signs all three repositories: RSA 4096, signing only, no expiry,
with a passphrase. Its user ID is
`FuTab packages (https://github.com/PurpleIcon/futab-packages)`.

- **Fingerprint:** not made yet.
- The public key is on the site, as `futab.asc` and `futab.gpg`.
- The private key is in the secrets `APT_SIGNING_KEY` (armoured) and
  `APT_SIGNING_PASSPHRASE` of the environment `signing`, which only `main`
  may use, and in the maintainer's offline backup, with its revocation
  certificate. It is never committed: `.gitignore` refuses key files.
- If it ever leaks: the revocation is published, a new key replaces it in
  the secrets, the site is rebuilt, and FuTab's README and release notes tell
  users to fetch the new key.

## Adding a FuTab plugin

Add its repository to `repositories.txt`, and give that repository the
`PACKAGES_TOKEN` secret (a fine-grained token, owner PurpleIcon, Contents:
read and write on this repository only). Its Flatpak extension is
`io.github.purpleicon.FuTab.Plugin.NAME`, attaching to FuTab's own extension
point.

## Contributing

Every change goes through a pull request into `main` (the only branch), with
the code owner's approval, signed off (`git commit -s`), and with an entry in
[`CHANGELOG.md`](CHANGELOG.md). Pull requests are squash-merged.

## Credits

The scripts and workflows are based on OxiGuitar's
[oxiguitar-packages](https://github.com/mateusrdp/oxiguitar-packages)
(mateusrdp/oxiguitar-packages@070d367, GPL-3.0-or-later), by Mateus Rocha de
Paula and the OxiGuitar contributors; each file names the one it comes from.

## Licence

GPL-3.0-or-later; see [LICENSE](LICENSE).
