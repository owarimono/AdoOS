# AdoOS — scope

What AdoOS is, what it deliberately is not, and where each promise stands.
If something is not in this file, assume it does not exist yet.

## Identity

AdoOS is an **Alpine derivative**. It keeps Alpine's foundations untouched:

- musl libc, OpenRC, apk package format, Alpine kernel (`linux-lts`)
- base: Alpine 3.24.1
- `aports/` is an unmodified upstream checkout; no recipe is patched

Everything AdoOS adds lives above that line: an ISO profile, overlay files, and
own packages. An Alpine package that runs on Alpine runs on AdoOS, and vice
versa. If a change cannot be expressed that way, it is not in scope yet.

## Goals, and the honest answer to each

### 1. "A stable, transparent glibc compatibility layer, beyond gcompat"

**This is the goal that has to be shrunk, and the reason is gcompat's shape.**

`main/gcompat` (v1.1.0, from Adélie) works by symlinking the sonames
`libc.so.6 libcrypt.so.1 libm.so.6 libpthread.so.0 libresolv.so.2 librt.so.1
libutil.so.1` to `libgcompat.so.0`. That is a shim for the C library surface.
It does *not* provide:

- `libstdc++` / `libgcc_s` built against glibc — so most prebuilt C++ binaries
  fail, and Alpine's own `libstdc++` is musl-linked and cannot substitute
- NSS (name service switch): `getpwnam`, `getgrnam`, LDAP/SSSD backends
- gconv: `iconv` module loading, i.e. many charset conversions
- glibc's locale machinery (that is what `musl-locales` exists for)

"Extending gcompat" therefore means reimplementing the parts of glibc that
people actually miss. Adélie has been doing exactly that as an organisation for
years. It is not an AdoOS sprint, and claiming it would be the claim/reality
gap this document exists to prevent.

**What AdoOS supports instead, in order of how well it works:**

1. **Flatpak** — `community/flatpak` exists in Alpine (with two patches). This
   is the supported answer for desktop applications and it needs no glibc work
   from us.
2. **distrobox + podman** — both in `community`. The supported answer for
   "any application, including a glibc one", at the cost of a container.
3. **glibc in a prefix + loader wrapper** — `glibc`, `libstdc++` and `libgcc_s`
   built against glibc under `/usr/glibc`, run via
   `/usr/glibc/lib/ld-linux-x86-64.so.2 --library-path …`. This works and is
   the fallback for things Flatpak does not ship. It is a **documented hack**:
   it breaks under NSS, locales and anything that re-execs through `/lib64`.
   It ships as its own package, marked unsupported.
4. **A full glibc variant of the tree** (Void's model: rebuild everything
   against glibc). The only actually-correct answer, months of work, out of
   scope.

### 2. "Easier repos / install paths for desktop and specialized software"

Cheap at the mechanism level, expensive at the operational level.

- apk is already multi-repo: an AdoOS repository is an `APKINDEX.tar.gz` and one
  line in `/etc/apk/repositories`. Building it is `abuild` + `apk index` +
  `abuild-sign`.
- The real cost is what a private binary repo *means*: every package AdoOS
  builds is a package AdoOS is responsible for. That means tracking Alpine's
  security advisories and rebuilding on musl/ABI bumps.

**Rule: an AdoOS package exists only if upstream Alpine refused it or has not
packaged it yet.** Everything else goes upstream first.

### 3. NVIDIA

**Cut.** Not because "NVIDIA is heavy" but because of where the split falls:

- The proprietary userspace (`libnvidia-*`, CUDA, DLSS) is prebuilt against
  glibc. There is no musl path to it, and Alpine does not package it.
- The **open** stack already works: Alpine's `mesa` 26.1.1 builds
  `mesa-vulkan-nouveau` (NVK) plus nouveau in the kernel. musl-native, no blobs.
- `nvidia-open`'s kernel side is C and would compile fine on musl; only its
  userspace is glibc. So the long-term path, if ever wanted, is kernel module +
  userspace through Flatpak or the glibc prefix above.

Supported claim: **open NVIDIA stack (nouveau/NVK) via mesa. Proprietary driver
and CUDA: not supported, no plan.**

### 4. Localization

This one is real, cheap, and upstreamable.

- `main/musl-locales` (from Adélie) provides locale definitions for musl. It is
  in the ISO's package list.
- Persian/RTL is a fonts-and-libraries problem (`font-*`, harfbuzz, icu), not a
  libc problem. Nothing here needs a fork.
- Wherever a locale fix is general, it belongs upstream in Alpine.

## Rules

1. `aports/` stays an unmodified checkout. AdoOS adds profiles, overlays, and
   packages — never patches to Alpine recipes.
2. No fork of core tooling. A rebranded `apk-tools` costs a rebase on every
   upstream sync, which is the opposite of "in the Alpine family". If the
   rebrand is kept at all, it ships as a patch series applied at package build
   time. *(open decision — the local `adoos` branch is not part of this repo)*
3. Upstream first. AdoOS-specific only when upstream declines.
4. One claim per feature, and this file is where it is written down.

## Status

| Area | State |
|------|-------|
| ISO profile, overlay, branding | builds through `scripts/build-iso.sh`; no root required |
| `apk-tools` rebrand | developed on a local branch; verified to build and to pass the upstream test suite |
| AdoOS package repository | not started |
| Flatpak / distrobox path | available from Alpine's `community`; not yet wired into the ISO or documented for users |
| glibc prefix package | not started |
| Localization | `musl-locales` in the ISO package list; no fonts, no input method work yet |
| NVIDIA | open stack only; nothing AdoOS-specific planned |
| Serial console | `console=ttyS0,115200` on the kernel cmdline; the live overlay still ships Alpine's commented-out serial getty, so the console stops at the kernel log |
| Boot test | not yet run on a built AdoOS ISO |

## Known gaps

**`ADOOS_LITE=1` does not yet skip the firmware download.** The override of
`section_kernels` in `iso/mkimg.adoos.sh` changes the package list passed to
`update-kernel`, but `update-kernel` adds `linux-firmware` itself
(`aports`-installed `alpine-conf`, line 279). That pulls 757 MB across 113
`linux-firmware-*` subpackages. The flag currently only changes the modloop
*contents*, not the download. Fixing it means resolving `linux-firmware` to an
empty package (a local repository with a higher-version stub, signed with the
ISO key) — not done yet.
