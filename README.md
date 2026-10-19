# AdoOS

Fork of Alpine Linux with customized apk package manager.

## What is this

Alpine Linux fork based on 3.24.1. Goal: modify apk-tools to support AdoOS-specific features while keeping Alpine compatibility.

## Repo structure

```
AdoOS/
  alpine-standard-3.24.1-x86_64.iso   # base ISO
  apk-tools/                           # apk source (gitlab.alpinelinux.org/alpine/apk-tools)
  aports/                              # Alpine package recipes (aports)
  docs/                                # design docs, decisions
  overlay/                             # filesystem overlay for custom ISO
  iso/                                 # ISO build output
  scripts/                             # build scripts
```

## Building apk-tools

```bash
cd apk-tools
meson setup -Dprefix=/usr build
ninja -C build
# binary: build/src/apk
```

## Modifying apk

Edit source in `apk-tools/src/`. Each `app_*.c` is an apk subcommand (applet).
The solver logic is in `solver.c`, database in `database.c`, package parsing in `package.c`.

## Building custom ISO

Requires Alpine chroot (see `scripts/build-iso.sh`).
