<div align="center">

<img src="Ado-logo.png" alt="AdoOS" width="200">

# AdoOS

**An Alpine derivative where every change is a profile, an overlay file, or a package — never a patched recipe.**

<p align="center">
  <a href="https://alpinelinux.org/"><img alt="Base: Alpine 3.24.1" src="https://img.shields.io/badge/Base-Alpine_3.24.1-0D597F?style=for-the-badge&labelColor=1F2937&logo=alpinelinux&logoColor=white"></a>
  <img alt="libc: musl" src="https://img.shields.io/badge/libc-musl-1B6E8C?style=for-the-badge&labelColor=1F2937">
  <img alt="init: OpenRC" src="https://img.shields.io/badge/init-OpenRC-2F80A8?style=for-the-badge&labelColor=1F2937">
  <img alt="arch: x86_64" src="https://img.shields.io/badge/Arch-x86__64-3B8FB8?style=for-the-badge&labelColor=1F2937&logo=linux&logoColor=white">
  <img alt="Builder: rootless" src="https://img.shields.io/badge/Builder-rootless-2EA44F?style=for-the-badge&labelColor=1F2937&logo=git&logoColor=white">
</p>

</div>

---

## What this is

An Alpine 3.24.1 base with its own ISO: branding, a live overlay, a rootless
build path, and a rebranded `apk` that lives on a separate branch. Nothing in
`aports/` is patched, so an Alpine package that runs on Alpine runs here.

What AdoOS deliberately does not do — a glibc compatibility layer beyond
`gcompat`, proprietary NVIDIA, a binary repository — is argued line by line in
[`docs/SCOPE.md`](docs/SCOPE.md). Read that before assuming a feature exists.

## Design

One rule drives the build: AdoOS adds layers, it does not fork the base.

| Surface | Mechanism |
|---|---|
| Base system | Upstream Alpine; no recipe modified |
| Branding | Files in `overlay/`, shipped as an apkovl tarball that wins over the packages owning the same paths |
| ISO profile | `iso/mkimg.adoos.sh`, loaded through `$HOME/.mkimage/` (`mkimage.sh:204`) — `aports/` stays untouched |
| Live overlay | `iso/genapkovl-adoos.sh` packs `overlay/` plus hostname and `apk/world` |
| Volume ID | `gen_volid()` in the profile — one source, since GRUB's `search --label` depends on it |
| Reproducibility | `SOURCE_DATE_EPOCH` pinned to `git log -1` of this repo |
| Rootless build | `unshare -Ur` gives fake root; the Alpine minirootfs is the builder, its checksum verified against the mirror before extraction |
| Console | `console=tty0 console=ttyS0,115200`, with a serial getty in `overlay/etc/inittab` so `qemu -nographic` reaches a shell |

### What it does not provide

- **No glibc runtime.** `gcompat` covers the C library sonames only; `libstdc++`,
  NSS and gconv stay out (see SCOPE). Flatpak and distrobox are the supported
  answers for glibc binaries, and neither is wired into the ISO yet.
- **No package repository.** AdoOS builds no packages of its own.
- **No installer.** The ISO is a live system.
- **No license file.** Absent one, the repo is all rights reserved by default.

## Build

```sh
scripts/build-iso.sh     # -> iso/adoos-3.24.1-x86_64.iso (+ .sha256/.sha512)
```

No root. `scripts/alpine-chroot.sh` fetches the Alpine minirootfs into
`.builder/`, verifies it against the SHA-256 the mirror publishes, re-execs the
build inside it via `unshare -Ur`, then runs Alpine's own `mkimage.sh` with
`--checksum`. Overrides: `ALPINE_VER`, `ARCH`, `ADOOS_MIRROR`,
`SOURCE_DATE_EPOCH`, and `ADOOS_LITE=1` to drop firmware from the modloop.

To inspect the builder: `scripts/alpine-chroot.sh` opens a shell with the repo
bind-mounted at `/adoos`.

### Layout

```
AdoOS/
  alpine-standard-3.24.1-x86_64.iso   reference ISO (upstream Alpine, git-ignored)
  docs/                               scope, decisions, architecture notes
  iso/                                ISO profile, apkovl generator, build output
  overlay/                            files baked into the live system
  scripts/                            rootless builder and build entry point
  aports/                             upstream checkout, unmodified (git-ignored)
  apk-tools/                          apk source with the rebrand branch (git-ignored)
```

Both upstream checkouts carry their own git history and are ignored here; no
script in `scripts/` writes to either.

## apk rebrand (`abo`)

`apk-tools` on branch `adoos` differs from upstream `844009a` in 133 files
(+623/−611). The executable is named `abo`, which is why the paths below say
`abo` and not `apk`.

```sh
cd apk-tools
meson setup -Dprefix=/usr build && ninja -C build
./build/src/abo --version        # AdoOS abo 3.0.6, compiled for x86_64.
```

Requires meson, ninja and the usual dev libs; on a non-Alpine host
`uv tool install meson ninja` is enough. `meson test -C build` runs the upstream
suite — it reads `$APK`, which the build points at the `abo` binary
(`test/meson.build:10`).

The branch is not part of this repository. SCOPE rule 2 keeps the option of
shipping the rebrand as a patch series at package build time instead.

## Status

The ISO has **not been built and booted** from this tree. Every claim above
describes the scripts, not a working image.

| Area | State |
|---|---|
| ISO profile, overlay, branding | Builds through `scripts/build-iso.sh`; no root required |
| Rootless builder | Works on this host (`unshare -Ur`); minirootfs checksum-verified |
| Serial console | getty on `ttyS0` shipped in the overlay |
| `apk-tools` rebrand | Local branch; builds and passes the upstream suite |
| Package repository | Not started |
| Flatpak / distrobox path | Present in Alpine `community`; not wired into the ISO |
| glibc prefix package | Not started |
| Localization | `musl-locales` in the package list; no fonts or input methods |
| NVIDIA | Open stack (nouveau/NVK) only; proprietary and CUDA unsupported, no plan |
| Boot test | Not run on a built AdoOS ISO |

### Known gaps

- **`ADOOS_LITE=1` does not skip the firmware download.** The profile overrides
  `section_kernels`, but `update-kernel` pulls `linux-firmware` itself (757 MB,
  113 subpackages), so the flag changes modloop contents, not build time.
  Closing it needs an empty higher-version stub package.
- **The volume ID truncates at 32 characters.** A long `RELEASE` value loses the
  architecture suffix.
- **No LICENSE file.** Pick one before anyone else builds on this.

## Roadmap

- [ ] Build and boot an ISO; record its SHA-256 here
- [ ] Wire Flatpak or distrobox into the live image and document the path
- [ ] Empty `linux-firmware` stub so `ADOOS_LITE=1` is fast, not just smaller
- [ ] Decide whether the `abo` rebrand ships as a patch series (SCOPE rule 2)
- [ ] Add a LICENSE
