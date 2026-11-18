# Changelog

All notable changes to futab-packages are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **The repository**: README, licence, code owners, and a `.gitignore` that keeps signing keys out.
- **The Site workflow** and its scripts, based on OxiGuitar's oxiguitar-packages: on each published FuTab release, the `.deb`, `.rpm` and Flatpak files are fetched and checked, signed into apt, dnf and Flatpak repositories, test-installed, and served on GitHub Pages. Not live until the signing key is set.
- **CI**: shellcheck, the sign-off check, and a whole site built from made-up packages with a throwaway key, then installed from with apt and dnf.
