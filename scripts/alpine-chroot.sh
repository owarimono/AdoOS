#!/bin/sh
# Rootless Alpine builder chroot: no sudo (unshare -Ur gives a fake root).
# The AdoOS tree is bind-mounted read-write at /adoos inside the chroot.
#
# Usage:
#   scripts/alpine-chroot.sh                 # interactive shell
#   scripts/alpine-chroot.sh apk add abuild  # run one command inside
#
# ponytail: single shared rootfs at .builder/, no overlayfs, no per-arch roots.
# Wipe it when it drifts from ALPINE_VER instead of adding a snapshot layer.
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="${ADOOS_BUILDER:-$REPO/.builder}"
VER="${ALPINE_VER:-3.24.1}"
URL="https://dl-cdn.alpinelinux.org/alpine/v${VER%.*}/releases/x86_64/alpine-minirootfs-${VER}-x86_64.tar.gz"

if [ ! -x "$ROOT/bin/busybox" ]; then
	# The tarball is extracted as root-in-userns, so verify it against the
	# checksum the mirror publishes next to it before handing it to tar.
	SHA_URL="$URL.sha256"
	echo "[*] fetching $URL" >&2
	WANT="$(curl -fsSL "$SHA_URL" | cut -d' ' -f1)"
	if [ -z "$WANT" ]; then
		echo "[!] no checksum published at $SHA_URL" >&2
		exit 1
	fi
	mkdir -p "$ROOT"
	curl -fsSL "$URL" -o "$ROOT.tar.gz"
	GOT="$(sha256sum "$ROOT.tar.gz" | cut -d' ' -f1)"
	if [ "$GOT" != "$WANT" ]; then
		echo "[!] checksum mismatch for $URL" >&2
		echo "    expected $WANT" >&2
		echo "    got      $GOT" >&2
		rm -f "$ROOT.tar.gz"
		exit 1
	fi
	tar -xzf "$ROOT.tar.gz" -C "$ROOT"
	rm -f "$ROOT.tar.gz"
fi

CMD="${*:-sh}"
exec unshare -Ur -m env ROOT="$ROOT" REPO="$REPO" CMD="$CMD" sh -ec '
	set -e
	mkdir -p "$ROOT/proc" "$ROOT/dev" "$ROOT/sys" "$ROOT/adoos"
	# rbind, not mount -t proc: mounting a fresh procfs in a userns needs a pid
	# namespace too (unshare -p), rbind does not.
	mountpoint -q "$ROOT/proc"  || mount --rbind /proc "$ROOT/proc"
	mountpoint -q "$ROOT/dev"   || mount --rbind /dev "$ROOT/dev"
	mountpoint -q "$ROOT/sys"   || mount --rbind /sys "$ROOT/sys"
	mountpoint -q "$ROOT/adoos" || mount --rbind "$REPO" "$ROOT/adoos"
	install -m 644 /etc/resolv.conf "$ROOT/etc/resolv.conf" 2>/dev/null || true
	# env -i: nothing from the host leaks in (TMPDIR, PATH, LD_* all point at
	# paths that do not exist inside the rootfs).
	exec chroot "$ROOT" /usr/bin/env -i \
		HOME=/root \
		PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
		TMPDIR=/tmp \
		/bin/sh -c "cd /adoos; $CMD"
'
