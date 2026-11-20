#!/bin/sh
# Opens an issue here when something upstream needs a look. Each event has a fixed title, and an issue with that title
# in any state counts as already reported, so a closed one isn't opened again.
set -eu
. ath11k/build.env

report() {
	title=$1
	if gh issue list --state all --limit 200 --json title --jq '.[].title' | grep -qxF "$title"; then
		echo "Already reported: $title"
		return
	fi
	echo "Reporting: $title"
	gh issue create --title "$title" --body "$2"
}

for number in 24254 24154; do
	state=$(gh api "repos/openwrt/openwrt/issues/$number" --jq 'if .pull_request.merged_at then "merged" else .state end')
	if [ "$state" != open ]; then
		report "openwrt/openwrt#$number is $state" "openwrt/openwrt#$number, which the ath11k build is about, is $state now.

Check whether the fix is in an OpenWrt release the devices can upgrade to. If it is, upgrade them to that release and
remove the patched driver; if it isn't yet, keep building it. See the README."
	fi
done

latest=$(curl -fsS https://downloads.openwrt.org/releases/ |
	grep -oE 'href="[0-9]+\.[0-9]+\.[0-9]+/"' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -uV | tail -n 1)
if [ "$latest" != "$OPENWRT_RELEASE" ]; then
	report "OpenWrt $latest is out" "OpenWrt $latest is out; the ath11k build is for $OPENWRT_RELEASE.

Before the devices are upgraded, build ath11k for it: set \`OPENWRT_RELEASE=$latest\` and \`BUILD=1\` in
\`ath11k/build.env\`, check that the patches still apply, and merge. Upgrading first brings back the stock driver until
that release exists."
fi
