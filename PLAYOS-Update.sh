#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update v3.0.2
# Build: 261030
# Track: STANDARD (3.0.x) only
#
# โหมดการทำงาน (เลือกอัตโนมัติจากเวอร์ชันในเครื่อง)
#   FULL  : เครื่อง 3.0.1 (หรือ 3.0.2 ที่ build < 261030)
#           -> อัปเดตทั้งชุด แล้วประทับเวอร์ชัน 3.0.2 / 261030
#   PATCH : เครื่อง 3.0.2 build 261030 (อัปเดตไปแล้ว)
#           -> อัปเดตเฉพาะ FindManager ตัวเดียว รันซ้ำได้ ถ้าเหมือนเดิมจะข้ามเอง
#   อื่นๆ : 3.0.0, 3.0.2 build ใหม่กว่า, สูงกว่า 3.0.2, สายวงเล็บ 3.0(X) -> ยกเลิก
#
# แถบหลอดบนหน้าจอ: ทุกบรรทัดที่ขึ้นต้นด้วย ">>" คือข้อความสถานะ
#   ถ้ามี "NN%" ในบรรทัด แถบจะเลื่อนตามเปอร์เซ็นต์จริง
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
CURRENT_VERSION_RAW=$(grep -m1 '^VERSION=' "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)
CURRENT_BUILD=$(grep -m1 '^BUILD=' "$INFO_FILE" 2>/dev/null | cut -d'"' -f2 | tr -cd '0-9')

NEW_VERSION="3.0.2"
MIN_VERSION="3.0.1"
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

say "PLAY OS Updater - current: ${CURRENT_VERSION_RAW:-unknown} (build $CURRENT_BUILD) 2%"

VERSION_BASE=$(echo "$CURRENT_VERSION_RAW" | sed -E 's/\(.*\)//')
VERSION_TAG=$(echo "$CURRENT_VERSION_RAW" | sed -nE 's/.*\(([^)]*)\).*/\1/p')
VERSION_MAJOR_MINOR=$(echo "$VERSION_BASE" | cut -d. -f1,2)
REQUIRED_MAJOR_MINOR="3.0"

# ---------- เลือกโหมด: ตั้งค่า MODE=full|patch หรือ MODE=cancel + CANCEL_MSG ----------
decide_mode() {
    MODE="cancel"
    # 🛡️ 1: ห้ามสายวงเล็บ เช่น 3.0(X)
    if [ -n "$VERSION_TAG" ]; then
        CANCEL_MSG="This device is on the '$VERSION_TAG' variant track. Update canceled."; return
    fi
    # 🛡️ 2: ต้องเป็นสาย 3.0.x
    if [ "$VERSION_MAJOR_MINOR" != "$REQUIRED_MAJOR_MINOR" ]; then
        CANCEL_MSG="This update only applies to $REQUIRED_MAJOR_MINOR.x (yours: ${VERSION_BASE:-UNKNOWN}). Update canceled."; return
    fi
    # 🛡️ 3: 3.0.2 พอดี -> ดูที่ build
    if [ "$VERSION_BASE" = "$NEW_VERSION" ]; then
        if [ "$CURRENT_BUILD" -lt "$NEW_BUILD" ]; then
            MODE="full"
        elif [ "$CURRENT_BUILD" -eq "$NEW_BUILD" ]; then
            MODE="patch"
        else
            CANCEL_MSG="Build $CURRENT_BUILD is newer than $NEW_BUILD. Update canceled."
        fi
        return
    fi
    # 🛡️ 4: ต่ำกว่า 3.0.2 ต้องตั้งแต่ 3.0.1 ขึ้นไป ส่วนสูงกว่า 3.0.2 ห้าม
    if [ "$(printf '%s\n%s\n' "$VERSION_BASE" "$NEW_VERSION" | sort -V | head -n1)" != "$VERSION_BASE" ]; then
        CANCEL_MSG="Version $VERSION_BASE is newer than $NEW_VERSION. Update canceled."; return
    fi
    if [ "$(printf '%s\n%s\n' "$VERSION_BASE" "$MIN_VERSION" | sort -V | head -n1)" != "$MIN_VERSION" ]; then
        CANCEL_MSG="Version $VERSION_BASE is older than $MIN_VERSION. Update canceled."; return
    fi
    MODE="full"
}

# ---------- ฟังก์ชันร่วม ----------
DL_TOTAL=9; DL_DONE=0; DL_BASE=5; DL_SPAN=40   # แถบ % ของช่วงดาวน์โหลด

fetch() {  # fetch <ชื่อบน repo>
    local pct=$((DL_BASE + DL_DONE * DL_SPAN / DL_TOTAL))
    say "Downloading $1... ${pct}%"
    wget -q -t 3 -T 60 -O "$STAGE_DIR/$1" "$URL_BASE/$1"
    if [ ! -s "$STAGE_DIR/$1" ]; then
        say "FAILED to download $1 - nothing was changed."
        rm -rf "$STAGE_DIR"
        sleep 3; exit 1
    fi
    DL_DONE=$((DL_DONE + 1))
}

check_fm_elf() {  # FindManager ต้องเป็นไฟล์โปรแกรมจริง (ELF) ไม่ใช่หน้า error
    if [ "$(head -c 4 "$STAGE_DIR/FindManager" | od -An -tx1 | tr -d ' \n')" != "7f454c46" ]; then
        say "FindManager download is not a valid program - nothing was changed."
        rm -rf "$STAGE_DIR"
        sleep 3; exit 1
    fi
}

install_fm() {  # วางแบบ atomic (กัน "text file busy" ถ้าโปรแกรมเปิดอยู่)
    local backup="$1"
    mkdir -p "$(dirname "$FM_DEST")"
    if [ -f "$FM_DEST" ]; then
        cp -f "$FM_DEST" "$backup"
        chown ark:ark "$backup"
    fi
    cp -f "$STAGE_DIR/FindManager" "$FM_DEST.new" \
        && chown ark:ark "$FM_DEST.new" \
        && chmod 755 "$FM_DEST.new" \
        && mv -f "$FM_DEST.new" "$FM_DEST" \
        || { rm -f "$FM_DEST.new"; say "Failed to install FindManager - please retry the update."; exit 1; }
}

decide_mode
if [ "$MODE" = "cancel" ]; then
    say "$CANCEL_MSG"
    sleep 3; exit 0
fi

# ==========================================
# โหมด PATCH: อัปเดตเฉพาะ FindManager (รันซ้ำได้)
# ==========================================
if [ "$MODE" = "patch" ]; then
    say "Checking FindManager... 10%"
    rm -rf "$STAGE_DIR"
    mkdir -p "$STAGE_DIR"
    DL_TOTAL=1; DL_BASE=30; DL_SPAN=0
    fetch FindManager
    say "Verifying FindManager... 60%"
    check_fm_elf

    if [ -f "$FM_DEST" ] && cmp -s "$STAGE_DIR/FindManager" "$FM_DEST"; then
        rm -rf "$STAGE_DIR"
        say "FindManager is already the latest. 100%"
        sleep 3; exit 0
    fi

    say "Installing FindManager... 80%"
    install_fm "$FM_DEST.bak"
    rm -rf "$STAGE_DIR"
    say "FindManager updated! 100%"
    sleep 3
    exit 0
fi

# ==========================================
# โหมด FULL
# 0. ดาวน์โหลดไฟล์ทั้งหมดก่อน (พลาด = ยังไม่แตะระบบเลย)
# ==========================================
say "Preparing update files... 5%"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/32"

fetch emulationstation
fetch es_systems.cfg
fetch apps.zip
fetch FindManager
check_fm_elf
fetch playos-logo.png
for entry in "${RA_FILES[@]}"; do fetch "${entry%%|*}"; done

ts="$(date +%Y%m%d%H%M%S)"

# ==========================================
# 1. EmulationStation (ark:ark ห้ามเป็น root)
# ==========================================
say "Updating EmulationStation... 50%"
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
say "Updating system configuration... 60%"
mkdir -p "$(dirname "$ES_SYSTEMS_DEST")"
[ -f "$ES_SYSTEMS_DEST" ] && cp -f "$ES_SYSTEMS_DEST" "$ES_SYSTEMS_DEST.bak.$ts"
cp -f "$STAGE_DIR/es_systems.cfg" "$ES_SYSTEMS_DEST"
chown root:root "$ES_SYSTEMS_DEST"
chmod 644 "$ES_SYSTEMS_DEST"

# ==========================================
# 3. apps (/opt/apps) / FindManager / logo
# ==========================================
say "Updating apps... 70%"
mkdir -p /opt /opt/FindManager_Data /opt/system
unzip -X -o "$STAGE_DIR/apps.zip" -d /opt \
    || { say "Failed to install apps - please retry the update."; exit 1; }
chown -R ark:ark /opt/apps
find /opt/apps -type f -name '*.sh' -exec chmod +x {} +

say "Updating FindManager... 78%"
install_fm "$FM_DEST.bak.$ts"

cp -f "$STAGE_DIR/playos-logo.png" "$LOGO_DEST"
chown ark:ark "$LOGO_DEST"
chmod 644 "$LOGO_DEST"

# ==========================================
# 4. RetroArch config (64 + 32)
# ==========================================
say "Updating RetroArch config... 88%"
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
say "Finishing... 96%"
cat > "$INFO_FILE" <<EOT
VERSION="$NEW_VERSION"
BUILD="$NEW_BUILD"
EOT

rm -rf "$STAGE_DIR"
say "Update completed! (PLAY OS v$NEW_VERSION) Restarting... 100%"
sleep 3
exit 187
