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
}

# Brand the volume id (also used by grub's search --label, so keep one source).
gen_volid() {
	printf "%s" "adoos-${profile_abbrev:-$PROFILE} ${RELEASE%_rc*} $ARCH" | cut -c1-32
}
