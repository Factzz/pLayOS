#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update (รวม 2 สาย เลือกอัตโนมัติจาก VERSION ในเครื่อง)
#
# สาย 3.0 (ไม่มีวงเล็บ)  ->  3.0.3  build 261104   [เหมือนเดิม]
#   โฟลเดอร์ 261104/3.0 : retroarch cfg (64/32) + playpod -> /opt/play_pod
#   ดึง emulationstation + FindManager จากเวอร์ชันก่อน (261030)
#   เครื่องที่ต่ำกว่า 3.0.2 (build 261030) ได้ชุด 3.0.2 ตามไปด้วย
#   (es_systems.cfg, apps.zip, logo จาก 261030)
#   รับ 3.0.1 และ 3.0.2  /  3.0.3 ขึ้นไปทุกบิลด์ = ยกเลิก
#
# สาย X (มี "(X)" ต่อท้าย)  ->  3.0.4(X)  build 261106
#   โฟลเดอร์ 261106 : drastic.sh -> /usr/local/bin (ทับของเดิม)
#                     system.zip -> แตกแล้วเอาไฟล์ BIOS ไปวางที่ <ROMS>/bios
#   เครื่องที่ต่ำกว่า 3.0.3(X) build 261104 ได้ชุด 3.0.3(X) ตามไปด้วย
#   (retroarch cfg 64/32 + playpod จาก 261104/X)
#   รับ 3.0.2(X) และ 3.0.3(X)  /  3.0.4(X) ขึ้นไปทุกบิลด์ = ยกเลิก
#
# สายวงเล็บอื่น, 3.0.0, สายที่ไม่ใช่ 3.0.x -> ยกเลิก
#
# แถบหลอดบนหน้าจอ: บรรทัดที่ขึ้นต้นด้วย ">>" คือข้อความสถานะ
#   ถ้ามี "NN%" ในบรรทัด แถบจะเลื่อนตามเปอร์เซ็นต์จริง
#
# โครงไฟล์บน repo
#   .../main/261106/     drastic.sh, system.zip            (สาย X)
#   .../main/261104/3.0/ retroarch.cfg, retroarch-core-options.cfg, playpod,
#                        32/retroarch.cfg, 32/retroarch-core-options.cfg
#   .../main/261104/X/   (ชุดเดียวกัน ใช้กับเครื่อง X ที่ข้ามมาจาก 3.0.2(X))
#   .../main/261030/     emulationstation, FindManager (+ es_systems.cfg, apps.zip,
#                        playos-logo.png สำหรับเครื่อง 3.0 ที่ข้ามจาก 3.0.1)
# ==========================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

INFO_FILE="/opt/system/playos_info.cfg"
CURRENT_VERSION_RAW=$(grep -m1 '^VERSION=' "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)
CURRENT_BUILD=$(grep -m1 '^BUILD=' "$INFO_FILE" 2>/dev/null | cut -d'"' -f2 | tr -cd '0-9')

# ----- สาย 3.0 -----
V30_VERSION="3.0.3"; V30_BUILD=261104
V30_MIN="3.0.1"                   # สาย 3.0 ต้องเป็น 3.0.1 ขึ้นไป
V30_PREV_VERSION="3.0.2"; V30_PREV_BUILD=261030   # ต่ำกว่านี้ -> เอาชุด 3.0.2 ตามไปด้วย
# ----- สาย X -----
VX_VERSION="3.0.4"; VX_BUILD=261106; VX_STAMP="3.0.4(X)"
VX_MIN="3.0.2"                    # สาย X ต้องเป็น 3.0.2(X) ขึ้นไป
VX_PREV_VERSION="3.0.3"; VX_PREV_BUILD=261104     # ต่ำกว่านี้ -> เอาชุด 3.0.3(X) ตามไปด้วย

REPO="https://raw.githubusercontent.com/Factzz/pLayOS/main"
R30_NEW="$REPO/261104/3.0"
R30_PREV="$REPO/261030"           # es + find (และชุด 3.0.2)
RX_NEW="$REPO/261106"             # drastic.sh + system.zip
RX_PREV="$REPO/261104/X"          # ชุด 3.0.3(X)

PLAYPOD_SRC="playpod"             # ชื่อไฟล์บน repo
PLAYPOD_DEST="/opt/play_pod/playpod"
DRASTIC_SRC="drastic.sh"
DRASTIC_DEST="/usr/local/bin/drastic.sh"
BIOS_ZIP="system.zip"
ROMS_CANDIDATES=("/roms" "/PLAYROMS" "/mnt/PLAYROMS" "/media/PLAYROMS")

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
LOG_FILE="/home/ark/PLAYOS-update-$VX_BUILD.log"
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

# ---------- เลือกโหมด: MODE=3.0|X|cancel (+ EXTRAS=1 ถ้าต้องเอาชุดรุ่นก่อนตามไปด้วย) ----------
decide_30() {
    if ver_lt "$V30_VERSION" "$VERSION_BASE"; then
        CANCEL_MSG="Version $VERSION_BASE is newer than $V30_VERSION. Update canceled."; return
    fi
    if [ "$VERSION_BASE" = "$V30_VERSION" ]; then
        CANCEL_MSG="Already on v$V30_VERSION (build $CURRENT_BUILD). Update canceled."; return
    fi
    if ver_lt "$VERSION_BASE" "$V30_MIN"; then
        CANCEL_MSG="Version $VERSION_BASE is older than $V30_MIN. Update canceled."; return
    fi
    MODE="3.0"
    if ver_lt "$VERSION_BASE" "$V30_PREV_VERSION" || \
       { [ "$VERSION_BASE" = "$V30_PREV_VERSION" ] && [ "$CURRENT_BUILD" -lt "$V30_PREV_BUILD" ]; }; then
        EXTRAS=1
    fi
}

decide_x() {
    if [ "$VERSION_BASE" = "$VX_VERSION" ]; then
        CANCEL_MSG="Already on v$VX_VERSION(X) (build $CURRENT_BUILD). Update canceled."; return
    fi
    if ver_lt "$VX_VERSION" "$VERSION_BASE"; then
        CANCEL_MSG="Version $VERSION_BASE is newer than $VX_VERSION. Update canceled."; return
    fi
    if ver_lt "$VERSION_BASE" "$VX_MIN"; then
        CANCEL_MSG="Version $VERSION_BASE is older than $VX_MIN. Update canceled."; return
    fi
    MODE="X"
    if ver_lt "$VERSION_BASE" "$VX_PREV_VERSION" || \
       { [ "$VERSION_BASE" = "$VX_PREV_VERSION" ] && [ "$CURRENT_BUILD" -lt "$VX_PREV_BUILD" ]; }; then
        EXTRAS=1
    fi
}

decide_mode() {
    MODE="cancel"; EXTRAS=0
    if [ "$VERSION_MAJOR_MINOR" != "$REQUIRED_MAJOR_MINOR" ]; then
        CANCEL_MSG="This update only applies to $REQUIRED_MAJOR_MINOR.x (yours: ${VERSION_BASE:-UNKNOWN}). Update canceled."; return
    fi
    if [ -z "$VERSION_TAG" ]; then
        decide_30
    elif [ "$VERSION_TAG" = "X" ]; then
        decide_x
    else
        CANCEL_MSG="This device is on the '$VERSION_TAG' variant track. Update canceled."
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

stamp_version() {  # ประทับเวอร์ชัน (ท้ายสุด)
    cat > "$INFO_FILE" <<EOT
VERSION="$1"
BUILD="$2"
EOT
}

# ==========================================================
#  สาย 3.0  ->  3.0.3 / 261104
# ==========================================================
run_30() {
    say "Preparing update files... 5%"
    rm -rf "$STAGE_DIR"; mkdir -p "$STAGE_DIR/32"

    DL_DONE=0
    DL_TOTAL=$(( ${#RA_FILES[@]} + 1 + 2 ))
    [ "$EXTRAS" = "1" ] && DL_TOTAL=$(( DL_TOTAL + 3 ))

    fetch "$R30_PREV" emulationstation; check_elf emulationstation
    fetch "$R30_PREV" FindManager;      check_elf FindManager
    if [ "$EXTRAS" = "1" ]; then
        fetch "$R30_PREV" es_systems.cfg
        fetch "$R30_PREV" apps.zip
        fetch "$R30_PREV" playos-logo.png
    fi
    local entry
    for entry in "${RA_FILES[@]}"; do fetch "$R30_NEW" "${entry%%|*}"; done
    fetch "$R30_NEW" "$PLAYPOD_SRC"

    ts="$(date +%Y%m%d%H%M%S)"

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

    say "Updating RetroArch config... 78%"
    install_ra
    say "Updating PlayPod... 88%"
    install_playpod

    say "Finishing... 96%"
    stamp_version "$V30_VERSION" "$V30_BUILD"
    rm -rf "$STAGE_DIR"
    say "Update completed! (PLAY OS v$V30_VERSION) Restarting... 100%"
    sleep 3
    exit 187
}

# ==========================================================
#  สาย X  ->  3.0.4(X) / 261106
# ==========================================================
run_x() {
    say "Preparing update files... 5%"
    if ! find_bios_dir; then
        say "ROMS partition not found (checked: ${ROMS_CANDIDATES[*]}) - nothing was changed."
        sleep 3; exit 1
    fi
    echo "[bios dir] $BIOS_DIR"

    rm -rf "$STAGE_DIR"; mkdir -p "$STAGE_DIR/32"

    DL_DONE=0
    DL_TOTAL=2
    [ "$EXTRAS" = "1" ] && DL_TOTAL=$(( DL_TOTAL + ${#RA_FILES[@]} + 1 ))

    local entry
    if [ "$EXTRAS" = "1" ]; then
        for entry in "${RA_FILES[@]}"; do fetch "$RX_PREV" "${entry%%|*}"; done
        fetch "$RX_PREV" "$PLAYPOD_SRC"
    fi
    fetch "$RX_NEW" "$DRASTIC_SRC"
    fetch "$RX_NEW" "$BIOS_ZIP"

    # drastic.sh ต้องเป็นสคริปต์จริง (ขึ้นต้นด้วย #!) ไม่ใช่หน้า error
    if [ "$(head -c 2 "$STAGE_DIR/$DRASTIC_SRC")" != "#!" ]; then
        say "$DRASTIC_SRC download is not a valid script - nothing was changed."
        fail_exit
    fi

    # แตก BIOS ใน stage (ยังไม่แตะระบบ) แล้วหาโฟลเดอร์ที่มีไฟล์จริง
    local BIOS_TMP="$STAGE_DIR/system_x" BIOS_SRC
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

    ts="$(date +%Y%m%d%H%M%S)"

    if [ "$EXTRAS" = "1" ]; then
        say "Updating RetroArch config... 55%"
        install_ra
        say "Updating PlayPod... 62%"
        install_playpod
    fi

    say "Updating DraStic... 72%"
    mkdir -p "$(dirname "$DRASTIC_DEST")"
    local DRASTIC_OWNER
    DRASTIC_OWNER=$(stat -c '%U:%G' "$DRASTIC_DEST" 2>/dev/null || echo "ark:ark")
    [ -f "$DRASTIC_DEST" ] && cp -f "$DRASTIC_DEST" "$DRASTIC_DEST.bak.$ts"
    cp -f "$STAGE_DIR/$DRASTIC_SRC" "$DRASTIC_DEST.new" \
        && chown "$DRASTIC_OWNER" "$DRASTIC_DEST.new" \
        && chmod 755 "$DRASTIC_DEST.new" \
        && mv -f "$DRASTIC_DEST.new" "$DRASTIC_DEST" \
        || { rm -f "$DRASTIC_DEST.new"; say "Failed to install DraStic - please retry the update."; exit 1; }

    say "Installing BIOS files... 84%"
    mkdir -p "$BIOS_DIR"
    cp -rf "$BIOS_SRC"/. "$BIOS_DIR"/ \
        || { say "Failed to install BIOS files - please retry the update."; exit 1; }
    chown -R ark:ark "$BIOS_DIR" 2>/dev/null
    echo ">> BIOS installed to $BIOS_DIR"

    say "Finishing... 96%"
    stamp_version "$VX_STAMP" "$VX_BUILD"
    rm -rf "$STAGE_DIR"
    say "Update completed! (PLAY OS v$VX_STAMP) Restarting... 100%"
    sleep 3
    exit 187
}

if [ "$MODE" = "X" ]; then run_x; else run_30; fi
