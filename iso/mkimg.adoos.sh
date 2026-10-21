# AdoOS ISO profile for Alpine's own mkimage.sh.
# Loaded via $HOME/.mkimage/ (mkimage.sh:204) — aports stays untouched.
profile_adoos() {
	profile_standard
	title="AdoOS"
	desc="Alpine-based. Localized, small, with documented glibc paths.
		Runs from RAM. Network required."
	profile_abbrev="adoos"
	image_name="adoos"
	apkovl="genapkovl-adoos.sh"
	hostname="adoos"
	apks="$apks musl-locales"
	# Keep the VGA console and add serial: the ISO boots in a VM/headless box
	# with `qemu -nographic` and the boot log is capturable.
	kernel_cmdline="console=tty0 console=ttyS0,115200"
}

# Brand the volume id (also used by grub's search --label, so keep one source).
# profile_abbrev already says "adoos"; prefixing it again produced
# "adoos-adoos 241020 x86_64".
gen_volid() {
	printf "%s" "${profile_abbrev:-$PROFILE} ${RELEASE%_rc*} $ARCH" | cut -c1-32
}

# mkimg.base.sh puts the whole linux-firmware metapackage (~600 MB to download,
# the bulk of build time on a slow link) into the modloop. ADOOS_LITE=1 drops
# it: the image boots, but wifi/GPU firmware is missing. Overriding the function
# through the plugin dir (sourced after aports/scripts) — no patch to aports.
if [ -n "$ADOOS_LITE" ]; then
section_kernels() {
	local _f _a _pkgs
	for _f in $kernel_flavors; do
		_pkgs="linux-$_f wireless-regdb $modloop_addons"
		for _a in $kernel_addons; do
			_pkgs="$_pkgs $_a-$_f"
		done
		local id=$( (echo "$initfs_features::$_hostkeys" ; apk fetch --root "$APKROOT" --simulate alpine-base $_pkgs | sort) | checksum)
		build_section kernel $ARCH $_f $id $_pkgs
	done
}
fi
