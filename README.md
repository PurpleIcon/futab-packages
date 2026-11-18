# futab-packages

Signed apt, dnf and Flatpak repositories for FuTab and its plugins.

Part of [FuTab](https://github.com/PurpleIcon/futab), a guitar tablature and
score viewer, editor and player written in Rust, forked from
[OxiGuitar](https://github.com/mateusrdp/oxiguitar). This repository holds
scripts and workflows only: the packages themselves come from FuTab's
published GitHub releases, and the repositories are served from
<https://purpleicon.github.io/futab-packages>.

**Not built yet.** The plan is FuTab's design note
[`docs/futab-design/package-repositories.md`](https://github.com/PurpleIcon/futab/blob/develop/docs/futab-design/package-repositories.md).
Until the first site build, install FuTab from the files on its
[releases page](https://github.com/PurpleIcon/futab/releases), as its README
explains.

## How it works

When a FuTab release (or a FuTab plugin's) is published, its Publish workflow
tells this repository. The Site workflow then downloads the latest published
release of each repository in `repositories.txt`, checks every file against
the release's `SHA256SUMS`, builds the apt, dnf and Flatpak repositories,
signs them, test-installs from them, and deploys them to GitHub Pages.

FuTab's plugins from OxiGuitar (Guitar Pro, MIDI, ALSA, PipeWire and the
others) stay in [OxiGuitar's repositories](https://github.com/mateusrdp/oxiguitar-packages);
add those as well.

## Credits

The scripts and workflows are based on OxiGuitar's
[oxiguitar-packages](https://github.com/mateusrdp/oxiguitar-packages)
(GPL-3.0-or-later), by the OxiGuitar authors.

## Licence

GPL-3.0-or-later; see [LICENSE](LICENSE).
