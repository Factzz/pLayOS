#!/bin/sh
# PLAYOS BRICK-Update.sh  -  OTA for release 4.1BRICK
# Package: BRICK4.1.zip  (contains only the fixed .system/bin/suspend: power-button wake fix)
#
# Contract with playfe (Settings -> Device -> System update):
#   * playfe downloads this file over HTTPS, runs it with `sh` as root, and shows every line that contains ">>"
#     (text after ">>" is the status line; a number followed by "%" drives the progress bar)
#   * exit code 0 (or 187) = success -> playfe offers to restart; anything else = "Update failed"
set -e
SD="${SDCARD_PATH:-/mnt/SDCARD}"
URL="${PLAYOS_UPDATE_URL:-https://github.com/Factzz/pLayOS/releases/download/4.1BRICK/BRICK4.1.zip}"
NEWVER="4.1.0"                      # written to .userdata/shared/playos_brick.cfg after a successful install
TMP=/tmp/playos_brick_update
CA=""; [ -n "$NX_CA_BUNDLE" ] && CA="--ca-certificate=$NX_CA_BUNDLE"

fail() { echo ">> $1"; rm -rf "$TMP"; exit "${2:-1}"; }

# unzip is not guaranteed on the firmware: use what exists (NX ships one in .tmp_update, 7zzs in shared/bin)
unpack() { # $1 = zip, $2 = target dir
	if command -v unzip >/dev/null 2>&1; then
		unzip -q -o "$1" -d "$2"
	elif [ -x "$SD/.tmp_update/tg5040/unzip" ]; then
		"$SD/.tmp_update/tg5040/unzip" -q -o "$1" -d "$2"
	elif [ -x "$SD/.system/shared/bin/7zzs.aarch64" ]; then
		"$SD/.system/shared/bin/7zzs.aarch64" x -y -o"$2" "$1" >/dev/null
	else
		return 127
	fi
}

rm -rf "$TMP"; mkdir -p "$TMP"; cd "$TMP"

echo ">> Downloading 10%"
wget -q -t 3 -T 60 $CA "$URL" -O pkg.zip || fail "Download failed" 3
[ -s pkg.zip ] || fail "Download failed (empty file)" 3

echo ">> Unpacking 40%"
mkdir x
unpack pkg.zip x || fail "Could not unpack the update" 4
NEWF="$(find x -type f -name suspend | head -n 1)"
[ -n "$NEWF" ] || fail "suspend not found in the update" 5

echo ">> Checking 60%"
head -n 1 "$NEWF" | grep -q '^#!/bin/sh' || fail "Invalid suspend (no #!/bin/sh)" 6
! grep -q "$(printf '\r')" "$NEWF" || fail "Invalid suspend (Windows line endings)" 6
sh -n "$NEWF" || fail "Invalid suspend (syntax error)" 6

echo ">> Installing 80%"
DST="$SD/.system/bin/suspend"
[ -f "$DST" ] && cp -p "$DST" "$DST.prev" 2>/dev/null || true       # one backup of the previous version
cp "$NEWF" "$DST.new" && chmod 755 "$DST.new" && sync && mv -f "$DST.new" "$DST" || fail "Install failed" 7

CFG="$SD/.userdata/shared/playos_brick.cfg"
[ -f "$CFG" ] && sed -i "s/^VERSION=.*/VERSION=\"$NEWVER\"/" "$CFG" 2>/dev/null || true

echo ">> Done 100%"
rm -rf "$TMP"
exit 0
