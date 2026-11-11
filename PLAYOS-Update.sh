#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update  (ตระกูล 4.0.x ทุกสาย)  ->  4.0.3   build 261211
#
#  รับเครื่อง: 4.0 / 4.0 B / 4.0(X) / 4.0 RG EDITION / 4.0.1 / 4.0.2 (ทุก tag) ที่ต่ำกว่า 4.0.3
#  ประทับเวอร์ชันโดยคงรูปแบบเดิม  เช่น  "4.0.2" -> "4.0.3", "4.0(X)" -> "4.0.3(X)",
#                                      "4.0.2 RG EDITION" -> "4.0.3 RG EDITION"   BUILD=261211
#  ไม่อัปเดต: 4.0.3 ขึ้นไป (ทุกบิลด์), สาย 3.x และเวอร์ชันอื่น -> ยกเลิก ไม่แตะอะไรเลย
#
#  แพ็กเกจ 4.0.3  (Release tag "4.0.3" : PlayOS4_0-update261211.zip)
#     /usr/local/bin/playfe, playfe-led   และ   /opt/apps (สคริปต์แอป + gamelist.xml + images,
#     เพิ่มแอป PortMaster)   คัดลอกทับของเดิมแบบ atomic (ไม่ลบไฟล์อื่นในโฟลเดอร์)
#     ไม่แตะ EmulationStation
#
#  เครื่องที่ต่ำกว่า 4.0.2 จะได้ชุด 4.0.2 ตามไปด้วยในรอบเดียว
#     (Release tag "4.0.2" : PlayOS4.0-update261207 = playfe + /opt/gamestore)
#  เครื่องแท้ (4.0 / 4.0 B) ที่ยังไม่ได้อัปเป็น 4.0.1 จะได้ชุด 4.0.1 ตามไปด้วยอีกชั้น
#     (Release tag "4.0B" : DSperate, GZDoom, Yabasanshiro, Stella, DTB, ไดรเวอร์ Wi-Fi,
#      es_systems dsperate, OTG_fix ใน /opt/system/Advanced ฯลฯ)
#     เครื่อง X และ RG ไม่ได้ชุด 4.0.1
#     ลำดับติดตั้ง 4.0.1 -> 4.0.2 -> 4.0.3 (ไฟล์ใหม่กว่าทับไฟล์เก่า)
#
#  ความปลอดภัย: เช็กพื้นที่/สิทธิ์เขียน /boot ก่อน, สำรองไฟล์เดิมที่จะถูกทับ
#     (boot/etc/lib/usr + gamestore binary + /opt/apps) ไว้ที่ /home/ark/.playos_backup_261211
#     ถ้าคัดลอกพลาด จะคืนของเดิมและลบไฟล์ใหม่ที่ใส่ไปแล้วให้เอง
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

# ===== 4.0.3 (ทุกสาย) =====
NEW_BASE_VERSION="4.0.3"
NEW_BUILD=261211
URL_P403="https://github.com/Factzz/pLayOS/releases/download/4.0.3"
P403_NAMES=("PlayOS4_0-update261211" "PlayOS4.0-update261211")     # ชื่อไฟล์ zip บน Release (ไม่รวม .zip) ลองตามลำดับ

# ===== ชุด 4.0.2 (เครื่องที่ยังต่ำกว่า 4.0.2) =====
P402_VERSION="4.0.2"
P402_BUILD=261207
URL_P402="https://github.com/Factzz/pLayOS/releases/download/4.0.2"
P402_NAMES=("PlayOS4.0-update261207" "PlayOS4_0-update261207")

# ===== ชุด 4.0.1 (เฉพาะเครื่องแท้/เบต้าที่ยังไม่มี) =====
P401_VERSION="4.0.1"
P401_BUILD=261203
URL_P401="https://github.com/Factzz/pLayOS/releases/download/4.0B"
P401_NAMES=("PlayOS4.0-update261203" "PlayOS4_0-update261203")
GENUINE_PATTERN='^4\.0(\.[0-9]+)?([[:space:]\(_-]*B(ETA)?\)?)?$'   # "4.0", "4.0.1", "4.0 B", "4.0(B)" (ไม่รวม X / RG)

BACKUP_DIR="/home/ark/.playos_backup_261211"
ES_CFG="/etc/emulationstation/es_systems.cfg"
OTG_DEST="/opt/system/Advanced/OTG_fix.sh"

STAGE_DIR="/home/ark/.playos_stage"

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
df -h / /boot /home/ark 2>&1 | tail -n 3
free -m 2>&1 | sed -n 2p

[ -z "$CURRENT_BUILD" ] && CURRENT_BUILD=0

say "PLAY OS Updater - current: ${CURRENT_VERSION_RAW:-unknown} (build $CURRENT_BUILD) 2%"


# ---------- ตรวจเวอร์ชัน: ตระกูล 4.0.x ทุกสาย ----------
ver_lt() {  # true ถ้า $1 < $2
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}
older_than() {  # older_than <ver> <build> : เครื่องนี้ยังไม่ถึง ver/build นั้น
    ver_lt "$VERSION_BASE" "$1" || { [ "$VERSION_BASE" = "$1" ] && [ "$CURRENT_BUILD" -lt "$2" ]; }
}

VERSION_UC=$(echo "$CURRENT_VERSION_RAW" | tr '[:lower:]' '[:upper:]')
VERSION_BASE=$(echo "$CURRENT_VERSION_RAW" | grep -oE '^[0-9]+(\.[0-9]+)*')
VERSION_MM=$(echo "$VERSION_BASE" | cut -d. -f1,2)
MODE="cancel"; NEED_P401=0; NEED_P402=0

if [ "$VERSION_MM" != "4.0" ]; then
    CANCEL_MSG="This update only applies to 4.0.x (yours: ${CURRENT_VERSION_RAW:-UNKNOWN}). Update canceled."
elif [ "$VERSION_BASE" = "$NEW_BASE_VERSION" ] || ver_lt "$NEW_BASE_VERSION" "$VERSION_BASE" || [ "$CURRENT_BUILD" -ge "$NEW_BUILD" ]; then
    CANCEL_MSG="Already up to date (v$VERSION_BASE, build $CURRENT_BUILD). Update canceled."
else
    MODE="go"
    # เครื่องที่ยังไม่มี 4.0.2 -> เอาชุด 4.0.2 ตามไปด้วย (ทุกสาย)
    if older_than "$P402_VERSION" "$P402_BUILD"; then
        NEED_P402=1
    fi
    # เครื่องแท้/เบต้าที่ยังไม่มี 4.0.1 -> เอาชุด 4.0.1 ตามไปด้วย (X และ RG ไม่ได้รับ 4.0.1)
    if [[ "$VERSION_UC" =~ $GENUINE_PATTERN ]] && older_than "$P401_VERSION" "$P401_BUILD"; then
        NEED_P401=1
    fi
fi

if [ "$MODE" = "cancel" ]; then
    say "$CANCEL_MSG"
    sleep 3; exit 0
fi
echo "[mode] update  need_4.0.1=$NEED_P401 need_4.0.2=$NEED_P402"


# ---------- ฟังก์ชันร่วม ----------
fail_exit() { rm -rf "$STAGE_DIR"; sleep 3; exit 1; }

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
    local base=$((5 + PKG_IDX * 12))

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
        pct=$((base + n)); [ "$pct" -gt $((base + 10)) ] && pct=$((base + 10))
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
#  4.0  ->  4.0.1 / 261203
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

backup_existing() {  # backup_existing <src_root> : เก็บของเดิมที่จะถูกทับ (เรียกซ้ำได้ ไม่ล้างของที่สำรองไว้ก่อนหน้า)
    local src="$1" f rel
    mkdir -p "$BACKUP_DIR"
    while IFS= read -r -d '' f; do
        rel="${f#"$src"/}"
        case "$rel" in boot/*|etc/*|usr/*|lib/*|home/ark/.asoundrc|opt/gamestore/gamestore|opt/gamestore/*.ttf|opt/apps/*) ;; *) continue ;; esac
        [ -f "/$rel" ] || continue
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")" && cp -f "/$rel" "$BACKUP_DIR/$rel"
    done < <(find "$src" -type f -print0)
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


# get_package <url-base> <ตัวแปรที่รับพาธ zip> <ชื่อไฟล์ที่ลองตามลำดับ...>
get_package() {
    local ub="$1" outvar="$2" n idx0=$PKG_IDX
    shift 2
    for n in "$@"; do
        PKG_IDX=$idx0
        if fetch_pkg "$ub" "$n" optional; then printf -v "$outvar" '%s' "$STAGE_DIR/$n.zip"; return 0; fi
    done
    return 1
}

# unpack_pkg <zip> <โฟลเดอร์ปลายทาง> : แตกแล้วตั้ง PKG_ROOT (ข้ามโฟลเดอร์ห่อเดียวที่ไม่ใช่โฟลเดอร์ระบบ)
unpack_pkg() {
    local zip="$1" dir="$2" only
    mkdir -p "$dir"
    unzip -q -o "$zip" -d "$dir" || return 1
    rm -f "$zip"
    PKG_ROOT="$dir"
    if [ "$(ls -A "$dir" | wc -l)" = "1" ]; then
        only="$(ls -A "$dir")"
        case "$only" in
            boot|etc|home|lib|opt|usr|roms|tmp|var|bin|sbin) ;;                 # เป็นโฟลเดอร์ระบบจริง ไม่ใช่ตัวห่อ
            *) [ -d "$dir/$only" ] && PKG_ROOT="$dir/$only" ;;
        esac
    fi
    rm -rf "$PKG_ROOT/tmp"                          # tmp/ = สคริปต์ของ dArkOSen ไม่ใช้
    [ -n "$(find "$PKG_ROOT" -type f | head -n 1)" ]
}

run_update() {
    local zip401="" zip402="" zip403="" z roots=() root pct zip_mb=0 un_mb=0 need_stage need_root need_boot
    local f rel

    say "Preparing update files... 5%"
    rm -rf "$STAGE_DIR"; mkdir -p "$STAGE_DIR"

    # --- ดาวน์โหลดแพ็กเกจ (ครบก่อนค่อยแตะระบบ) ---
    if [ "$NEED_P401" = "1" ]; then
        if ! get_package "$URL_P401" zip401 "${P401_NAMES[@]}"; then
            say "FAILED: 4.0.1 package not found on server - nothing was changed."
            fail_exit
        fi
    fi
    if [ "$NEED_P402" = "1" ]; then
        if ! get_package "$URL_P402" zip402 "${P402_NAMES[@]}"; then
            say "FAILED: 4.0.2 package not found on server - nothing was changed."
            fail_exit
        fi
    fi
    if ! get_package "$URL_P403" zip403 "${P403_NAMES[@]}"; then
        say "FAILED: 4.0.3 package not found on server - nothing was changed."
        fail_exit
    fi

    say "Verifying packages... 46%"
    for z in $zip401 $zip402 $zip403; do
        if ! unzip -tq "$z" >/dev/null 2>&1; then
            say "Update package is not a valid zip - nothing was changed."
            fail_exit
        fi
        zip_mb=$(( zip_mb + $(stat -c %s "$z") / 1048576 + 1 ))
        un_mb=$(( un_mb + $(unzip -l "$z" | tail -n 1 | awk '{print $1}') / 1048576 + 1 ))
    done

    # --- เช็กพื้นที่ว่างก่อนแตะอะไร ---
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
    say "Unpacking packages... 50%"
    local root401="" root402="" root403="" pkg_has_otg=0
    if [ -n "$zip401" ]; then
        if ! unpack_pkg "$zip401" "$STAGE_DIR/p401"; then say "Failed to unpack 4.0.1 package - nothing was changed."; fail_exit; fi
        root401="$PKG_ROOT"; roots+=("$root401")
        [ -f "$root401/opt/system/Advanced/OTG_fix.sh" ] && pkg_has_otg=1
    fi
    if [ -n "$zip402" ]; then
        if ! unpack_pkg "$zip402" "$STAGE_DIR/p402"; then say "Failed to unpack 4.0.2 package - nothing was changed."; fail_exit; fi
        root402="$PKG_ROOT"; roots+=("$root402")
    fi
    if ! unpack_pkg "$zip403" "$STAGE_DIR/p403"; then say "Failed to unpack 4.0.3 package - nothing was changed."; fail_exit; fi
    root403="$PKG_ROOT"; roots+=("$root403")

    for root in "${roots[@]}"; do
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
    done

    # --- สำรองของเดิม แล้วคัดลอก (ทุกแพ็กเกจ แล้วค่อยทำขั้นตอนหลังติดตั้ง) ---
    say "Backing up current files... 56%"
    rm -rf "$BACKUP_DIR"; mkdir -p "$BACKUP_DIR"
    for root in "${roots[@]}"; do backup_existing "$root"; done
    if [ "$NEED_P401" = "1" ] && [ -f "$ES_CFG" ]; then
        mkdir -p "$BACKUP_DIR/etc/emulationstation" && cp -f "$ES_CFG" "$BACKUP_DIR/etc/emulationstation/es_systems.cfg"
    fi

    say "Installing update files... 62%"
    CREATED_LIST="$STAGE_DIR/created.list"; : > "$CREATED_LIST"; : > "$CREATED_LIST.dirs"
    COPY_FAIL=0
    for root in "${roots[@]}"; do
        copy_tree "$root"
        [ "$COPY_FAIL" = "1" ] && break
    done
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
    for root in "${roots[@]}"; do
        while IFS= read -r -d '' f; do
            rel="${f#"$root"/}"
            case "$rel" in
                usr/local/bin/*)  chmod 755 "/$rel"; chown ark:ark "/$rel" ;;
                home/ark/*)       chown ark:ark "/$rel" ;;
            esac
        done < <(find "$root" -type f -print0)
    done
    # 4.0.2: gamestore
    if [ -d /opt/gamestore ]; then
        chmod 755 /opt/gamestore/gamestore 2>/dev/null
        chown -R ark:ark /opt/gamestore
    fi
    # 4.0.3: /opt/apps (สคริปต์แอปต้องรันได้ เช่น PortMaster.sh ในแพ็กเกจเป็น 644)
    if [ -d /opt/apps ]; then
        chmod 755 /opt/apps/*.sh 2>/dev/null
        chown -R ark:ark /opt/apps
    fi

    # ---- ขั้นตอนหลังติดตั้งของชุด 4.0.1 (เฉพาะเครื่องที่ได้ชุดนี้) ----
    if [ "$NEED_P401" = "1" ]; then
        chmod +x /opt/gzdoom/gzdoom /opt/dsperate/dsperate /opt/yabasanshiro/yabasanshiro-pirry 2>/dev/null
        [ -d /opt/gzdoom ] && chown -R ark:ark /opt/gzdoom
        [ -d /opt/dsperate ] && chown -R ark:ark /opt/dsperate
        [ -f /opt/yabasanshiro/yabasanshiro-pirry ] && chown ark:ark /opt/yabasanshiro/yabasanshiro-pirry

        # เครื่องมือ OTG_fix.sh (ไม่รันอัตโนมัติ) -- ใช้ตัวในแพ็กเกจถ้ามี ไม่งั้นใช้ตัวที่ฝังไว้
        if [ "$pkg_has_otg" = "0" ]; then write_otg_fix; fi
        chmod 755 "$OTG_DEST" 2>/dev/null; chown ark:ark "$OTG_DEST" 2>/dev/null

        # es_systems.cfg: เพิ่ม dsperate ต่อจาก drastic + แก้กรณีซ้อนผิดโครงสร้าง
        say "Updating system configuration... 86%"
        if [ -f "$ES_CFG" ]; then
            sed -i -E '/^[[:space:]]*<emulator name="drastic">/{N;N;/name="dsperate"/!s/^([[:space:]]*)(<emulator name="drastic">\n[[:space:]]*<\/emulator>)\n/\1\2\n\1<emulator name="dsperate">\n\1<\/emulator>\n/}' "$ES_CFG"
            sed -i '/<emulator name="drastic">/{N;N;N;s#^\([[:space:]]*\)<emulator name="drastic">\n[[:space:]]*<emulator name="dsperate">\n[[:space:]]*</emulator>\n[[:space:]]*</emulator>#\1<emulator name="drastic">\n\1</emulator>\n\1<emulator name="dsperate">\n\1</emulator>#;}' "$ES_CFG"
            echo "[es_systems] dsperate entries: $(grep -c '<emulator name="dsperate">' "$ES_CFG")"
        else
            echo "[es_systems] $ES_CFG not found - skipped"
        fi

        say "Refreshing services... 90%"
        systemctl daemon-reload 2>&1
        systemctl enable --now night-filter.timer 2>&1
        depmod -a 2>&1
    fi

    # --- ประทับเวอร์ชัน (ท้ายสุด) : คงรูปแบบเดิม เช่น "4.0(X)" -> "4.0.2(X)" ---
    say "Finishing... 96%"
    local newver
    newver=$(echo "$CURRENT_VERSION_RAW" | sed -E "s/^4\.0(\.[0-9]+)?/$NEW_BASE_VERSION/")
    cat > "$INFO_FILE" <<EOT
VERSION="$newver"
BUILD="$NEW_BUILD"
EOT
    rm -rf "$STAGE_DIR"
    say "Update completed! (PLAY OS v$newver) Restarting... 100%"
    sleep 3
    exit 187
}

run_update
