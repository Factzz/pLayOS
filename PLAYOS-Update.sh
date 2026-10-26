#!/bin/bash
# ==========================================================
# PLAY OS - OTA Patch : PPSSPP
# Track: 4.0(X) (เครื่องโคลน) เท่านั้น  build 261201
#
# อัปเดตเฉพาะ PPSSPP  -- ไม่เปลี่ยนเวอร์ชัน/บิลด์ (ยังเป็น 4.0(X) / 261201)
#   ppsspp.zip       -> /opt/ppsspp        (ลบของเดิมแล้ววางใหม่ ไม่วางทับ)
#   ppsspp-2021.zip  -> /opt/ppsspp-2021   (ลบของเดิมแล้ววางใหม่ ไม่วางทับ)
#   แล้วตั้งสิทธิ์: chmod +x <dir>/PPSSPPSDL และ chmod -R 755 <dir>
#
# เครื่องที่ไม่ใช่ 4.0(X) build 261201 (เช่น 4.0 เครื่องแท้, 4.0 RG EDITION,
# สาย 3.x) -> ยกเลิก ไม่แตะอะไรเลย
# รันซ้ำได้: ถ้าไฟล์เหมือนที่ติดตั้งล่าสุดแล้ว จะขึ้น "already the latest" แล้วข้าม
#
# แถบหลอดบนหน้าจอ: บรรทัดที่ขึ้นต้นด้วย ">>" คือข้อความสถานะ
#   ถ้ามี "NN%" ในบรรทัด แถบจะเลื่อนตามเปอร์เซ็นต์จริง
#
# ไฟล์อยู่ที่ GitHub Release  https://github.com/Factzz/pLayOS/releases/tag/PPSSPP
#   ppsspp.zip        (จะมีไฟล์ในราก หรือห่อด้วยโฟลเดอร์เดียว เช่น ppsspp/ ก็ได้)
#   ppsspp-2021.zip   (เหมือนกัน)
#   ข้างในต้องมีไฟล์ PPSSPPSDL
#
# ไฟล์ใหญ่เกิน 25MB (ข้อจำกัดอัปโหลดผ่านหน้าเว็บ GitHub) -> แบ่งเป็นชิ้นได้
#   ppsspp.zip.001, ppsspp.zip.002, ppsspp.zip.003, ...   (เลขต่อเนื่อง 3 หลัก เริ่มที่ 001)
#   ถ้ามี ppsspp.zip ไฟล์เดียวจะใช้ไฟล์นั้น ถ้าไม่มีจะโหลดชิ้นต่อกันจนหมดแล้วประกอบเอง
#   วิธีแบ่ง (Linux/Mac/WSL):
#     split -b 20m -d -a 3 --numeric-suffixes=1 ppsspp.zip ppsspp.zip.
#   (Windows: 7-Zip > Add to archive > Split to volumes = 20M จะได้ .zip.001, .zip.002 ...)
# ==========================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

INFO_FILE="/opt/system/playos_info.cfg"
CURRENT_VERSION_RAW=$(grep -m1 '^VERSION=' "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)
CURRENT_BUILD=$(grep -m1 '^BUILD=' "$INFO_FILE" 2>/dev/null | cut -d'"' -f2 | tr -cd '0-9')

REQUIRED_VERSION="4.0(X)"
REQUIRED_BUILD=261201

URL_BASE="https://github.com/Factzz/pLayOS/releases/download/PPSSPP"   # GitHub Release (tag: PPSSPP)
PKGS=("ppsspp" "ppsspp-2021")     # ชื่อ = ชื่อโฟลเดอร์ใน /opt = ชื่อ zip (ไม่รวม .zip)
OPT_DIR="/opt"
STATE_FILE="/opt/system/ppsspp_patch.sha256"
STAGE_DIR="/home/ark/.playos_stage"

# ---------- log: รายละเอียดลงไฟล์ / หน้าจอแสดงแค่สถานะสั้นๆ ----------
LOG_FILE="/home/ark/PLAYOS-update-$REQUIRED_BUILD.log"
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
df -h "$OPT_DIR" /home/ark 2>&1 | tail -n 2
free -m 2>&1 | sed -n 2p

[ -z "$CURRENT_BUILD" ] && CURRENT_BUILD=0

say "PLAY OS Updater - current: ${CURRENT_VERSION_RAW:-unknown} (build $CURRENT_BUILD) 2%"

# 🛡️ ต้องเป็น 4.0(X) เท่านั้น
if [ "$CURRENT_VERSION_RAW" != "$REQUIRED_VERSION" ]; then
    say "This update is only for v$REQUIRED_VERSION (yours: ${CURRENT_VERSION_RAW:-UNKNOWN}). Update canceled."
    sleep 3; exit 0
fi
# 🛡️ และต้องเป็น build 261201 (กันเขียนทับเครื่องที่ใหม่กว่า)
if [ "$CURRENT_BUILD" -ne "$REQUIRED_BUILD" ]; then
    say "This update is only for build $REQUIRED_BUILD (yours: $CURRENT_BUILD). Update canceled."
    sleep 3; exit 0
fi

# ---------- ฟังก์ชัน ----------
cleanup_tmp() { rm -rf "$OPT_DIR"/.pp_new_* "$OPT_DIR"/.pp_old_* 2>/dev/null; }
fail_exit() { rm -rf "$STAGE_DIR"; cleanup_tmp; sleep 3; exit 1; }

PKG_IDX=0
try_get() {  # try_get <ชื่อบน repo> <ไฟล์ปลายทาง> : ตั้ง GOT=1 ถ้าได้ไฟล์ / MISSING=1 ถ้า repo ตอบ 404
    local outtxt
    GOT=0; MISSING=0
    outtxt=$(wget -nv -t 3 -T 60 -O "$2" "$URL_BASE/$1" 2>&1)
    echo "[$(date +%T)] wget $1 rc=$? size=$(stat -c %s "$2" 2>/dev/null) $outtxt" | tail -n 3
    if [ -s "$2" ]; then GOT=1; return; fi
    rm -f "$2"
    echo "$outtxt" | grep -q "ERROR 404" && MISSING=1
}

fetch_pkg() {  # fetch_pkg <ชื่อแพ็กเกจ> : ได้ $STAGE_DIR/<ชื่อ>.zip (ไฟล์เดียว หรือประกอบจากชิ้น .001 .002 ...)
    local p="$1" out="$STAGE_DIR/$1.zip" n=1 part pct
    local base=$((5 + PKG_IDX * 20))

    say "Downloading $p.zip... ${base}%"
    try_get "$p.zip" "$out"
    if [ "$GOT" = "1" ]; then PKG_IDX=$((PKG_IDX + 1)); return; fi
    if [ "$MISSING" != "1" ]; then
        say "FAILED to download $p.zip - nothing was changed."
        fail_exit
    fi

    # ไม่มีไฟล์เดียว -> ลองโหลดแบบแบ่งชิ้น
    : > "$out"
    while [ "$n" -le 99 ]; do
        part=$(printf '%s.zip.%03d' "$p" "$n")
        pct=$((base + n * 2)); [ "$pct" -gt $((base + 18)) ] && pct=$((base + 18))
        say "Downloading $part... ${pct}%"
        try_get "$part" "$STAGE_DIR/$part"
        if [ "$GOT" = "1" ]; then
            cat "$STAGE_DIR/$part" >> "$out" && rm -f "$STAGE_DIR/$part"
            n=$((n + 1))
        elif [ "$MISSING" = "1" ] && [ "$n" -gt 1 ]; then
            break                                   # หมดชิ้นแล้ว
        elif [ "$MISSING" = "1" ]; then
            say "FAILED: $p.zip not found on server - nothing was changed."
            fail_exit
        else
            say "FAILED to download $part - nothing was changed."
            fail_exit
        fi
    done
    echo "[parts] $p: $((n - 1)) part(s) -> $(stat -c %s "$out") bytes"
    PKG_IDX=$((PKG_IDX + 1))
}

# ==========================================
# 0. ดาวน์โหลดและตรวจให้ครบก่อน (พลาด = ยังไม่แตะของเดิมเลย)
# ==========================================
say "Preparing update files... 5%"
rm -rf "$STAGE_DIR"; mkdir -p "$STAGE_DIR"
cleanup_tmp

for p in "${PKGS[@]}"; do fetch_pkg "$p"; done

say "Verifying files... 48%"
HASH=""
for p in "${PKGS[@]}"; do
    if ! unzip -tq "$STAGE_DIR/$p.zip" >/dev/null 2>&1; then
        say "$p.zip is not a valid zip - nothing was changed."
        fail_exit
    fi
    HASH="$HASH$(sha256sum "$STAGE_DIR/$p.zip" | cut -d' ' -f1)  $p.zip"$'\n'
done

# เหมือนที่ติดตั้งไว้ล่าสุดแล้ว (และโฟลเดอร์ยังครบ) -> ข้าม
ALL_OK=1
for p in "${PKGS[@]}"; do [ -x "$OPT_DIR/$p/PPSSPPSDL" ] || ALL_OK=0; done
if [ "$ALL_OK" = "1" ] && [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "${HASH%$'\n'}" ]; then
    rm -rf "$STAGE_DIR"
    say "PPSSPP is already the latest. 100%"
    sleep 3; exit 0
fi

# ==========================================
# 1. แตกไฟล์ไปไว้ข้างๆ ก่อน (ยังไม่ลบของเดิม) แล้วตรวจว่ามี PPSSPPSDL จริง
# ==========================================
declare -A NEW_ROOT
pct=52
for p in "${PKGS[@]}"; do
    say "Unpacking $p... ${pct}%"
    tmp="$OPT_DIR/.pp_new_$p"
    rm -rf "$tmp"; mkdir -p "$tmp"
    if ! unzip -q -o "$STAGE_DIR/$p.zip" -d "$tmp"; then
        say "Failed to unpack $p.zip (disk full?) - nothing was changed."
        fail_exit
    fi
    root="$tmp"
    if [ "$(ls -A "$tmp" | wc -l)" = "1" ] && [ -d "$tmp/$(ls -A "$tmp")" ]; then
        root="$tmp/$(ls -A "$tmp")"       # zip ห่อด้วยโฟลเดอร์เดียว (เช่น ppsspp/)
    fi
    if [ ! -f "$root/PPSSPPSDL" ]; then
        say "$p.zip has no PPSSPPSDL inside - nothing was changed."
        fail_exit
    fi
    NEW_ROOT[$p]="$root"
    pct=$((pct + 10))
done
rm -rf "$STAGE_DIR"      # คืนพื้นที่ zip

# ==========================================
# 2. ลบของเดิม แล้ววางอันใหม่ (สลับโฟลเดอร์ ถ้าพลาดจะคืนของเดิม)
# ==========================================
pct=76
for p in "${PKGS[@]}"; do
    say "Installing $p... ${pct}%"
    dest="$OPT_DIR/$p"; old="$OPT_DIR/.pp_old_$p"
    owner=$(stat -c '%U:%G' "$dest" 2>/dev/null || echo "ark:ark")
    rm -rf "$old"
    [ -e "$dest" ] && mv "$dest" "$old"
    if ! mv "${NEW_ROOT[$p]}" "$dest"; then
        [ -e "$old" ] && mv "$old" "$dest"      # คืนของเดิม
        say "Failed to install $p - please retry the update."
        fail_exit
    fi
    chown -R "$owner" "$dest"
    chmod +x "$dest/PPSSPPSDL"
    chmod -R 755 "$dest"
    rm -rf "$old"
    pct=$((pct + 8))
done
cleanup_tmp

# จำว่าติดตั้งชุดไหนไว้ (ใช้ข้ามตอนรันซ้ำ) -- ไม่แตะ VERSION/BUILD
printf '%s' "$HASH" > "$STATE_FILE"

say "Update completed! (PPSSPP updated) Restarting... 100%"
sleep 3
exit 187
