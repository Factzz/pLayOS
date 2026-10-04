#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update v3.0.3
# Build: 261104
#
# แยกตามสายของเครื่อง (ดูจาก VERSION ใน /opt/system/playos_info.cfg)
#   สาย 3.0  (ไม่มีวงเล็บ)  -> ใช้โฟลเดอร์ 261104/3.0
#       ดึง emulationstation + FindManager จากเวอร์ชันก่อน (261030)
#       + retroarch cfg (64/32) + playpod -> /opt/play_pod
#       เครื่องที่ต่ำกว่า 3.0.2 (build 261030) จะได้ชุดของ 3.0.2 ตามไปด้วย
#       (es_systems.cfg, apps.zip, logo จาก 261030) กันตกหล่น
#   สาย X    (เฉพาะ 3.0.2(X) เท่านั้น) -> ใช้โฟลเดอร์ 261104/X
#       retroarch cfg (64/32) + playpod -> /opt/play_pod  (ไม่แตะ ES/FindManager)
#   สายวงเล็บอื่น, 3.0.0, สูงกว่า 3.0.3, เป็น 3.0.3 อยู่แล้ว (ทุกบิลด์ ทุกสาย) -> ยกเลิก
#
# แถบหลอดบนหน้าจอ: บรรทัดที่ขึ้นต้นด้วย ">>" คือข้อความสถานะ
#   ถ้ามี "NN%" ในบรรทัด แถบจะเลื่อนตามเปอร์เซ็นต์จริง
#
# โครงไฟล์บน repo
#   .../main/261104/3.0/  retroarch.cfg, retroarch-core-options.cfg, playpod
#                         32/retroarch.cfg, 32/retroarch-core-options.cfg
#   .../main/261104/X/    (ชุดเดียวกัน)
#   .../main/261030/      emulationstation, FindManager (+ es_systems.cfg, apps.zip,
#                         playos-logo.png สำหรับเครื่องที่ข้ามจาก 3.0.1)
# ==========================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

INFO_FILE="/opt/system/playos_info.cfg"
CURRENT_VERSION_RAW=$(grep -m1 '^VERSION=' "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)
CURRENT_BUILD=$(grep -m1 '^BUILD=' "$INFO_FILE" 2>/dev/null | cut -d'"' -f2 | tr -cd '0-9')

NEW_VERSION="3.0.3"
NEW_BUILD=261104
X_VERSION_STAMP="3.0.3(X)"        # ค่า VERSION ที่ประทับให้เครื่องสาย X
X_REQUIRED_VERSION="3.0.2"        # สาย X อัปเดตได้เฉพาะเครื่องที่เป็น 3.0.2(X)
MIN_VERSION="3.0.1"               # สาย 3.0 ต้องเป็น 3.0.1 ขึ้นไป
PREV_VERSION="3.0.2"              # เวอร์ชันก่อนหน้า (อ้างอิงโฟลเดอร์ PREV_BASE)
PREV_BUILD=261030

REPO="https://raw.githubusercontent.com/Factzz/pLayOS/main"
NEW_BASE="$REPO/261104"           # + /3.0 หรือ /X
PREV_BASE="$REPO/261030"          # es + find (และชุด 3.0.2) ดึงจากที่นี่

PLAYPOD_SRC="playpod"             # ชื่อไฟล์บน repo (ในโฟลเดอร์ 3.0 และ X)
PLAYPOD_DEST="/opt/play_pod/playpod"

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

ver_lt() {  # true ถ้า $1 < $2
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}

# ---------- เลือกโหมด: MODE=3.0|X|cancel (+ EXTRAS=1 ถ้าต้องเอาชุด 3.0.2 ตามไปด้วย) ----------
decide_mode() {
    MODE="cancel"; EXTRAS=0

    if [ "$VERSION_MAJOR_MINOR" != "$REQUIRED_MAJOR_MINOR" ]; then
        CANCEL_MSG="This update only applies to $REQUIRED_MAJOR_MINOR.x (yours: ${VERSION_BASE:-UNKNOWN}). Update canceled."; return
    fi
    if ver_lt "$NEW_VERSION" "$VERSION_BASE"; then
        CANCEL_MSG="Version $VERSION_BASE is newer than $NEW_VERSION. Update canceled."; return
    fi

    # 3.0.3 ทุกบิลด์ ทุกสาย = อัปเดตแล้ว ห้ามอัปซ้ำ
    if [ "$VERSION_BASE" = "$NEW_VERSION" ]; then
        CANCEL_MSG="Already on v$NEW_VERSION (build $CURRENT_BUILD). Update canceled."; return
    fi

    # ----- สาย X -----
    if [ -n "$VERSION_TAG" ]; then
        if [ "$VERSION_TAG" != "X" ]; then
            CANCEL_MSG="This device is on the '$VERSION_TAG' variant track. Update canceled."; return
        fi
        # สาย X อนุญาตเฉพาะ 3.0.2(X) เท่านั้น
        if [ "$VERSION_BASE" != "$X_REQUIRED_VERSION" ]; then
            CANCEL_MSG="X track update only applies to v$X_REQUIRED_VERSION(X) (yours: $CURRENT_VERSION_RAW). Update canceled."; return
        fi
        if [ "$CURRENT_BUILD" -ge "$NEW_BUILD" ]; then
            CANCEL_MSG="Already up to date (build $CURRENT_BUILD >= $NEW_BUILD). Update canceled."; return
        fi
        MODE="X"; return
    fi

    # ----- สาย 3.0 -----
    if ver_lt "$VERSION_BASE" "$MIN_VERSION"; then
        CANCEL_MSG="Version $VERSION_BASE is older than $MIN_VERSION. Update canceled."; return
    fi
    MODE="3.0"
    # ยังไม่ถึง 3.0.2 (build 261030) -> เอาชุดของ 3.0.2 ตามไปด้วย
    if ver_lt "$VERSION_BASE" "$PREV_VERSION" || \
       { [ "$VERSION_BASE" = "$PREV_VERSION" ] && [ "$CURRENT_BUILD" -lt "$PREV_BUILD" ]; }; then
        EXTRAS=1
    fi
}

decide_mode
if [ "$MODE" = "cancel" ]; then
    say "$CANCEL_MSG"
    sleep 3; exit 0
fi

# ---------- ฟังก์ชันร่วม ----------
fail_exit() { rm -rf "$STAGE_DIR"; sleep 3; exit 1; }

fetch() {  # fetch <base-url> <ชื่อบน repo>   (เก็บใน stage ด้วยชื่อเดียวกัน)
    local pct=$((5 + DL_DONE * 40 / DL_TOTAL))
    say "Downloading $2... ${pct}%"
    mkdir -p "$(dirname "$STAGE_DIR/$2")"
    wget -q -t 3 -T 60 -O "$STAGE_DIR/$2" "$1/$2"
    if [ ! -s "$STAGE_DIR/$2" ]; then
        say "FAILED to download $2 - nothing was changed."
        fail_exit
    fi
    DL_DONE=$((DL_DONE + 1))
}

check_elf() {  # ไฟล์โปรแกรมต้องเป็น ELF จริง ไม่ใช่หน้า error
    if [ "$(head -c 4 "$STAGE_DIR/$1" | od -An -tx1 | tr -d ' \n')" != "7f454c46" ]; then
        say "$1 download is not a valid program - nothing was changed."
        fail_exit
    fi
}

install_fm() {  # วางแบบ atomic (กัน "text file busy" ถ้าโปรแกรมเปิดอยู่)
    mkdir -p "$(dirname "$FM_DEST")"
    if [ -f "$FM_DEST" ]; then
        cp -f "$FM_DEST" "$FM_DEST.bak.$ts"
        chown ark:ark "$FM_DEST.bak.$ts"
    fi
    cp -f "$STAGE_DIR/FindManager" "$FM_DEST.new" \
        && chown ark:ark "$FM_DEST.new" \
        && chmod 755 "$FM_DEST.new" \
        && mv -f "$FM_DEST.new" "$FM_DEST" \
        || { rm -f "$FM_DEST.new"; say "Failed to install FindManager - please retry the update."; exit 1; }
}

# ==========================================
# 0. ดาวน์โหลดไฟล์ทั้งหมดก่อน (พลาด = ยังไม่แตะระบบเลย)
# ==========================================
say "Preparing update files... 5%"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/32"

TRACK_BASE="$NEW_BASE/$MODE"       # .../261104/3.0 หรือ .../261104/X
DL_DONE=0
DL_TOTAL=$(( ${#RA_FILES[@]} + 1 ))
[ "$MODE" = "3.0" ] && DL_TOTAL=$(( DL_TOTAL + 2 ))
[ "$EXTRAS" = "1" ] && DL_TOTAL=$(( DL_TOTAL + 3 ))

if [ "$MODE" = "3.0" ]; then
    fetch "$PREV_BASE" emulationstation
    check_elf emulationstation
    fetch "$PREV_BASE" FindManager
    check_elf FindManager
    if [ "$EXTRAS" = "1" ]; then
        fetch "$PREV_BASE" es_systems.cfg
        fetch "$PREV_BASE" apps.zip
        fetch "$PREV_BASE" playos-logo.png
    fi
fi
for entry in "${RA_FILES[@]}"; do fetch "$TRACK_BASE" "${entry%%|*}"; done
fetch "$TRACK_BASE" "$PLAYPOD_SRC"

ts="$(date +%Y%m%d%H%M%S)"

# ==========================================
# 1. สาย 3.0 เท่านั้น: EmulationStation + FindManager (+ ชุด 3.0.2)
# ==========================================
if [ "$MODE" = "3.0" ]; then
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

    say "Updating FindManager... 58%"
    install_fm

    if [ "$EXTRAS" = "1" ]; then
        say "Updating system configuration... 64%"
        mkdir -p "$(dirname "$ES_SYSTEMS_DEST")"
        [ -f "$ES_SYSTEMS_DEST" ] && cp -f "$ES_SYSTEMS_DEST" "$ES_SYSTEMS_DEST.bak.$ts"
        cp -f "$STAGE_DIR/es_systems.cfg" "$ES_SYSTEMS_DEST"
        chown root:root "$ES_SYSTEMS_DEST"
        chmod 644 "$ES_SYSTEMS_DEST"

        say "Updating apps... 70%"
        mkdir -p /opt /opt/system
        unzip -X -o "$STAGE_DIR/apps.zip" -d /opt \
            || { say "Failed to install apps - please retry the update."; exit 1; }
        chown -R ark:ark /opt/apps
        find /opt/apps -type f -name '*.sh' -exec chmod +x {} +

        cp -f "$STAGE_DIR/playos-logo.png" "$LOGO_DEST"
        chown ark:ark "$LOGO_DEST"
        chmod 644 "$LOGO_DEST"
    fi
fi

# ==========================================
# 2. RetroArch config (64 + 32)  -- ทั้งสาย 3.0 และ X
# ==========================================
say "Updating RetroArch config... 78%"
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
# 3. playpod -> /opt/play_pod  -- ทั้งสาย 3.0 และ X
# ==========================================
say "Updating PlayPod... 88%"
mkdir -p "$(dirname "$PLAYPOD_DEST")"
[ -f "$PLAYPOD_DEST" ] && cp -f "$PLAYPOD_DEST" "$PLAYPOD_DEST.bak.$ts"
cp -f "$STAGE_DIR/$PLAYPOD_SRC" "$PLAYPOD_DEST.new" \
    && chmod 755 "$PLAYPOD_DEST.new" \
    && mv -f "$PLAYPOD_DEST.new" "$PLAYPOD_DEST" \
    || { rm -f "$PLAYPOD_DEST.new"; say "Failed to install PlayPod - please retry the update."; exit 1; }
chown -R ark:ark "$(dirname "$PLAYPOD_DEST")"

# ==========================================
# 4. ประทับเวอร์ชัน (ท้ายสุด)
# ==========================================
say "Finishing... 96%"
if [ "$MODE" = "X" ]; then STAMP="$X_VERSION_STAMP"; else STAMP="$NEW_VERSION"; fi
cat > "$INFO_FILE" <<EOT
VERSION="$STAMP"
BUILD="$NEW_BUILD"
EOT

rm -rf "$STAGE_DIR"
say "Update completed! (PLAY OS v$STAMP) Restarting... 100%"
sleep 3
exit 187
