#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update  Build 261110
#   สาย 3.0 (ไม่มีวงเล็บ) -> 3.0.5
#   สาย X   (มี "(X)")    -> 3.0.5(X)
# เลือกสายอัตโนมัติจาก VERSION ใน /opt/system/playos_info.cfg
#
# สิ่งที่อัปเดตของรุ่นนี้ (ทั้งสองสาย)
#   emulationstation -> /usr/bin/emulationstation/emulationstation
#   FindManager      -> /opt/FindManager_Data/FindManager
#   ดึงจากโฟลเดอร์ 261110/3.0 (สาย 3.0) หรือ 261110/X (สาย X)
#
# เครื่องที่ยังไม่มีชุดของรุ่นก่อนๆ จะได้ตามไปด้วย (กันตกหล่น)
#   สาย 3.0 : ต่ำกว่า 3.0.2 (261030) -> es_systems.cfg, apps.zip, logo   (จาก 261030)
#             ต่ำกว่า 3.0.3 (261104) -> retroarch cfg 64/32 + playpod    (จาก 261104/3.0)
#   สาย X   : ต่ำกว่า 3.0.3(X) (261104) -> retroarch cfg 64/32 + playpod (จาก 261104/X)
#             ต่ำกว่า 3.0.4(X) (261106) -> drastic.sh + BIOS (system.zip) (จาก 261106)
#
# รับ: สาย 3.0 ตั้งแต่ 3.0.1  /  สาย X ตั้งแต่ 3.0.2(X)
# ยกเลิก: 3.0.5 ขึ้นไปทุกบิลด์ (อัปเดตแล้ว ห้ามอัปซ้ำ), 3.0.0, สายวงเล็บอื่น
#
# แถบหลอดบนหน้าจอ: บรรทัดที่ขึ้นต้นด้วย ">>" คือข้อความสถานะ
#   ถ้ามี "NN%" ในบรรทัด แถบจะเลื่อนตามเปอร์เซ็นต์จริง
#
# โครงไฟล์บน repo
#   .../main/261110/3.0/  emulationstation, FindManager
#   .../main/261110/X/    emulationstation, FindManager
#   .../main/261106/      drastic.sh, system.zip                   (สาย X เก่ากว่า 3.0.4)
#   .../main/261104/3.0/  retroarch.cfg, retroarch-core-options.cfg, playpod, 32/...
#   .../main/261104/X/    (ชุดเดียวกัน)
#   .../main/261030/      es_systems.cfg, apps.zip, playos-logo.png (สาย 3.0 เก่ากว่า 3.0.2)
# ==========================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

INFO_FILE="/opt/system/playos_info.cfg"
CURRENT_VERSION_RAW=$(grep -m1 '^VERSION=' "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)
CURRENT_BUILD=$(grep -m1 '^BUILD=' "$INFO_FILE" 2>/dev/null | cut -d'"' -f2 | tr -cd '0-9')

NEW_VERSION="3.0.5"
NEW_BUILD=261110
STAMP_30="3.0.5"
STAMP_X="3.0.5(X)"
MIN_30="3.0.1"                    # สาย 3.0 ต้องเป็น 3.0.1 ขึ้นไป
MIN_X="3.0.2"                     # สาย X ต้องเป็น 3.0.2(X) ขึ้นไป

# ชุดของรุ่นก่อนๆ (เวอร์ชัน/บิลด์ที่ปล่อย)
P302_VERSION="3.0.2"; P302_BUILD=261030     # สาย 3.0: es_systems + apps + logo
P303_VERSION="3.0.3"; P303_BUILD=261104     # ทั้งสองสาย: retroarch cfg + playpod
P304_VERSION="3.0.4"; P304_BUILD=261106     # สาย X: drastic.sh + BIOS

REPO="https://raw.githubusercontent.com/Factzz/pLayOS/main"
B302="$REPO/261030"
B303_30="$REPO/261104/3.0"
B303_X="$REPO/261104/X"
B304="$REPO/261106"
B305="$REPO/261110"               # + /3.0 หรือ /X

ES_BIN="/usr/bin/emulationstation/emulationstation"
FM_DEST="/opt/FindManager_Data/FindManager"
ES_SYSTEMS_DEST="/etc/emulationstation/es_systems.cfg"
LOGO_DEST="/opt/system/playos-logo.png"
PLAYPOD_SRC="playpod"
PLAYPOD_DEST="/opt/play_pod/playpod"
DRASTIC_SRC="drastic.sh"
DRASTIC_DEST="/usr/local/bin/drastic.sh"
BIOS_ZIP="system.zip"
ROMS_CANDIDATES=("/roms" "/PLAYROMS" "/mnt/PLAYROMS" "/media/PLAYROMS")
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

# ---------- diagnostics: จดสาเหตุที่สคริปต์จบ/ถูกหยุด ลง log ----------
trap 'rc=$?; echo "[$(date +%T)] script exit rc=$rc"' EXIT
trap 'echo "[$(date +%T)] got SIGPIPE (GUI pipe closed) - continuing"' PIPE
trap 'echo "[$(date +%T)] got SIGHUP - continuing"' HUP
trap 'echo "[$(date +%T)] got SIGTERM"; exit 143' TERM
trap 'echo "[$(date +%T)] got SIGINT"; exit 130' INT
echo "[$(date)] start pid=$$"
df -h /home/ark 2>&1 | tail -n 1
free -m 2>&1 | sed -n 2p

[ -z "$CURRENT_BUILD" ] && CURRENT_BUILD=0

say "PLAY OS Updater - current: ${CURRENT_VERSION_RAW:-unknown} (build $CURRENT_BUILD) 2%"

VERSION_BASE=$(echo "$CURRENT_VERSION_RAW" | sed -E 's/\(.*\)//')
VERSION_TAG=$(echo "$CURRENT_VERSION_RAW" | sed -nE 's/.*\(([^)]*)\).*/\1/p')
VERSION_MAJOR_MINOR=$(echo "$VERSION_BASE" | cut -d. -f1,2)
REQUIRED_MAJOR_MINOR="3.0"

ver_lt() {  # true ถ้า $1 < $2
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}
older_than() {  # older_than <ver> <build> : เครื่องนี้ยังไม่ถึง ver/build นั้น
    ver_lt "$VERSION_BASE" "$1" || { [ "$VERSION_BASE" = "$1" ] && [ "$CURRENT_BUILD" -lt "$2" ]; }
}

# ---------- เลือกโหมด: MODE=3.0|X|cancel  +  N302/N303/N304 = ชุดรุ่นก่อนที่ต้องตามไปด้วย ----------
decide_mode() {
    MODE="cancel"; N302=0; N303=0; N304=0
    local min

    if [ "$VERSION_MAJOR_MINOR" != "$REQUIRED_MAJOR_MINOR" ]; then
        CANCEL_MSG="This update only applies to $REQUIRED_MAJOR_MINOR.x (yours: ${VERSION_BASE:-UNKNOWN}). Update canceled."; return
    fi
    if [ -z "$VERSION_TAG" ]; then
        MODE="3.0"; min="$MIN_30"
    elif [ "$VERSION_TAG" = "X" ]; then
        MODE="X"; min="$MIN_X"
    else
        MODE="cancel"
        CANCEL_MSG="This device is on the '$VERSION_TAG' variant track. Update canceled."; return
    fi

    # 3.0.5 ขึ้นไปทุกบิลด์ = ห้ามอัปซ้ำ
    if [ "$VERSION_BASE" = "$NEW_VERSION" ]; then
        MODE="cancel"; CANCEL_MSG="Already on v$NEW_VERSION (build $CURRENT_BUILD). Update canceled."; return
    fi
    if ver_lt "$NEW_VERSION" "$VERSION_BASE"; then
        MODE="cancel"; CANCEL_MSG="Version $VERSION_BASE is newer than $NEW_VERSION. Update canceled."; return
    fi
    if ver_lt "$VERSION_BASE" "$min"; then
        MODE="cancel"; CANCEL_MSG="Version $VERSION_BASE is older than $min. Update canceled."; return
    fi

    # ชุดรุ่นก่อนที่เครื่องนี้ยังไม่มี
    if [ "$MODE" = "3.0" ]; then
        older_than "$P302_VERSION" "$P302_BUILD" && N302=1
        older_than "$P303_VERSION" "$P303_BUILD" && N303=1
    else
        older_than "$P303_VERSION" "$P303_BUILD" && N303=1
        older_than "$P304_VERSION" "$P304_BUILD" && N304=1
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
    wget -nv -t 3 -T 60 -O "$STAGE_DIR/$2" "$1/$2"
    echo "[$(date +%T)] wget $2 rc=$? size=$(stat -c %s "$STAGE_DIR/$2" 2>/dev/null)"
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

find_bios_dir() {  # หา <ROMS>/bios : ถ้ามีโฟลเดอร์ bios อยู่แล้วใช้ก่อน ไม่งั้นใช้ตัวที่มีพาร์ทิชันอยู่
    local r
    for r in "${ROMS_CANDIDATES[@]}"; do
        [ -d "$r/bios" ] && { BIOS_DIR="$r/bios"; return 0; }
    done
    for r in "${ROMS_CANDIDATES[@]}"; do
        [ -d "$r" ] && { BIOS_DIR="$r/bios"; return 0; }
    done
    return 1
}

install_bin() {  # install_bin <ชื่อใน stage> <ปลายทาง> <owner:group> : วางแบบ atomic (กัน "text file busy")
    mkdir -p "$(dirname "$2")"
    if [ -f "$2" ]; then
        cp -f "$2" "$2.bak.$ts"
        chown ark:ark "$2.bak.$ts"
    fi
    cp -f "$STAGE_DIR/$1" "$2.new" \
        && chown "$3" "$2.new" \
        && chmod 755 "$2.new" \
        && mv -f "$2.new" "$2" \
        || { rm -f "$2.new"; say "Failed to install $1 - please retry the update."; exit 1; }
}

install_ra() {  # RetroArch config (64 + 32)
    local entry src dest
    for entry in "${RA_FILES[@]}"; do
        src="${entry%%|*}"; dest="${entry#*|}"
        mkdir -p "$(dirname "$dest")"
        [ -f "$dest" ] && cp -f "$dest" "$dest.bak.$ts"
        cp -f "$STAGE_DIR/$src" "$dest"
        chown ark:ark "$dest"; chmod 644 "$dest"
        echo ">> installed $dest"
    done
    chown ark:ark /home/ark/.config/retroarch /home/ark/.config/retroarch32 2>/dev/null
}

install_playpod() {  # playpod -> /opt/play_pod
    mkdir -p "$(dirname "$PLAYPOD_DEST")"
    [ -f "$PLAYPOD_DEST" ] && cp -f "$PLAYPOD_DEST" "$PLAYPOD_DEST.bak.$ts"
    cp -f "$STAGE_DIR/$PLAYPOD_SRC" "$PLAYPOD_DEST.new" \
        && chmod 755 "$PLAYPOD_DEST.new" \
        && mv -f "$PLAYPOD_DEST.new" "$PLAYPOD_DEST" \
        || { rm -f "$PLAYPOD_DEST.new"; say "Failed to install PlayPod - please retry the update."; exit 1; }
    chown -R ark:ark "$(dirname "$PLAYPOD_DEST")"
}

# ==========================================
# 0. เช็กก่อนเริ่ม + รายการดาวน์โหลด (พลาด = ยังไม่แตะระบบเลย)
# ==========================================
say "Preparing update files... 5%"

if [ "$N304" = "1" ] && ! find_bios_dir; then
    say "ROMS partition not found (checked: ${ROMS_CANDIDATES[*]}) - nothing was changed."
    sleep 3; exit 1
fi
[ "$N304" = "1" ] && echo "[bios dir] $BIOS_DIR"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/32"

B303="$B303_30"; [ "$MODE" = "X" ] && B303="$B303_X"

DL=()   # "base|ชื่อไฟล์"
DL+=("$B305/$MODE|emulationstation" "$B305/$MODE|FindManager")
if [ "$N302" = "1" ]; then
    DL+=("$B302|es_systems.cfg" "$B302|apps.zip" "$B302|playos-logo.png")
fi
if [ "$N303" = "1" ]; then
    for entry in "${RA_FILES[@]}"; do DL+=("$B303|${entry%%|*}"); done
    DL+=("$B303|$PLAYPOD_SRC")
fi
if [ "$N304" = "1" ]; then
    DL+=("$B304|$DRASTIC_SRC" "$B304|$BIOS_ZIP")
fi

DL_DONE=0
DL_TOTAL=${#DL[@]}
for item in "${DL[@]}"; do fetch "${item%%|*}" "${item#*|}"; done

check_elf emulationstation
check_elf FindManager

if [ "$N304" = "1" ]; then
    # drastic.sh ต้องเป็นสคริปต์จริง (ขึ้นต้นด้วย #!) ไม่ใช่หน้า error
    if [ "$(head -c 2 "$STAGE_DIR/$DRASTIC_SRC")" != "#!" ]; then
        say "$DRASTIC_SRC download is not a valid script - nothing was changed."
        fail_exit
    fi
    # แตก BIOS ใน stage (ยังไม่แตะระบบ) แล้วหาโฟลเดอร์ที่มีไฟล์จริง
    BIOS_TMP="$STAGE_DIR/system_x"
    mkdir -p "$BIOS_TMP"
    if ! unzip -q -o "$STAGE_DIR/$BIOS_ZIP" -d "$BIOS_TMP"; then
        say "$BIOS_ZIP is not a valid zip - nothing was changed."
        fail_exit
    fi
    BIOS_SRC="$BIOS_TMP"
    if [ "$(ls -A "$BIOS_TMP" | wc -l)" = "1" ] && [ -d "$BIOS_TMP/$(ls -A "$BIOS_TMP")" ]; then
        BIOS_SRC="$BIOS_TMP/$(ls -A "$BIOS_TMP")"     # zip ห่อด้วยโฟลเดอร์เดียว (เช่น system/)
    fi
    if [ -z "$(ls -A "$BIOS_SRC")" ]; then
        say "$BIOS_ZIP is empty - nothing was changed."
        fail_exit
    fi
fi

ts="$(date +%Y%m%d%H%M%S)"

# ==========================================
# 1. ของรุ่นนี้: EmulationStation + FindManager
# ==========================================
say "Updating EmulationStation... 50%"
install_bin emulationstation "$ES_BIN" ark:ark
echo ">> ES: $(stat -c '%U:%G %a' "$ES_BIN") $ES_BIN"

say "Updating FindManager... 58%"
install_bin FindManager "$FM_DEST" ark:ark

# ==========================================
# 2. ชุดของรุ่นก่อนที่เครื่องนี้ยังไม่มี
# ==========================================
if [ "$N302" = "1" ]; then
    say "Updating system configuration... 64%"
    mkdir -p "$(dirname "$ES_SYSTEMS_DEST")"
    [ -f "$ES_SYSTEMS_DEST" ] && cp -f "$ES_SYSTEMS_DEST" "$ES_SYSTEMS_DEST.bak.$ts"
    cp -f "$STAGE_DIR/es_systems.cfg" "$ES_SYSTEMS_DEST"
    chown root:root "$ES_SYSTEMS_DEST"
    chmod 644 "$ES_SYSTEMS_DEST"

    say "Updating apps... 68%"
    mkdir -p /opt /opt/system
    unzip -X -o "$STAGE_DIR/apps.zip" -d /opt \
        || { say "Failed to install apps - please retry the update."; exit 1; }
    chown -R ark:ark /opt/apps
    find /opt/apps -type f -name '*.sh' -exec chmod +x {} +

    cp -f "$STAGE_DIR/playos-logo.png" "$LOGO_DEST"
    chown ark:ark "$LOGO_DEST"
    chmod 644 "$LOGO_DEST"
fi

if [ "$N303" = "1" ]; then
    say "Updating RetroArch config... 74%"
    install_ra
    say "Updating PlayPod... 78%"
    install_playpod
fi

if [ "$N304" = "1" ]; then
    say "Updating DraStic... 84%"
    DRASTIC_OWNER=$(stat -c '%U:%G' "$DRASTIC_DEST" 2>/dev/null || echo "ark:ark")
    install_bin "$DRASTIC_SRC" "$DRASTIC_DEST" "$DRASTIC_OWNER"

    say "Installing BIOS files... 90%"
    mkdir -p "$BIOS_DIR"
    cp -rf "$BIOS_SRC"/. "$BIOS_DIR"/ \
        || { say "Failed to install BIOS files - please retry the update."; exit 1; }
    chown -R ark:ark "$BIOS_DIR" 2>/dev/null
    echo ">> BIOS installed to $BIOS_DIR"
fi

# ==========================================
# 3. ประทับเวอร์ชัน (ท้ายสุด)
# ==========================================
say "Finishing... 96%"
if [ "$MODE" = "X" ]; then STAMP="$STAMP_X"; else STAMP="$STAMP_30"; fi
cat > "$INFO_FILE" <<EOT
VERSION="$STAMP"
BUILD="$NEW_BUILD"
EOT

rm -rf "$STAGE_DIR"
say "Update completed! (PLAY OS v$STAMP) Restarting... 100%"
sleep 3
exit 187
