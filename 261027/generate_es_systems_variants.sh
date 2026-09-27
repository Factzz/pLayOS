#!/bin/bash
# ---------------------------------------------------------------------------
# generate_es_systems_variants.sh
#
# Builds the three variant files SdCardControl::applyCfg() switches between:
#
#   es_systems.cfg.sd1   every <path> forced onto /roms/...   (SD1 only)
#   es_systems.cfg.sd2   every <path> forced onto /roms2/...  (SD2 only)
#   es_systems.cfg.dual  only the systems named in -d go onto /roms2/...,
#                        everything else stays on /roms/...   (SD1 + SD2)
#
# Only <path>...</path> lines are touched (matches how the original
# "Switch to SD2 for Roms.sh" edited es_systems.cfg: <command>, <extension>,
# etc. are left alone). The source is first normalized back to /roms/... so
# this is safe to re-run even if the live cfg is currently mid-switched to
# SD2/Dual.
#
# Usage:
#   sudo ./generate_es_systems_variants.sh
#   sudo ./generate_es_systems_variants.sh -s /path/to/es_systems.cfg -o /etc/emulationstation
#   sudo ./generate_es_systems_variants.sh -d "psx ps2 psp dreamcast saturn"
#
#   -s  source es_systems.cfg to build from (default: /etc/emulationstation/es_systems.cfg)
#   -o  directory to write the .sd1/.sd2/.dual files into (default: same dir as -s)
#   -d  space-separated <name> values that go on /roms2 in Dual mode
#       (default list below - edit to match the systems you want split)
# ---------------------------------------------------------------------------
set -euo pipefail

SRC="/etc/emulationstation/es_systems.cfg"
OUT_DIR=""
DUAL_SD2_SYSTEMS="psx ps2 psp dreamcast saturn naomi atomiswave n64 fbneo neogeo"

usage() {
    echo "Usage: $0 [-s source_cfg] [-o output_dir] [-d \"system1 system2 ...\"]" >&2
    echo "  -s  source es_systems.cfg to build the three variants from (default: $SRC)" >&2
    echo "  -o  directory to write the .sd1/.sd2/.dual files into (default: same dir as -s)" >&2
    echo "  -d  space-separated <name> values that go on /roms2 in Dual mode" >&2
    echo "      current default: \"$DUAL_SD2_SYSTEMS\"" >&2
    exit 1
}

while getopts "s:o:d:h" opt; do
    case "$opt" in
        s) SRC="$OPTARG" ;;
        o) OUT_DIR="$OPTARG" ;;
        d) DUAL_SD2_SYSTEMS="$OPTARG" ;;
        h|*) usage ;;
    esac
done

if [ ! -f "$SRC" ]; then
    echo "Source file not found: $SRC" >&2
    exit 1
fi

if [ -z "$OUT_DIR" ]; then
    OUT_DIR="$(dirname "$SRC")"
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Note: not running as root - writes under $OUT_DIR (and chown to ark) may fail. Re-run with sudo if so." >&2
fi

SD1="$OUT_DIR/es_systems.cfg.sd1"
SD2="$OUT_DIR/es_systems.cfg.sd2"
DUAL="$OUT_DIR/es_systems.cfg.dual"

TMP_BASE="$(mktemp)"
trap 'rm -f "$TMP_BASE"' EXIT

# ---- normalize source back to /roms/... on <path> lines, regardless of
#      whatever mode the live cfg currently happens to be in ----------------
sed '/<path>/s#/roms2/#/roms/#' "$SRC" > "$TMP_BASE"

for f in "$SD1" "$SD2" "$DUAL"; do
    if [ -f "$f" ]; then
        cp -f "$f" "$f.bak.$(date +%Y%m%d%H%M%S)"
        echo "Backed up existing $f"
    fi
done

# ---- sd1: baseline, all <path> on /roms/... --------------------------------
cp -f "$TMP_BASE" "$SD1"
echo "Wrote $SD1 ($(grep -c '<path>/roms/' "$SD1" || true) path(s) on /roms)"

# ---- sd2: every <path> forced onto /roms2/... ------------------------------
sed '/<path>/s#/roms/#/roms2/#' "$TMP_BASE" > "$SD2"
echo "Wrote $SD2 ($(grep -c '<path>/roms2/' "$SD2" || true) path(s) on /roms2)"

# ---- dual: only the listed <name> systems move to /roms2/... --------------
DUAL_SD2_SYSTEMS="$DUAL_SD2_SYSTEMS" awk '
BEGIN {
    n = split(ENVIRON["DUAL_SD2_SYSTEMS"], list, /[ \t]+/)
    for (i = 1; i <= n; i++) if (list[i] != "") wanted[list[i]] = 1
    inSys = 0
}
{
    if (!inSys) {
        if ($0 ~ /<system>/) {
            inSys = 1
            buf = $0 "\n"
            name = ""
        } else {
            print
        }
        next
    }

    buf = buf $0 "\n"
    if (match($0, /<name>[^<]*<\/name>/)) {
        line = substr($0, RSTART, RLENGTH)
        gsub(/<\/?name>/, "", line)
        name = line
    }

    if ($0 ~ /<\/system>/) {
        if (name in wanted) {
            nlines = split(buf, larr, "\n")
            buf = ""
            for (li = 1; li < nlines; li++) {   # last element is empty (trailing \n)
                line = larr[li]
                if (line ~ /<path>/)
                    gsub(/\/roms\//, "/roms2/", line)
                buf = buf line "\n"
            }
        }
        printf "%s", buf
        inSys = 0
    }
    next
}
' "$TMP_BASE" > "$DUAL"

moved=$(grep -c '<path>/roms2/' "$DUAL" || true)
echo "Wrote $DUAL ($moved system(s) on /roms2, rest on /roms - see -d to change which systems)"

# ---- ownership / permissions, matching what applyCfg()'s sudo-cp fallback
#      sets on the live cfg ---------------------------------------------------
for f in "$SD1" "$SD2" "$DUAL"; do
    chown ark:ark "$f" 2>/dev/null || true
    chmod 644 "$f"
done

# ---- sanity check, if xmllint is on this image -----------------------------
if command -v xmllint >/dev/null 2>&1; then
    for f in "$SD1" "$SD2" "$DUAL"; do
        if ! xmllint --noout "$f" 2>/tmp/es_variant_xmllint.err; then
            echo "WARNING: $f failed XML validation:" >&2
            cat /tmp/es_variant_xmllint.err >&2
        fi
    done
else
    echo "xmllint not found - skipping XML validation"
fi

echo "Done."
