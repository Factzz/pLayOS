#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update v3.0.1
# Build: 261027
# Track: STANDARD (3.0.x) only - rejects the 3.0(X) variant track,
#        and any version outside the 3.0.x line.
# ==========================================================

INFO_FILE="/opt/system/playos_info.cfg"
CURRENT_VERSION_RAW=$(grep "VERSION" "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)
CURRENT_BUILD=$(grep "BUILD" "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)

NEW_VERSION="3.0.1"
NEW_BUILD=261027
URL_BASE="https://raw.githubusercontent.com/Factzz/pLayOS/main/261027"

# ถ้าหาบิลด์ไม่เจอให้ตีเป็น 0 เพื่อบังคับให้ผ่านเงื่อนไขการอัปเดต
if [ -z "$CURRENT_BUILD" ]; then
    CURRENT_BUILD=0
fi

echo ">> PLAY OS OTA Updater Starting..."
echo ">> Your Current Version: $CURRENT_VERSION_RAW (Build $CURRENT_BUILD)"

# ==========================================
# แยกเวอร์ชันฐาน ("3.0" จาก "3.0.1") ออกจากส่วนวงเล็บต่อท้าย ("X" จาก "3.0(X)")
# VERSION_TAG ไม่ว่าง = เป็นสายพันธุ์อื่น เช่น 3.0(X), ไม่ใช่สาย STANDARD
# ==========================================
VERSION_BASE=$(echo "$CURRENT_VERSION_RAW" | sed -E 's/\(.*\)//')
VERSION_TAG=$(echo "$CURRENT_VERSION_RAW" | sed -nE 's/.*\(([^)]*)\).*/\1/p')
VERSION_MAJOR_MINOR=$(echo "$VERSION_BASE" | cut -d. -f1,2)

REQUIRED_MAJOR_MINOR="3.0"

# ==========================================
# 🛡️ ด่านที่ 1: ต้องเป็นสาย STANDARD เท่านั้น ห้ามเป็นสายวงเล็บ เช่น (X)
# ==========================================
if [ -n "$VERSION_TAG" ]; then
    echo ">> THIS DEVICE IS ON THE '$VERSION_TAG' VARIANT TRACK (VERSION $CURRENT_VERSION_RAW)."
    echo ">> THIS UPDATE IS FOR THE STANDARD $REQUIRED_MAJOR_MINOR TRACK ONLY."
    echo ">> UPDATE CANCELED."
    sleep 3
    exit 0
fi

# ==========================================
# 🛡️ ด่านที่ 2: ต้องอยู่สาย 3.0.x เท่านั้น (ต่ำกว่า/สูงกว่านั้นอัปเดตผ่านตัวนี้ไม่ได้)
# ==========================================
if [ "$VERSION_MAJOR_MINOR" != "$REQUIRED_MAJOR_MINOR" ]; then
    echo ">> THIS UPDATE ONLY APPLIES TO VERSION $REQUIRED_MAJOR_MINOR.x (YOURS: ${VERSION_BASE:-UNKNOWN})."
    echo ">> UPDATE CANCELED."
    sleep 3
    exit 0
fi

# ==========================================
# 🛡️ ด่านที่ 3: บิลด์ปัจจุบันต้องต่ำกว่าบิลด์ใหม่เท่านั้น
# ==========================================
if [ "$CURRENT_BUILD" -ge "$NEW_BUILD" ]; then
    echo ">> SYSTEM IS ALREADY UP TO DATE OR NEWER (Build $CURRENT_BUILD >= $NEW_BUILD)."
    echo ">> UPDATE CANCELED."
    sleep 3
    exit 0
fi

# ==========================================
# 1. ติดตั้ง EmulationStation ตัวใหม่
# ==========================================
echo ">> [1/3] Updating EmulationStation..."

# แก้ ES_BIN ตรงนี้ให้ตรงกับ path จริงบนเครื่อง ถ้าไม่ใช่ /usr/bin/emulationstation
ES_BIN="/usr/bin/emulationstation"
ES_TMP="/tmp/emulationstation.new"

wget -q -t 3 -T 60 -O "$ES_TMP" "$URL_BASE/emulationstation"
if [ -f "$ES_TMP" ] && [ -s "$ES_TMP" ]; then
    if [ -f "$ES_BIN" ]; then
        sudo cp -f "$ES_BIN" "$ES_BIN.bak.$(date +%Y%m%d%H%M%S)"
    fi
    sudo cp -f "$ES_TMP" "$ES_BIN"
    # ต้องเป็นเจ้าของ ark:ark ห้ามเป็น root/สิทธิ์ root เด็ดขาด - ไม่งั้น ES เปิดไม่ขึ้น
    sudo chown ark:ark "$ES_BIN"
    sudo chmod 755 "$ES_BIN"
    rm -f "$ES_TMP"
    echo ">> emulationstation installed: $(stat -c '%U:%G %a' "$ES_BIN" 2>/dev/null) $ES_BIN"
else
    echo ">> FAILED TO DOWNLOAD emulationstation - ABORTING UPDATE (nothing changed)."
    rm -f "$ES_TMP"
    exit 1
fi

# ==========================================
# 2. ติดตั้ง generate_es_systems_variants.sh
# ==========================================
echo ">> [2/3] Updating generate_es_systems_variants.sh..."

GEN_SCRIPT="/usr/local/bin/generate_es_systems_variants.sh"
GEN_TMP="/tmp/generate_es_systems_variants.sh.new"

wget -q -t 3 -T 60 -O "$GEN_TMP" "$URL_BASE/generate_es_systems_variants.sh"
if [ -f "$GEN_TMP" ] && [ -s "$GEN_TMP" ]; then
    if [ -f "$GEN_SCRIPT" ]; then
        sudo cp -f "$GEN_SCRIPT" "$GEN_SCRIPT.bak.$(date +%Y%m%d%H%M%S)"
    fi
    sudo cp -f "$GEN_TMP" "$GEN_SCRIPT"
    sudo chown root:root "$GEN_SCRIPT"
    sudo chmod 755 "$GEN_SCRIPT"
    rm -f "$GEN_TMP"
    echo ">> generate_es_systems_variants.sh installed at $GEN_SCRIPT"
else
    echo ">> FAILED TO DOWNLOAD generate_es_systems_variants.sh - ABORTING UPDATE."
    echo ">> (emulationstation was already replaced above - re-run this updater once the download works"
    echo ">>  to finish the rest, or restore $ES_BIN.bak.* by hand.)"
    rm -f "$GEN_TMP"
    exit 1
fi

# ==========================================
# 3. อัปเดตตัวเลขเวอร์ชันในระบบ
# ==========================================
echo ">> [3/3] Finalizing update to v$NEW_VERSION..."
sudo bash -c "cat > \"$INFO_FILE\" <<EOF
VERSION=\"$NEW_VERSION\"
BUILD=\"$NEW_BUILD\"
EOF"

echo ">> ======================================="
echo ">> PLAY OS v$NEW_VERSION UPDATE COMPLETED!"
echo ">> Restarting system to apply changes..."
echo ">> ======================================="
sleep 3
exit 187
