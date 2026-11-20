#!/bin/sh
# Runs inside the OpenWrt SDK image, with this folder at /ath11k and the output folder at /out.
set -eu
. /ath11k/build.env

cd /builder
./scripts/feeds update base
./scripts/feeds install kmod-ath11k-ahb
pkg=$(readlink -f package/feeds/base/mac80211)

for patch in /ath11k/patches/*.patch; do
	name=$(basename "$patch")
	if [ -e "$pkg/patches/ath11k/$name" ]; then
		echo "$name already exists in this OpenWrt release; rename or drop it" >&2
		exit 1
	fi
	cp "$patch" "$pkg/patches/ath11k/"
done

# Above the stock release, so the nodes' package manager never replaces this build with the stock one.
sed -i "s/^PKG_RELEASE:=.*/PKG_RELEASE:=$((100 + BUILD))/" "$pkg/Makefile"

echo CONFIG_PACKAGE_kmod-ath11k-ahb=m >> .config
make defconfig
make package/mac80211/compile -j"$(nproc)" || make package/mac80211/compile V=s

for name in kmod-ath11k kmod-ath11k-ahb; do
	cp "$(find bin -name "$name-[0-9]*.apk")" "/out/$name.apk"
done
cp dl/backports-*.tar.* /out/
tar -czf /out/mac80211-package.tar.gz -C "$(dirname "$pkg")" mac80211
cd /out && sha256sum ./* > sha256sums
