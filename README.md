<p align="center">
  <img src="Ado-logo.png" alt="AdoOS" width="200">
</p>

<h1 align="center">AdoOS</h1>

<p align="center">
  <em>Alpine-based Linux distribution. Same musl, same OpenRC, same package format — with its own identity.</em>
</p>

<p align="center">
  <a href="https://alpinelinux.org/">
    <img alt="Base: Alpine 3.24.1" src="https://img.shields.io/badge/base-Alpine_3.24.1-0D597F?style=flat-square&logo=alpinelinux&logoColor=white">
  </a>
  <img alt="libc: musl" src="https://img.shields.io/badge/libc-musl-2D6A8F?style=flat-square">
  <img alt="init: OpenRC" src="https://img.shields.io/badge/init-OpenRC-4A7BA7?style=flat-square">
  <img alt="arch: x86_64" src="https://img.shields.io/badge/arch-x86__64-555555?style=flat-square&logo=linux&logoColor=white">
  <img alt="Reproducible builds" src="https://img.shields.io/badge/reproducible_builds-2EA44F?style=flat-square&logo=git&logoColor=white">
</p>

<br>

AdoOS is an Alpine-based Linux distribution: same musl, same OpenRC, same
package format — with its own ISO branding, its own package repository, and
documented answers for the things musl does not do (glibc-only software,
non-Latin locales).

What this is and is not is written down in [`docs/SCOPE.md`](docs/SCOPE.md).
Read that before assuming a feature exists.

Base: Alpine 3.24.1. Nothing in `aports/` is patched — every AdoOS change is a
profile, an overlay file, or a package.

## Layout

```
AdoOS/
  alpine-standard-3.24.1-x86_64.iso   reference ISO (upstream Alpine)
  aports/                             Alpine recipes, unmodified checkout
  apk-tools/                          apk source, unmodified checkout
  docs/                               scope, decisions, architecture notes
  overlay/                            filesystem overlay baked into the ISO
  iso/                                ISO profile + output
  scripts/                            build scripts
```

`aports/` and `apk-tools/` are upstream checkouts with their own git history;
they are git-ignored here and are not modified by any script in `scripts/`.

## Building the ISO

```sh
scripts/build-iso.sh          # -> iso/adoos-3.24.1-x86_64.iso (+ .sha256/.sha512)
```

No root needed. The script bootstraps an Alpine minirootfs into `.builder/`
and re-execs itself inside it via `unshare -Ur` (see
`scripts/alpine-chroot.sh`). The ISO is built by Alpine's own `mkimage.sh`, with
`iso/mkimg.adoos.sh` as the profile and `iso/genapkovl-adoos.sh` generating the
live overlay from `overlay/`.

Timestamps are pinned to `git log -1` of this repo via `SOURCE_DATE_EPOCH`, so
two builds of the same commit produce the same image.

To poke around the builder: `scripts/alpine-chroot.sh` opens a shell with the
repo bind-mounted at `/adoos`.

## Building apk-tools

```sh
cd apk-tools
meson setup -Dprefix=/usr build && ninja -C build
./build/src/apk --version
```

Requires meson, ninja and the usual dev libs; on a non-Alpine host
`uv tool install meson ninja` is enough. The apk test suite is
`meson test -C build` — it expects `$APK` to point at the built binary, which
the meson build sets up.
