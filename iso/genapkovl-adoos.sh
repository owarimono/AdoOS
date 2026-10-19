#!/bin/sh -e
# AdoOS apkovl: the live system's overlay.
# Run by mkimage.sh as: (cd $DESTDIR; fakeroot genapkovl-adoos.sh <hostname>)
#
# Files listed in the tarball are installed by apk's --overlay-from-stdin,
# so they win over the packages that own the same paths (branding sticks).
#
# ADOOS_OVERLAY defaults to /adoos/overlay (the repo bind-mount inside the
# builder chroot, see scripts/alpine-chroot.sh).
HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	echo "usage: $0 hostname" >&2
	exit 1
fi

OVERLAY="${ADOOS_OVERLAY:-/adoos/overlay}"
[ -d "$OVERLAY" ] || { echo "overlay dir not found: $OVERLAY" >&2; exit 1; }

makefile() {
	OWNER="$1" PERMS="$2" FILENAME="$3"
	cat > "$FILENAME"
	chown "$OWNER" "$FILENAME"
	chmod "$PERMS" "$FILENAME"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# static branding files (etc/os-release, etc/issue, etc/motd, ...)
# Files come from the host checkout, so re-own them (fakeroot makes this stick).
cp -a "$OVERLAY"/. "$tmp"/
chown -R root:root "$tmp/"

mkdir -p "$tmp/etc"
makefile root:root 0644 "$tmp/etc/hostname" <<EOF
$HOSTNAME
EOF

# With an apkovl present, initramfs-init only wires up boot services when this
# marker exists (init:950). Ship it empty rather than re-listing runlevels.
: > "$tmp/etc/.default_boot_services"
chown root:root "$tmp/etc/.default_boot_services"
chmod 0644 "$tmp/etc/.default_boot_services"

mkdir -p "$tmp/etc/apk"
makefile root:root 0644 "$tmp/etc/apk/world" <<EOF
alpine-base
musl-locales
EOF

tar -c -C "$tmp" etc | gzip -9n > "$HOSTNAME.apkovl.tar.gz"
