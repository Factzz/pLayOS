#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update v3.0.2
# Build: 261030
# Track: STANDARD (3.0.x) only
#   - รับเฉพาะ 3.0.x ที่ต่ำกว่า 3.0.2 (build < 261030)
#   - ปฏิเสธสายวงเล็บ เช่น 3.0(X) และเวอร์ชันที่สูงกว่า 3.0.2
#
# สิ่งที่อัปเดต:
#   dArkOSen (เฉพาะหลังบ้าน - ตัดธีม/โลโก้/BMP/ภาพ ออกทั้งหมด)
#   ES ใหม่ของ PLAY OS, es_systems.cfg (ย้ายแอปไป /opt), RetroArch config (64/32)
#
# โครงไฟล์บน repo  .../main/261030/
#   emulationstation                    -> /usr/bin/emulationstation/emulationstation (ark:ark)
#   es_systems.cfg                      -> /etc/emulationstation/es_systems.cfg
#   apps.zip  (มีโฟลเดอร์ apps/ ข้างใน)   -> /opt/apps
#   FindManager (ไฟล์โปรแกรมเดี่ยว)        -> /opt/FindManager_Data/FindManager
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

# ---------- dArkOSen ----------
DARKOSEN_LOCATION="https://raw.githubusercontent.com/djparentx/dArkOSen-updates/main"
DARKOSEN_UPDATES="07202026 07272026 07312026 08152026 08312026 09162026 09302026 09302026b"

# แพ็กเกจของ dArkOSen: ไฟล์ที่ตรงกับ pattern เหล่านี้จะไม่ถูกแตกลงเครื่อง (หน้าบ้าน: ธีม/โลโก้/ภาพ)
UNZIP_EXCLUDE=(
    "*.bmp" "*.BMP" "*.jpg" "*.JPG" "*.jpeg" "*.png" "*.PNG"
    "*launchimages/*" "*/BMPs/*" "*themes/*" "*logo*" "*Logo*"
    "opt/apps/*" "opt/FindManager_Data/*"   # ของเรา
    "opt/system/*"      # สคริปต์/เมนูใน /opt/system (รวมโฟลเดอร์ System) ใช้ของเราเอง ไม่รับจาก dArkOSen
)

# ของเราที่ห้ามถูก dArkOSen ทับ (รองรับ glob) - สำรองก่อน แล้วคืนหลังแต่ละรุ่น
ES_BIN="/usr/bin/emulationstation/emulationstation"
ES_SYSTEMS_DEST="/etc/emulationstation/es_systems.cfg"
PROTECT_PATHS=(
    "$ES_BIN"
    "$ES_SYSTEMS_DEST"
    "/etc/emulationstation/themes"
    "/boot/BMPs"
    "/boot/*.bmp"
    "/roms/launchimages"
    "/opt/system"
)
# โฟลเดอร์ที่ต้องย้อนกลับเหมือนเดิมเป๊ะ (ไฟล์ที่ dArkOSen เพิ่มใหม่จะถูกลบทิ้งด้วย)
PROTECT_RESET_DIRS=( "/opt/system" )
PROTECT_DIR="/home/ark/.playos_protect"
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

if command -v msgbox >/dev/null 2>&1; then
    msgbox "DO NOT STOP THIS UPDATE UNTIL IT FINISHES. Make a backup of this SD card first. The system may restart during the update; if so, run this update again until it reports completed."
fi

# ==========================================
# 0. ดาวน์โหลดไฟล์ของ PLAY OS ทั้งหมดก่อน (พลาด = ยังไม่แตะระบบเลย)
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
for entry in "${RA_FILES[@]}"; do fetch "${entry%%|*}"; done

# ==========================================
# ฟังก์ชันป้องกันไฟล์ของเรา
# ==========================================
protect_backup() {
    rm -rf "$PROTECT_DIR"; mkdir -p "$PROTECT_DIR"
    local pat p
    shopt -s nullglob
    for pat in "${PROTECT_PATHS[@]}"; do
        for p in $pat; do
            if [ -e "$p" ]; then
                mkdir -p "$PROTECT_DIR$(dirname "$p")"
                cp -a "$p" "$PROTECT_DIR$p"
            fi
        done
    done
    shopt -u nullglob
}

protect_restore() {
    local f p
    while IFS= read -r f; do
        p="${f#$PROTECT_DIR}"
        rm -rf "$p"
        mkdir -p "$(dirname "$p")"
        cp -a "$f" "$p"
    done < <(find "$PROTECT_DIR" -mindepth 1 \( -type f -o -type l \) 2>/dev/null | sort)
    local d
    for d in "${PROTECT_RESET_DIRS[@]}"; do
        while IFS= read -r f; do
            [ -e "$PROTECT_DIR$f" ] || rm -f "$f"
        done < <(find "$d" \( -type f -o -type l \) 2>/dev/null)
    done
}

# ==========================================
# 1. dArkOSen (หลังบ้านเท่านั้น)
# ==========================================
run_darkosen_update() {
    local id="$1"
    local marker="/home/ark/.config/.dArkOSen-update$id"
    local zip="/dev/shm/dArkOSen-update$id.zip"

    [ -f "$marker" ] && return 0
    say "Updating core system ($id)..."

    if [ "$id" = "07312026" ] && [ ! -f "/home/ark/.config/.update07262026" ]; then
        command -v msgbox >/dev/null 2>&1 && msgbox "The system will update dArkOS first. Run this update again after reboot to complete all updates."
        bash /opt/system/System/Update.sh
        exit 1
    fi

    rm -rf /dev/shm/*
    wget -t 3 -T 60 --no-check-certificate "$DARKOSEN_LOCATION/$id/dArkOSen-update$id.zip" -O "$zip"
    if [ ! -s "$zip" ]; then
        say "Download failed ($id). Please retry the update."
        rm -f "$zip"; sleep 3; exit 1
    fi

    systemctl stop ogage.service 2>/dev/null

    # pre-cleanup (ไม่แตะ /opt/system และส่วนหน้าบ้าน)
    case "$id" in
        07272026)
            rm -f "/boot/dtb/r36s/R36S-Plus-V20 2025-03-18 2551/rg351mp-kernel.dtb"
            ;;
    esac

    protect_backup
    unzip -X -o "$zip" -d / -x "${UNZIP_EXCLUDE[@]}"
    sleep 1

    if [ "$id" = "07202026" ]; then
        bash /tmp/fix_fstab.sh
        bash /tmp/patch_dtb_battery.sh
    fi
    [ -f "/tmp/$id.sh" ] && bash "/tmp/$id.sh"

    protect_restore
    touch "$marker"

    if [ "$id" = "07202026" ]; then
        bash /tmp/flash_uboot.sh
        sleep 1
        command -v msgbox >/dev/null 2>&1 && msgbox "A reboot is required. Run this update again after restart to finish. System will restart after you press A."
        reboot
        exit 0
    fi
}

for id in $DARKOSEN_UPDATES; do
    run_darkosen_update "$id"
done
rm -f /dev/shm/dArkOSen-update*.zip

# ==========================================
# 2. EmulationStation ใหม่ของเรา
# ==========================================
say "Updating EmulationStation..."
mkdir -p "$(dirname "$ES_BIN")"
if [ -f "$ES_BIN" ]; then
    cp -f "$ES_BIN" "$ES_BIN.bak.$(date +%Y%m%d%H%M%S)"
    chown ark:ark "$ES_BIN".bak.* 2>/dev/null
fi
cp -f "$STAGE_DIR/emulationstation" "$ES_BIN"
chown ark:ark "$ES_BIN"      # ต้องเป็น ark:ark ห้าม root
chmod 755 "$ES_BIN"
echo ">> ES: $(stat -c '%U:%G %a' "$ES_BIN") $ES_BIN"

# ==========================================
# 3. es_systems.cfg (วางทับของเดิม)
# ==========================================
say "Updating system configuration..."
mkdir -p "$(dirname "$ES_SYSTEMS_DEST")"
[ -f "$ES_SYSTEMS_DEST" ] && cp -f "$ES_SYSTEMS_DEST" "$ES_SYSTEMS_DEST.bak.$(date +%Y%m%d%H%M%S)"
cp -f "$STAGE_DIR/es_systems.cfg" "$ES_SYSTEMS_DEST"
chown root:root "$ES_SYSTEMS_DEST"; chmod 644 "$ES_SYSTEMS_DEST"

# ==========================================
# 4. RetroArch config (64 + 32)
# ==========================================
say "Updating RetroArch config..."
ts="$(date +%Y%m%d%H%M%S)"
for entry in "${RA_FILES[@]}"; do
    src="${entry%%|*}"; dest="${entry#*|}"
    mkdir -p "$(dirname "$dest")"
    [ -f "$dest" ] && cp -f "$dest" "$dest.bak.$ts"
    cp -f "$STAGE_DIR/$src" "$dest"
    chown ark:ark "$dest"; chmod 644 "$dest"
    echo ">> installed $dest"
done

# ==========================================
# 5. apps (/opt/apps) และ FindManager (/opt/FindManager_Data)
# ==========================================
say "Updating apps..."
mkdir -p /opt /opt/FindManager_Data
unzip -X -o "$STAGE_DIR/apps.zip" -d /opt \
    || { say "Failed to install apps - please retry the update."; exit 1; }
chown -R ark:ark /opt/apps
find /opt/apps -type f -name '*.sh' -exec chmod +x {} +

FM_DEST="/opt/FindManager_Data/FindManager"
[ -f "$FM_DEST" ] && cp -f "$FM_DEST" "$FM_DEST.bak.$(date +%Y%m%d%H%M%S)"
cp -f "$STAGE_DIR/FindManager" "$FM_DEST" \
    || { say "Failed to install FindManager - please retry the update."; exit 1; }
chown ark:ark "$FM_DEST"
chmod 755 "$FM_DEST"

# ==========================================
# 6. ประทับเวอร์ชัน (ท้ายสุด)
# ==========================================
cat > "$INFO_FILE" <<EOT
VERSION="$NEW_VERSION"
BUILD="$NEW_BUILD"
EOT

rm -rf "$STAGE_DIR" "$PROTECT_DIR"
say "Update completed! (PLAY OS v$NEW_VERSION) Restarting..."
sleep 3
exit 187
