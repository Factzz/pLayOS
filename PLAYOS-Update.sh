#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update  (ตระกูล 4.x)
#
#  [1] 4.0 B  (เครื่องแท้ รุ่นเบต้าทดสอบ)  ->  4.0.1 B   build 261203
#        แพ็กเกจ: GitHub Release tag "4.0B"  (PlayOS4.0-update261203.zip)
#        - แตกแพ็กเกจแล้วคัดลอกไปที่ / (boot, etc, lib/modules, opt, usr/local/bin, home/ark)
#        - ไม่รัน tmp/10312026.sh ของ dArkOSen ในแพ็กเกจ (ทำขั้นตอนที่จำเป็นในสคริปต์นี้แทน)
#        - ไม่แตะ EmulationStation
#        - เพิ่ม dsperate ใน es_systems.cfg + แก้โครงสร้าง (fix_dsperate)
#        - ติดตั้ง OTG_fix.sh ที่ /opt/system/Advanced (ไม่รันอัตโนมัติ)
#        - สำรองไฟล์เดิมที่จะถูกทับ (boot/etc/lib/usr) ไว้ที่ /home/ark/.playos_backup_261203
#          ถ้าคัดลอกพลาดจะคืนของเดิมให้เอง
#        *** ปล่อยจริง: เปลี่ยน B_PATTERN_ANY เป็น '^4\.0(\.[0-9]+)?$' (ดูหมายเหตุในโค้ด) ***
#
#  [2] 4.0 RG EDITION  ->  4.0.1  build 261202                       [เหมือนเดิม]
#        PPSSPP ชุดของ RG (Release: PPSSPPRG) ลบของเดิมแล้ววางใหม่
#
#  เครื่องอื่นทั้งหมด (4.0(X), 4.0 เครื่องแท้ที่ไม่ใช่ B, สาย 3.x, อัปแล้ว, build อื่น)
#     -> ยกเลิก ไม่แตะอะไรเลย
#
# แถบหลอดบนหน้าจอ: บรรทัดที่ขึ้นต้นด้วย ">>" คือข้อความสถานะ
#   ถ้ามี "NN%" ในบรรทัด แถบจะเลื่อนตามเปอร์เซ็นต์จริง
# ==========================================================

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

INFO_FILE="/opt/system/playos_info.cfg"
CURRENT_VERSION_RAW=$(grep -m1 '^VERSION=' "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)
CURRENT_BUILD=$(grep -m1 '^BUILD=' "$INFO_FILE" 2>/dev/null | cut -d'"' -f2 | tr -cd '0-9')

# ===== [2] RG =====
RG_FROM_BUILD=261201              # รับเฉพาะ RG ที่ build นี้
RG_NEW_BASE_VERSION="4.0.1"
RG_NEW_BUILD=261202
URL_RG="https://github.com/Factzz/pLayOS/releases/download/PPSSPPRG"
PKGS=("ppsspp" "ppsspp-2021")     # ชื่อ = ชื่อโฟลเดอร์ใน /opt = ชื่อ zip (ไม่รวม .zip)
OPT_DIR="/opt"

# ===== [1] 4.0 B (เครื่องแท้ เบต้า) =====
B_NEW_BASE_VERSION="4.0.1"
B_NEW_BUILD=261203
# รับ VERSION แบบ "4.0 B" / "4.0B" / "4.0(B)" / "4.0 BETA"  (รวมรุ่นที่อัปแล้ว เช่น "4.0.1 B" ไว้เช็ก "อัปแล้ว")
# >>> ตอนปล่อยจริงให้เปลี่ยนเป็น:  B_PATTERN_ANY='^4\.0(\.[0-9]+)?$'   (เครื่อง "4.0" ธรรมดา)
#     แล้ว VERSION จะถูกประทับเป็น "4.0.1" เอง
B_PATTERN_ANY='^4\.0(\.[0-9]+)?[[:space:]\(_-]*B(ETA)?\)?$'
URL_B="https://github.com/Factzz/pLayOS/releases/download/4.0B"
B_PKG_NAMES=("PlayOS4.0-update261203" "PlayOS4_0-update261203")   # ชื่อไฟล์ zip บน Release (ไม่รวม .zip) ลองตามลำดับ
BACKUP_DIR="/home/ark/.playos_backup_261203"
ES_CFG="/etc/emulationstation/es_systems.cfg"
OTG_DEST="/opt/system/Advanced/OTG_fix.sh"

STAGE_DIR="/home/ark/.playos_stage"

# ---------- log: รายละเอียดลงไฟล์ / หน้าจอแสดงแค่สถานะสั้นๆ ----------
LOG_FILE="/home/ark/PLAYOS-update-$B_NEW_BUILD.log"
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
df -h / /boot /home/ark 2>&1 | tail -n 3
free -m 2>&1 | sed -n 2p

[ -z "$CURRENT_BUILD" ] && CURRENT_BUILD=0

say "PLAY OS Updater - current: ${CURRENT_VERSION_RAW:-unknown} (build $CURRENT_BUILD) 2%"

# ---------- เลือกโหมดจาก VERSION: MODE=B|RG|cancel ----------
VERSION_UC=$(echo "$CURRENT_VERSION_RAW" | tr '[:lower:]' '[:upper:]')
RG_PATTERN='^4\.0(\.[0-9]+)?[[:space:]\(_-]*RG'     # "4.0 RG EDITION", "4.0(RG)", "4.0.1 RG ..."
VERSION_BASE=$(echo "$CURRENT_VERSION_RAW" | grep -oE '^[0-9]+(\.[0-9]+)*')
MODE="cancel"

if [[ "$VERSION_UC" =~ $RG_PATTERN ]]; then
    if [ "$VERSION_BASE" = "$RG_NEW_BASE_VERSION" ] || [ "$CURRENT_BUILD" -ge "$RG_NEW_BUILD" ]; then
        CANCEL_MSG="Already up to date (v$VERSION_BASE, build $CURRENT_BUILD). Update canceled."
    elif [ "$VERSION_BASE" = "4.0" ] && [ "$CURRENT_BUILD" -eq "$RG_FROM_BUILD" ]; then
        MODE="RG"
    else
        CANCEL_MSG="This update is only for 4.0 RG build $RG_FROM_BUILD (yours: $CURRENT_VERSION_RAW, build $CURRENT_BUILD). Update canceled."
    fi
elif [[ "$VERSION_UC" =~ $B_PATTERN_ANY ]]; then
    if [ "$VERSION_BASE" = "$B_NEW_BASE_VERSION" ] || [ "$CURRENT_BUILD" -ge "$B_NEW_BUILD" ]; then
        CANCEL_MSG="Already up to date (v$VERSION_BASE, build $CURRENT_BUILD). Update canceled."
    elif [ "$VERSION_BASE" = "4.0" ]; then
        MODE="B"
    else
        CANCEL_MSG="This update is only for v4.0 (yours: $CURRENT_VERSION_RAW). Update canceled."
    fi
else
    CANCEL_MSG="This update is not available for your version (yours: ${CURRENT_VERSION_RAW:-UNKNOWN}). Update canceled."
fi

if [ "$MODE" = "cancel" ]; then
    say "$CANCEL_MSG"
    sleep 3; exit 0
fi
echo "[mode] $MODE"

# ---------- ฟังก์ชันร่วม ----------
cleanup_tmp() { rm -rf "$OPT_DIR"/.pp_new_* "$OPT_DIR"/.pp_old_* 2>/dev/null; }
fail_exit() { rm -rf "$STAGE_DIR"; cleanup_tmp; sleep 3; exit 1; }

PKG_IDX=0
try_get() {  # try_get <url> <ไฟล์ปลายทาง> : ตั้ง GOT=1 ถ้าได้ไฟล์ / MISSING=1 ถ้าเซิร์ฟเวอร์ตอบ 404
    local outtxt
    GOT=0; MISSING=0
    outtxt=$(wget -nv -t 3 -T 60 -O "$2" "$1" 2>&1)
    echo "[$(date +%T)] wget ${1##*/} rc=$? size=$(stat -c %s "$2" 2>/dev/null) $outtxt" | tail -n 3
    if [ -s "$2" ]; then GOT=1; return; fi
    rm -f "$2"
    echo "$outtxt" | grep -q "ERROR 404" && MISSING=1
}

# fetch_pkg <url-base> <ชื่อแพ็กเกจ> [optional]
#   ได้ $STAGE_DIR/<ชื่อ>.zip  (ไฟล์เดียว หรือประกอบจากชิ้น .001 .002 ... ถ้าไม่มีไฟล์เดียว)
#   optional: ถ้าไม่พบบนเซิร์ฟเวอร์ คืนค่า 1 (ไม่หยุดสคริปต์)
fetch_pkg() {
    local ub="$1" p="$2" opt="$3" out="$STAGE_DIR/$2.zip" n=1 part pct
    local base=$((5 + PKG_IDX * 20))

    say "Downloading $p.zip... ${base}%"
    try_get "$ub/$p.zip" "$out"
    if [ "$GOT" = "1" ]; then PKG_IDX=$((PKG_IDX + 1)); return 0; fi
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
        try_get "$ub/$part" "$STAGE_DIR/$part"
        if [ "$GOT" = "1" ]; then
            cat "$STAGE_DIR/$part" >> "$out" && rm -f "$STAGE_DIR/$part"
            n=$((n + 1))
        elif [ "$MISSING" = "1" ] && [ "$n" -gt 1 ]; then
            break                                   # หมดชิ้นแล้ว
        elif [ "$MISSING" = "1" ]; then
            rm -f "$out"
            if [ "$opt" = "optional" ]; then return 1; fi
            say "FAILED: $p.zip not found on server - nothing was changed."
            fail_exit
        else
            say "FAILED to download $part - nothing was changed."
            fail_exit
        fi
    done
    echo "[parts] $p: $((n - 1)) part(s) -> $(stat -c %s "$out") bytes"
    PKG_IDX=$((PKG_IDX + 1))
    return 0
}

# ==========================================================
#  [2] RG  ->  4.0.1 / 261202   (PPSSPP)
# ==========================================================
run_rg() {
    say "Preparing update files... 5%"
    rm -rf "$STAGE_DIR"; mkdir -p "$STAGE_DIR"
    cleanup_tmp

    for p in "${PKGS[@]}"; do fetch_pkg "$URL_RG" "$p"; done

    say "Verifying files... 48%"
    for p in "${PKGS[@]}"; do
        if ! unzip -tq "$STAGE_DIR/$p.zip" >/dev/null 2>&1; then
            say "$p.zip is not a valid zip - nothing was changed."
            fail_exit
        fi
    done

    # แตกไฟล์ไปไว้ข้างๆ ก่อน (ยังไม่ลบของเดิม) แล้วตรวจว่ามี PPSSPPSDL จริง
    declare -A NEW_ROOT
    local pct=52 tmp root dest old owner
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

    # ลบของเดิมทิ้งทั้งหมด แล้ววางอันใหม่ (สลับโฟลเดอร์ ถ้าพลาดจะคืนของเดิม)
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

    say "Finishing... 96%"
    local newver
    newver=$(echo "$CURRENT_VERSION_RAW" | sed -E "s/^4\.0/$RG_NEW_BASE_VERSION/")
    cat > "$INFO_FILE" <<EOT
VERSION="$newver"
BUILD="$RG_NEW_BUILD"
EOT
    say "Update completed! (PLAY OS v$newver) Restarting... 100%"
    sleep 3
    exit 187
}

# ==========================================================
#  [1] 4.0 B  ->  4.0.1 B / 261203
# ==========================================================
avail_mb() { df -Pm "$1" 2>/dev/null | awk 'NR==2 {print $4}'; }
fs_id() { stat -c %d "$1" 2>/dev/null; }

CREATED_LIST=""
copy_tree() {  # copy_tree <src_root> : คัดลอกทุกไฟล์ไปที่ / (แบบ atomic ต่อไฟล์) ตั้ง COPY_FAIL=1 ถ้าพลาด
    local src="$1" f rel dest cnt=0 d
    COPY_FAIL=0
    while IFS= read -r -d '' f; do
        rel="${f#"$src"/}"
        dest="/$rel"
        if [ -n "$CREATED_LIST" ]; then                # จดโฟลเดอร์ที่ยังไม่เคยมี (ไว้ลบตอนย้อนกลับ)
            d="$(dirname "$dest")"
            while [ ! -d "$d" ] && [ "$d" != "/" ]; do printf '%s\0' "$d" >> "$CREATED_LIST.dirs"; d="$(dirname "$d")"; done
        fi
        if ! mkdir -p "$(dirname "$dest")"; then
            echo "[copy] mkdir FAILED for $dest"; COPY_FAIL=1; break
        fi
        # จดไฟล์ที่ยังไม่เคยมี (ไว้ลบตอนย้อนกลับ)
        if [ -n "$CREATED_LIST" ] && [ ! -e "$dest" ]; then printf '%s\0' "$dest" >> "$CREATED_LIST"; fi
        if cp -f "$f" "$dest.pkgnew" && mv -f "$dest.pkgnew" "$dest"; then
            cnt=$((cnt + 1))
        else
            rm -f "$dest.pkgnew"
            echo "[copy] FAILED $dest"; COPY_FAIL=1; break
        fi
    done < <(find "$src" -type f -print0)
    echo "[copy] $cnt file(s) copied from $src (fail=$COPY_FAIL)"
}

backup_existing() {  # backup_existing <src_root> : เก็บของเดิมที่จะถูกทับ (boot, etc, lib, usr, .asoundrc, es_systems.cfg)
    local src="$1" f rel
    rm -rf "$BACKUP_DIR"; mkdir -p "$BACKUP_DIR"
    while IFS= read -r -d '' f; do
        rel="${f#"$src"/}"
        case "$rel" in boot/*|etc/*|usr/*|lib/*|home/ark/.asoundrc) ;; *) continue ;; esac
        [ -f "/$rel" ] || continue
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")" && cp -f "/$rel" "$BACKUP_DIR/$rel"
    done < <(find "$src" -type f -print0)
    if [ -f "$ES_CFG" ]; then
        mkdir -p "$BACKUP_DIR/etc/emulationstation" && cp -f "$ES_CFG" "$BACKUP_DIR/etc/emulationstation/es_systems.cfg"
    fi
    echo "[backup] $(find "$BACKUP_DIR" -type f | wc -l) file(s) in $BACKUP_DIR"
}

write_otg_fix() {  # OTG_fix.sh (ฝังไว้ในสคริปต์นี้)
    mkdir -p "$(dirname "$OTG_DEST")"
    cat > "$OTG_DEST.new" <<'OTG_FIX_EOF'
#!/bin/bash
ROOT="/boot"
cd "$ROOT" || exit 1
LOG="$ROOT/OTG_fix.log"

command -v dtc >/dev/null || { echo "dtc not found"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

{
  printf '\tvcc_host {\n'
  printf '\t\tcompatible = "regulator-fixed";\n'
  printf '\t\tregulator-name = "vcc_host";\n'
  printf '\t\tregulator-min-microvolt = <0x4c4b40>;\n'
  printf '\t\tregulator-max-microvolt = <0x4c4b40>;\n'
  printf '\t\tgpio = <0x5c 0x0f 0x00>;\n'
  printf '\t\tenable-active-high;\n'
  printf '\t\tregulator-always-on;\n'
  printf '\t\tvin-supply = <0x64>;\n'
  printf '\t};\n'
} > "$TMP/vcc_host.txt"

# node_ph FILE HEADER_REGEX END_LINE PHANDLE_LINE_PREFIX -> decimal phandle
node_ph() {
  local h
  h=$(awk -v hdr="$2" -v end="$3" -v pre="$4" '
    $0 ~ hdr {n=1; next}
    n && $0 == end {exit}
    n && index($0, pre) == 1 {match($0, /0x[0-9a-fA-F]+/); print substr($0, RSTART, RLENGTH); exit}
  ' "$1")
  [ -n "$h" ] && echo $((h))
}

pwm0_status() {
  awk '
    /^\tpwm@ff200000 [{]$/ {n=1; next}
    n && /^\t};$/ {exit}
    n && /^\t\tstatus = / {gsub(/.*= "|";.*/, ""); print; exit}
  ' "$1"
}

process() {
  local f="$1"
  local dts="$TMP/in.dts" out="$TMP/out.dts" t2="$TMP/t.dts" new="$TMP/new.dtb"
  local g0 vs jph pwm0 changed=0

  R_RUM="-"; R_PWM="-"; R_VH="-"; R_WR="-"

  if ! dtc -q -I dtb -O dts -o "$dts" "$f" 2>/dev/null; then
    R_WR="DECOMPILE-FAIL"
    return
  fi
  cp "$dts" "$out"

  g0=$(node_ph "$dts" $'^\t\tgpio0@ff040000 [{]$' $'\t\t};' $'\t\t\tphandle = <')
  vs=$(node_ph "$dts" $'^\t(vccsys|vcc_sys) [{]$' $'\t};' $'\t\tphandle = <')

  # ---- rumble: PWM0 (GPIO0_B7) -> rumble-gpio GPIO0_A0, PWM0 disabled
  if awk '
      /^\todroidgo3-joypad [{]$/ {n=1; next}
      n && /^\t};$/ {exit}
      n && /^\t\trumble-gpio = </ {f=1}
      END {exit !f}
    ' "$dts"; then
    R_RUM="ALREADY"
  else
    jph=$(awk '
      /^\todroidgo3-joypad [{]$/ {n=1; next}
      n && /^\t};$/ {exit}
      n && /^\t\tpwms = </ {match($0, /0x[0-9a-fA-F]+/); print substr($0, RSTART, RLENGTH); exit}
    ' "$dts")
    pwm0=$(node_ph "$dts" $'^\tpwm@ff200000 [{]$' $'\t};' $'\t\tphandle = <')

    if [ -z "$jph" ]; then
      R_RUM="SKIP:NO-PWMS"
    elif [ -z "$pwm0" ] || [ $((jph)) -ne "$pwm0" ]; then
      R_RUM="SKIP:PWMS-NOT-PWM0"
    elif [ "$(grep -cE "^\s+pwms = <0x0*$(printf '%x' $((jph)))[ >]" "$dts")" -ne 1 ]; then
      R_RUM="SKIP:PWM0-SHARED"
    elif [ "${g0:-}" != "92" ]; then
      R_RUM="SKIP:GPIO0-PH"
    elif grep -qE '<0x5c 0x0+ |rockchip,pins = <0x0+ 0x0+ ' "$dts"; then
      R_RUM="SKIP:A0-IN-USE"
    else
      awk '
        /^\todroidgo3-joypad [{]$/ {n=1}
        n && /^\t};$/ {n=0}
        n && /^\t\tpwms = </ {print "\t\trumble-gpio = <0x5c 0x00 0x00>;"; next}
        n && /^\t\tpwm-names = / {next}
        {print}
      ' "$out" > "$t2" && mv "$t2" "$out"
      awk '
        /^\tpwm@ff200000 [{]$/ {n=1}
        n && /^\t};$/ {n=0}
        n && /^\t\tstatus = / {print "\t\tstatus = \"disabled\";"; next}
        {print}
      ' "$out" > "$t2" && mv "$t2" "$out"
      R_RUM="MOVED"
      changed=1
    fi
  fi

  # ---- vcc_host
  if grep -qE $'^\tvcc_host [{]$' "$dts"; then
    R_VH="ALREADY"
  elif [ -z "$vs" ]; then
    R_VH="SKIP:NO-VCCSYS"
  elif [ "$vs" != "100" ]; then
    R_VH="SKIP:VCCSYS-PH"
  elif [ "${g0:-}" != "92" ]; then
    R_VH="SKIP:GPIO0-PH"
  elif grep -qE '<0x5c 0x0f ' "$dts"; then
    R_VH="SKIP:B7-IN-USE"
  else
    awk -v blk="$TMP/vcc_host.txt" '
      /^\t(vccsys|vcc_sys) [{]$/ {n=1}
      {print}
      n && /^\t};$/ {n=0; while ((getline l < blk) > 0) print l; close(blk)}
    ' "$out" > "$t2" && mv "$t2" "$out"
    R_VH="ADDED"
    changed=1
  fi

  R_PWM=$(pwm0_status "$out"); R_PWM="${R_PWM:--}"

  if [ "$changed" = 1 ]; then
    if dtc -q -I dts -O dtb -o "$new" "$out" 2>/dev/null && [ -s "$new" ]; then
      cp "$new" "$f" && R_WR="WRITTEN" || R_WR="COPY-FAIL"
    else
      R_WR="COMPILE-FAIL"
    fi
  else
    R_WR="UNCHANGED"
  fi
}

rows=()
total=0; n_moved=0; n_added=0; n_written=0; n_skip=0; n_fail=0

while IFS= read -r -d '' f; do
  rel="${f#./}"
  dir="$(dirname "$rel")"
  base="$(basename "$rel")"
  case "${base,,}" in *uboot*) continue ;; esac

  total=$((total + 1))
  process "$f"

  [ "$R_RUM" = "MOVED" ] && n_moved=$((n_moved + 1))
  [ "$R_VH" = "ADDED" ] && n_added=$((n_added + 1))
  [ "$R_WR" = "WRITTEN" ] && n_written=$((n_written + 1))
  case "$R_RUM$R_VH" in *SKIP*) n_skip=$((n_skip + 1)) ;; esac
  case "$R_WR" in *FAIL*) n_fail=$((n_fail + 1)) ;; esac

  rows+=("$dir"$'\t'"$base"$'\t'"$R_RUM"$'\t'"$R_PWM"$'\t'"$R_VH"$'\t'"$R_WR")
done < <(find . -maxdepth 1 -type f -iname '*.dtb' -print0 | sort -z)

{
  echo "OTG fix - $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Root: $ROOT"
  echo "DTBs: $total"
  echo
  {
    printf 'FOLDER\tFILE\tRUMBLE\tPWM0\tVCC_HOST\tWRITE\n'
    [ "${#rows[@]}" -gt 0 ] && printf '%s\n' "${rows[@]}"
  } | column -t -s $'\t'
  echo
  echo "Summary:"
  echo "  Rumble moved:     $n_moved"
  echo "  vcc_host added:   $n_added"
  echo "  Files written:    $n_written"
  echo "  With skips:       $n_skip"
  echo "  Failures:         $n_fail"
} | tee "$LOG"
OTG_FIX_EOF
    chmod 755 "$OTG_DEST.new" && chown ark:ark "$OTG_DEST.new" && mv -f "$OTG_DEST.new" "$OTG_DEST"
}

run_b() {
    local zip="" name need_stage need_root need_boot zip_mb un_mb pct

    say "Preparing update files... 5%"
    rm -rf "$STAGE_DIR"; mkdir -p "$STAGE_DIR"

    # --- ดาวน์โหลดแพ็กเกจ (ลองชื่อไฟล์ตามลำดับ) ---
    for name in "${B_PKG_NAMES[@]}"; do
        PKG_IDX=0
        if fetch_pkg "$URL_B" "$name" optional; then zip="$STAGE_DIR/$name.zip"; break; fi
    done
    if [ -z "$zip" ]; then
        say "FAILED: update package not found on server - nothing was changed."
        fail_exit
    fi

    say "Verifying package... 42%"
    if ! unzip -tq "$zip" >/dev/null 2>&1; then
        say "Update package is not a valid zip - nothing was changed."
        fail_exit
    fi

    # --- เช็กพื้นที่ว่างก่อนแตะอะไร ---
    zip_mb=$(( $(stat -c %s "$zip") / 1048576 + 1 ))
    un_mb=$(( $(unzip -l "$zip" | tail -n 1 | awk '{print $1}') / 1048576 + 1 ))
    need_stage=$(( zip_mb + un_mb + 25 ))           # zip + ไฟล์ที่แตก + สำรอง
    need_root=$(( un_mb + 15 ))                     # ไฟล์ที่ลงระบบ
    need_boot=12
    if [ "$(fs_id /)" = "$(fs_id /home/ark)" ]; then need_stage=$(( need_stage + need_root )); fi
    echo "[space] zip=${zip_mb}MB unpacked=${un_mb}MB | need stage>=${need_stage}MB root>=${need_root}MB boot>=${need_boot}MB | free stage=$(avail_mb /home/ark)MB root=$(avail_mb /)MB boot=$(avail_mb /boot)MB"
    if [ "$(avail_mb /home/ark)" -lt "$need_stage" ] 2>/dev/null; then
        say "Not enough free space (need ${need_stage} MB) - nothing was changed."
        fail_exit
    fi
    if [ "$(avail_mb /)" -lt "$need_root" ] 2>/dev/null; then
        say "Not enough free space on system (need ${need_root} MB) - nothing was changed."
        fail_exit
    fi

    # --- แตกแพ็กเกจใน stage ---
    say "Unpacking package... 48%"
    mkdir -p "$STAGE_DIR/pkg"
    if ! unzip -q -o "$zip" -d "$STAGE_DIR/pkg"; then
        say "Failed to unpack package - nothing was changed."
        fail_exit
    fi
    rm -f "$zip"
    local root="$STAGE_DIR/pkg"
    if [ "$(ls -A "$root" | wc -l)" = "1" ] && [ -d "$root/$(ls -A "$root")" ]; then
        root="$root/$(ls -A "$root")"               # แพ็กเกจห่อด้วยโฟลเดอร์เดียว (PlayOS4.0-update261203/)
    fi
    rm -rf "$root/tmp"                              # tmp/10312026.sh = สคริปต์ของ dArkOSen ไม่ใช้
    if [ -z "$(find "$root" -type f | head -n 1)" ]; then
        say "Update package is empty - nothing was changed."
        fail_exit
    fi
    if [ -d "$root/boot" ]; then
        if ! { touch /boot/.playos_w 2>/dev/null && rm -f /boot/.playos_w; }; then
            say "Boot partition is not writable - nothing was changed."
            fail_exit
        fi
        if [ "$(avail_mb /boot)" -lt "$need_boot" ] 2>/dev/null; then
            say "Not enough free space on boot partition - nothing was changed."
            fail_exit
        fi
    fi
    # ไฟล์ OTG_fix.sh ในแพ็กเกจ (ถ้ามี) ใช้ตัวในแพ็กเกจ ไม่งั้นใช้ตัวที่ฝังไว้
    local pkg_has_otg=0
    [ -f "$root/opt/system/Advanced/OTG_fix.sh" ] && pkg_has_otg=1

    # --- สำรองของเดิม แล้วคัดลอก ---
    say "Backing up current files... 55%"
    backup_existing "$root"

    say "Installing update files... 62%"
    CREATED_LIST="$STAGE_DIR/created.list"; : > "$CREATED_LIST"; : > "$CREATED_LIST.dirs"
    copy_tree "$root"
    if [ "$COPY_FAIL" = "1" ]; then
        say "Install failed - restoring previous files..."
        local cl="$CREATED_LIST" d
        CREATED_LIST=""
        copy_tree "$BACKUP_DIR"                      # คืนไฟล์เดิมที่ถูกทับ
        while IFS= read -r -d '' d; do rm -f "$d"; done < "$cl"   # ลบไฟล์ใหม่ที่เพิ่งใส่
        if [ -f "$cl.dirs" ]; then                                  # ลบโฟลเดอร์ใหม่ที่ว่างเปล่า (ลูกก่อนพ่อ)
            sort -rz "$cl.dirs" | while IFS= read -r -d '' d; do rmdir "$d" 2>/dev/null; done
        fi
        echo "[rollback] removed $(tr -cd '\0' < "$cl" | wc -c) new file(s)"
        say "Previous files restored. Update canceled."
        fail_exit
    fi
    CREATED_LIST=""

    # --- สิทธิ์การรัน + เจ้าของไฟล์ ---
    say "Setting permissions... 80%"
    while IFS= read -r -d '' f; do
        rel="${f#"$root"/}"
        case "$rel" in
            usr/local/bin/*)
                chmod 755 "/$rel"; chown ark:ark "/$rel" ;;
            home/ark/*)
                chown ark:ark "/$rel" ;;
        esac
    done < <(find "$root" -type f -print0)
    chmod +x /opt/gzdoom/gzdoom /opt/dsperate/dsperate /opt/yabasanshiro/yabasanshiro-pirry 2>/dev/null
    [ -d /opt/gzdoom ] && chown -R ark:ark /opt/gzdoom
    [ -d /opt/dsperate ] && chown -R ark:ark /opt/dsperate
    [ -f /opt/yabasanshiro/yabasanshiro-pirry ] && chown ark:ark /opt/yabasanshiro/yabasanshiro-pirry

    # --- เครื่องมือ OTG_fix.sh (ไม่รันอัตโนมัติ) ---
    if [ "$pkg_has_otg" = "0" ]; then write_otg_fix; fi
    chmod 755 "$OTG_DEST" 2>/dev/null; chown ark:ark "$OTG_DEST" 2>/dev/null

    # --- es_systems.cfg: เพิ่ม dsperate ต่อจาก drastic + แก้กรณีซ้อนผิดโครงสร้าง ---
    say "Updating system configuration... 86%"
    if [ -f "$ES_CFG" ]; then
        sed -i -E '/^[[:space:]]*<emulator name="drastic">/{N;N;/name="dsperate"/!s/^([[:space:]]*)(<emulator name="drastic">\n[[:space:]]*<\/emulator>)\n/\1\2\n\1<emulator name="dsperate">\n\1<\/emulator>\n/}' "$ES_CFG"
        sed -i '/<emulator name="drastic">/{N;N;N;s#^\([[:space:]]*\)<emulator name="drastic">\n[[:space:]]*<emulator name="dsperate">\n[[:space:]]*</emulator>\n[[:space:]]*</emulator>#\1<emulator name="drastic">\n\1</emulator>\n\1<emulator name="dsperate">\n\1</emulator>#;}' "$ES_CFG"
        echo "[es_systems] dsperate entries: $(grep -c '<emulator name="dsperate">' "$ES_CFG")"
    else
        echo "[es_systems] $ES_CFG not found - skipped"
    fi

    # --- บริการ/โมดูล ---
    say "Refreshing services... 90%"
    systemctl daemon-reload 2>&1
    systemctl enable --now night-filter.timer 2>&1
    depmod -a 2>&1

    # --- ประทับเวอร์ชัน (ท้ายสุด) --- รักษารูปแบบเดิม เช่น "4.0 B" -> "4.0.1 B"
    say "Finishing... 96%"
    local newver
    newver=$(echo "$CURRENT_VERSION_RAW" | sed -E "s/^4\.0/$B_NEW_BASE_VERSION/")
    cat > "$INFO_FILE" <<EOT
VERSION="$newver"
BUILD="$B_NEW_BUILD"
EOT
    rm -rf "$STAGE_DIR"
    say "Update completed! (PLAY OS v$newver) Restarting... 100%"
    sleep 3
    exit 187
}

if [ "$MODE" = "RG" ]; then run_rg; else run_b; fi
