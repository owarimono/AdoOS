# apk-tools Architecture

Source: `apk-tools/src/` (v3.0.6)

## Entry point

`apk.c` — parses global options, finds the requested applet, opens the database, dispatches.

## Applet system

Each subcommand is a separate `app_*.c` file, registered via `apk_applet_register()` in `applet.c`. Applets:

| File | Command |
|------|---------|
| `app_add.c` | `apk add` |
| `app_del.c` | `apk del` |
| `app_update.c` | `apk update` |
| `app_upgrade.c` | `apk upgrade` |
| `app_search.c` | `apk search` |
| `app_info.c` | `apk info` |
| `app_list.c` | `apk list` |
| `app_fetch.c` | `apk fetch` |
| `app_cache.c` | `apk cache` |
| `app_audit.c` | `apk audit` |
| `app_fix.c` | `apk fix` |
| `app_policy.c` | `apk policy` |
| `app_dot.c` | `apk dot` |
| `app_stats.c` | `apk stats` |
| `app_query.c` | `apk query` |
| `app_manifest.c` | `apk manifest` |
| `app_version.c` | `apk version` |
| `app_verify.c` | `apk verify` |
| `app_index.c` | `apk index` |
| `app_mkndx.c` | `apk mkndx` |
| `app_mkpkg.c` | `apk mkpkg` |
| `app_extract.c` | `apk extract` |
| `app_adbdump.c` | `apk adbdump` |
| `app_adbgen.c` | `apk adbgen` |
| `app_adbsign.c` | `apk adbsign` |
| `app_convdb.c` | `apk convdb` |
| `app_convndx.c` | `apk convndx` |

## Core modules

| File | Purpose |
|------|---------|
| `database.c` | Package database: repos, installed packages, file tracking |
| `solver.c` | Dependency solver (constraint satisfaction) |
| `package.c` | Package metadata parsing |
| `commit.c` | Transaction commit (install/remove) |
| `extract_v2.c` / `extract_v3.c` | Package extraction (v2=tar, v3=ADB format) |
| `crypto.c` / `crypto_openssl.c` / `crypto_mbedtls.c` | Signature verification |
| `io.c` / `io_zstd.c` / `io_gunzip.c` | I/O and decompression |
| `trust.c` | Trust key management |
| `version.c` | Version comparison |
| `repoparser.c` | Repository index parsing |
| `serialize.c` | Package serialization (JSON, YAML, ADB) |

## Data structures

- `apk_database` — top-level: repos, packages, tags, overlay
- `apk_package` — single package: name, version, deps, files
- `apk_name` — package name, points to install choice + candidates
- `apk_repository` — a repo with URL, index, signing key
- `apk_solver` — dependency resolution state

## Build system

Meson (preferred) or legacy Makefile (musl only). Dependencies:
- zlib, libzstd, openssl (or mbedtls)
- Optional: lua (bindings), python (bindings), scdoc (manpages)
