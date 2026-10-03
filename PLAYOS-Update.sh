#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update v3.0.2
# Build: 261030
# Track: STANDARD (3.0.x) only
#   - รับเฉพาะ 3.0.x ที่ต่ำกว่า 3.0.2 (build < 261030)
#   - ปฏิเสธสายวงเล็บ เช่น 3.0(X) และเวอร์ชันที่สูงกว่า 3.0.2
#
# อัปเดตเฉพาะของ PLAY OS (ไม่ยุ่งกับ dArkOSen)
#
# โครงไฟล์บน repo  .../main/261030/
#   emulationstation                    -> /usr/bin/emulationstation/emulationstation (ark:ark)
#   es_systems.cfg                      -> /etc/emulationstation/es_systems.cfg
#   apps.zip  (มีโฟลเดอร์ apps/ ข้างใน)   -> /opt/apps
#   FindManager (ไฟล์โปรแกรมเดี่ยว)        -> /opt/FindManager_Data/FindManager
#   playos-logo.png                     -> /opt/system/playos-logo.png
#   retroarch.cfg, retroarch-core-options.cfg           -> ~/.config/retroarch/
#   32/retroarch.cfg, 32/retroarch-core-options.cfg     -> ~/.config/retroarch32/
# ==========================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

INFO_FILE="/opt/system/playos_info.cfg"
CURRENT_VERSION_RAW=$(grep "VERSION" "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)
CURRENT_BUILD=$(grep "BUILD" "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)

NEW_VERSION="3.0.2"
NEW_BUILD=261030
URL_BASE="https://raw.githubusercontent.com/Factzz/pLayOS/main/261030"

ES_BIN="/usr/bin/emulationstation/emulationstation"
ES_SYSTEMS_DEST="/etc/emulationstation/es_systems.cfg"
LOGO_DEST="/opt/system/playos-logo.png"
FM_DEST="/opt/FindManager_Data/FindManager"
STAGE_DIR="/home/ark/.playos_stage"

# RetroArch  "ไฟล์บน repo|ปลายทางบนเครื่อง"
RA_FILES=(
    "retroarch.cfg|/home/ark/.config/retroarch/retroarch.cfg"
    "retroarch-core-options.cfg|/home/ark/.config/retroarch/retroarch-core-options.cfg"
    "32/retroarch.cfg|/home/ark/.config/retroarch32/retroarch.cfg"
    "32/retroarch-core-options.cfg|/home/ark/.config/retroarch32/retroarch-core-options.cfg"
)

# ---------- log: รายละเอียดลงไฟล์ / หน้าจอแสดงแค่สถานะสั้นๆ ----------
LOG_FILE="/home/ark/PLAYOS-update-$NEW_BUILD.log"
exec 3>&1
exec >>"$LOG_FILE" 2>&1
say() { echo ">> $*"; echo ">> $*" >&3; }

[ -z "$CURRENT_BUILD" ] && CURRENT_BUILD=0

say "PLAY OS Updater - current: ${CURRENT_VERSION_RAW:-unknown} (build $CURRENT_BUILD)"

VERSION_BASE=$(echo "$CURRENT_VERSION_RAW" | sed -E 's/\(.*\)//')
VERSION_TAG=$(echo "$CURRENT_VERSION_RAW" | sed -nE 's/.*\(([^)]*)\).*/\1/p')
VERSION_MAJOR_MINOR=$(echo "$VERSION_BASE" | cut -d. -f1,2)
REQUIRED_MAJOR_MINOR="3.0"

# 🛡️ 1: ห้ามสายวงเล็บ เช่น 3.0(X)
if [ -n "$VERSION_TAG" ]; then
    say "This device is on the '$VERSION_TAG' variant track. Update canceled."
    sleep 3; exit 0
fi

# 🛡️ 2: ต้องเป็นสาย 3.0.x
if [ "$VERSION_MAJOR_MINOR" != "$REQUIRED_MAJOR_MINOR" ]; then
    say "This update only applies to $REQUIRED_MAJOR_MINOR.x (yours: ${VERSION_BASE:-UNKNOWN}). Update canceled."
    sleep 3; exit 0
fi

# 🛡️ 3: เวอร์ชันปัจจุบันต้องไม่สูงกว่า 3.0.2
if [ "$(printf '%s\n%s\n' "$VERSION_BASE" "$NEW_VERSION" | sort -V | tail -n1)" != "$NEW_VERSION" ]; then
    say "Version $VERSION_BASE is newer than $NEW_VERSION. Update canceled."
    sleep 3; exit 0
fi

# 🛡️ 4: build ปัจจุบันต้องต่ำกว่า build ใหม่
if [ "$CURRENT_BUILD" -ge "$NEW_BUILD" ]; then
    say "Already up to date (build $CURRENT_BUILD >= $NEW_BUILD). Update canceled."
    sleep 3; exit 0
fi

# ==========================================
# 0. ดาวน์โหลดไฟล์ทั้งหมดก่อน (พลาด = ยังไม่แตะระบบเลย)
# ==========================================
say "Preparing update files..."
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/32"

fetch() {  # fetch <ชื่อบน repo>
    wget -q -t 3 -T 60 -O "$STAGE_DIR/$1" "$URL_BASE/$1"
    if [ ! -s "$STAGE_DIR/$1" ]; then
        say "FAILED to download $1 - nothing was changed."
        rm -rf "$STAGE_DIR"
        sleep 3; exit 1
    fi
}
fetch emulationstation
fetch es_systems.cfg
fetch apps.zip
fetch FindManager
fetch playos-logo.png
for entry in "${RA_FILES[@]}"; do fetch "${entry%%|*}"; done

ts="$(date +%Y%m%d%H%M%S)"

# ==========================================
# 1. EmulationStation (ark:ark ห้ามเป็น root)
# ==========================================
say "Updating EmulationStation..."
mkdir -p "$(dirname "$ES_BIN")"
if [ -f "$ES_BIN" ]; then
    cp -f "$ES_BIN" "$ES_BIN.bak.$ts"
    chown ark:ark "$ES_BIN.bak.$ts"
fi
cp -f "$STAGE_DIR/emulationstation" "$ES_BIN"
chown ark:ark "$ES_BIN"
chmod 755 "$ES_BIN"
echo ">> ES: $(stat -c '%U:%G %a' "$ES_BIN") $ES_BIN"

# ==========================================
# 2. es_systems.cfg (วางทับของเดิม)
# ==========================================
say "Updating system configuration..."
mkdir -p "$(dirname "$ES_SYSTEMS_DEST")"
[ -f "$ES_SYSTEMS_DEST" ] && cp -f "$ES_SYSTEMS_DEST" "$ES_SYSTEMS_DEST.bak.$ts"
cp -f "$STAGE_DIR/es_systems.cfg" "$ES_SYSTEMS_DEST"
chown root:root "$ES_SYSTEMS_DEST"
chmod 644 "$ES_SYSTEMS_DEST"

# ==========================================
# 3. apps (/opt/apps) / FindManager / logo
# ==========================================
say "Updating apps..."
mkdir -p /opt /opt/FindManager_Data /opt/system
unzip -X -o "$STAGE_DIR/apps.zip" -d /opt \
    || { say "Failed to install apps - please retry the update."; exit 1; }
chown -R ark:ark /opt/apps
find /opt/apps -type f -name '*.sh' -exec chmod +x {} +

[ -f "$FM_DEST" ] && cp -f "$FM_DEST" "$FM_DEST.bak.$ts"
cp -f "$STAGE_DIR/FindManager" "$FM_DEST" \
    || { say "Failed to install FindManager - please retry the update."; exit 1; }
chown ark:ark "$FM_DEST"
chmod 755 "$FM_DEST"

cp -f "$STAGE_DIR/playos-logo.png" "$LOGO_DEST"
chown ark:ark "$LOGO_DEST"
chmod 644 "$LOGO_DEST"

# ==========================================
# 4. RetroArch config (64 + 32)
# ==========================================
say "Updating RetroArch config..."
for entry in "${RA_FILES[@]}"; do
    src="${entry%%|*}"; dest="${entry#*|}"
    mkdir -p "$(dirname "$dest")"
    [ -f "$dest" ] && cp -f "$dest" "$dest.bak.$ts"
    cp -f "$STAGE_DIR/$src" "$dest"
    chown ark:ark "$dest"; chmod 644 "$dest"
    echo ">> installed $dest"
done
chown ark:ark /home/ark/.config/retroarch /home/ark/.config/retroarch32 2>/dev/null

# ==========================================
# 5. ประทับเวอร์ชัน (ท้ายสุด)
# ==========================================
cat > "$INFO_FILE" <<EOT
VERSION="$NEW_VERSION"
BUILD="$NEW_BUILD"
EOT

rm -rf "$STAGE_DIR"
say "Update completed! (PLAY OS v$NEW_VERSION) Restarting..."
sleep 3
exit 187
