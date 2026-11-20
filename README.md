# openwrt-builds

OpenWrt packages built with fixes that aren't upstream yet. They're built with the official OpenWrt SDK image and
published as [releases](../../releases), together with the source they were built from.

Use at your own risk: no warranty, see [LICENSE](LICENSE).

## ath11k: RX memory fix for qualcommax/ipq807x

On 512 MB IPQ8074 devices such as the Linksys MX4200 v1, stock ath11k slowly uses up the RAM until the kernel kills
`hostapd`, `wpa_supplicant` or `netifd` ([openwrt/openwrt#24154](https://github.com/openwrt/openwrt/issues/24154)).
The memory doesn't show up in slab or in any process: RX buffers come from the shared per-CPU page-frag cache, and a
few long-lived fragments keep whole pages allocated. It is worst on nodes with an 802.11s mesh backhaul.

The two patches in [`ath11k/patches`](ath11k/patches) are from
[openwrt/openwrt#24254](https://github.com/openwrt/openwrt/pull/24254) by Mark Ruvald Pedersen (commit `2ab272d`),
unchanged:

- `950`: makes the external IRQ enable and disable idempotent, which `951` relies on during teardown.
- `951`: gives each RXDMA ring its own page-frag cache. RX ring sizes stay as they are.

A release contains:

| File | What |
| --- | --- |
| `kmod-ath11k.apk`, `kmod-ath11k-ahb.apk` | The patched driver packages. Install both; the other wireless packages stay stock |
| `backports-*.tar.*` | The driver source (Linux backports) the packages were built from |
| `mac80211-package.tar.gz` | OpenWrt's `mac80211` package with all its patches, these two included |
| `sha256sums` | Checksums of the above |

The packages only load on the exact OpenWrt release they were built for, because kernel modules have to match the
running kernel. Each release is named `ath11k-<OpenWrt release>-<build>`.

### Versions

[`ath11k/build.env`](ath11k/build.env) holds the OpenWrt release, the target and the build number. The package
release is `r` plus 100 plus the build number (`-r101` for build 1), above the stock one, so the package manager never
swaps it back for the stock package. When the patches change, raise `BUILD`; the PR check fails otherwise. Move
`OPENWRT_RELEASE` together with the OpenWrt upgrade of the devices, never ahead of it, and set `BUILD` back to 1.

### Install

On the device, with the two packages copied to `/tmp`, then reboot:

```sh
apk add --allow-untrusted /tmp/kmod-ath11k.apk /tmp/kmod-ath11k-ahb.apk
reboot
```

The packages aren't signed with OpenWrt's key, hence `--allow-untrusted`. To go back to the stock driver, reinstall
the stock packages from the OpenWrt feed and reboot:

```sh
apk update
apk add kmod-ath11k=<stock version> kmod-ath11k-ahb=<stock version>
reboot
```

### Build

The `build` workflow builds on every PR and on `main`; on `main` it publishes the release if it doesn't exist yet.
To build locally, with Docker:

```sh
mkdir -p out
. ath11k/build.env
docker run --rm -v "$PWD/ath11k:/ath11k:ro" -v "$PWD/out:/out" "openwrt/sdk:$TARGET-$OPENWRT_RELEASE" sh /ath11k/build.sh
```
