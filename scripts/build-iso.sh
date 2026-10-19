#!/bin/sh
# Build the AdoOS ISO: a thin wrapper around Alpine's own mkimage.sh.
# No sudo. Re-executes itself inside the rootless builder chroot, so the same
# script works both on the host and inside.
#
#   scripts/build-iso.sh                -> iso/adoos-<tag>-<arch>.iso
#   ALPINE_VER=3.24.1 ARCH=x86_64       -> overrides
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ALPINE_VER="${ALPINE_VER:-3.24.1}"
ALPINE_BRANCH="v${ALPINE_VER%.*}"
ARCH="${ARCH:-x86_64}"
OUTDIR=/adoos/iso
WORKDIR=/adoos/.mkimage-work
# Reachable-by-default mirror; overridable for slow links (ADOOS_MIRROR=https://mirrors.aliyun.com/alpine).
MIRROR="${ADOOS_MIRROR:-https://dl-cdn.alpinelinux.org/alpine}"
REPO_MAIN="$MIRROR/$ALPINE_BRANCH/main"
REPO_COMMUNITY="$MIRROR/$ALPINE_BRANCH/community"

# --- outside the chroot: enter it -----------------------------------------
if [ ! -e /etc/alpine-release ]; then
	# Pin the image timestamp to this repo's HEAD so rebuilds are reproducible.
	E="${SOURCE_DATE_EPOCH:-$(git -C "$REPO" log -1 --format=%cd --date=unix 2>/dev/null || date +%s)}"
	# Passed inline: the chroot runs with a cleared environment (env -i).
	ENV="SOURCE_DATE_EPOCH=$E ALPINE_VER=$ALPINE_VER ARCH=$ARCH ADOOS_MIRROR=$MIRROR"
	if [ -n "$ADOOS_LITE" ]; then ENV="$ENV ADOOS_LITE=$ADOOS_LITE"; fi
	exec "$REPO/scripts/alpine-chroot.sh" "$ENV /adoos/scripts/build-iso.sh"
fi

# --- inside: Alpine host --------------------------------------------------
export HOME=/root
export ADOOS_OVERLAY=/adoos/overlay

apk info -e abuild >/dev/null 2>&1 || apk add --no-cache \
	abuild alpine-conf xorriso mtools syslinux grub-efi fakeroot squashfs-tools

# Signing key for the ISO's own boot repository (/apks). mkimage needs it set
# because profile_base turns on modloop_sign. Done by hand instead of
# abuild-keygen: that script only needs $SUDO (doas) to copy the pubkey, and we
# are already root.
if [ -z "$PACKAGER_PRIVKEY" ]; then
	KEY="$HOME/.abuild/adoos-iso.rsa"
	if [ ! -f "$KEY" ]; then
		mkdir -p "$HOME/.abuild"
		(umask 0007; openssl genrsa -out "$KEY" 2048)
		openssl rsa -in "$KEY" -pubout -out "$KEY.pub"
	fi
	mkdir -p /etc/apk/keys
	cp -f "$KEY.pub" /etc/apk/keys/
	PACKAGER_PRIVKEY="$KEY"
	export PACKAGER_PRIVKEY
fi

# mkimage.sh:288 initialises APKROOT with `apk add --initdb --no-chown`, and
# --no-chown implies usermode, which apk refuses to run as root (context.c:103).
# We are root in the user namespace, so seed APKROOT the privileged way and let
# mkimage take its "cache already exists" path (that block is skipped whole).
APKROOT="$WORKDIR/apkroot-$ARCH"
if [ ! -e "$APKROOT" ]; then
	mkdir -p "$APKROOT/etc/apk/cache" "$APKROOT/etc/apk/keys"
	cp /usr/share/apk/keys/"$ARCH"/* "$APKROOT/etc/apk/keys/"
	cp "$PACKAGER_PRIVKEY.pub" "$APKROOT/etc/apk/keys/" 2>/dev/null || true
	apk --arch "$ARCH" --root "$APKROOT" add --initdb
fi
# Rewritten every run so switching mirrors reuses the download cache (mkimage
# skips its own APKROOT block entirely once the directory exists).
printf '%s\n%s\n' "$REPO_MAIN" "$REPO_COMMUNITY" > "$APKROOT/etc/apk/repositories"
# Same for the chroot itself: apk calls without --root (the tool install below)
# would otherwise still hit the minirootfs default mirror.
printf '%s\n%s\n' "$REPO_MAIN" "$REPO_COMMUNITY" > /etc/apk/repositories

# mkimage loads profiles and apkovl scripts from $HOME/.mkimage (mkimage.sh:204).
mkdir -p /root/.mkimage
ln -sf /adoos/iso/mkimg.adoos.sh /root/.mkimage/mkimg.adoos.sh
ln -sf /adoos/iso/genapkovl-adoos.sh /root/.mkimage/genapkovl-adoos.sh

exec sh /adoos/aports/scripts/mkimage.sh \
	--profile adoos \
	--arch "$ARCH" \
	--tag "$ALPINE_VER" \
	--outdir "$OUTDIR" \
	--workdir "$WORKDIR" \
	--checksum \
	--repository "$REPO_MAIN" \
	--repository "$REPO_COMMUNITY"
