#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update Script
# Version: 2.5 | Build: 26930
# ==========================================================

BUILD_VER="26930"
INFO_FILE="/opt/system/playos_info.cfg"
LOG_FILE="/home/ark/playos-update.log"
URL_BASE="https://raw.githubusercontent.com/Factzz/pLayOS/main/$BUILD_VER"

# ==========================================================
# 0. Smart Version Check (เช็คว่าสูงกว่า หรือ เท่ากับ จริงๆ)
# ==========================================================
# ดึงเฉพาะตัวเลขจากบรรทัด BUILD="XXXXX" ออกมา
CURRENT_BUILD=$(grep "^BUILD=" "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)

# ถ้าดึงเลขมาได้ และ เลขปัจจุบัน มากกว่าหรือเท่ากับ (-ge) เลขในสคริปต์ ให้ข้าม!
if [ -n "$CURRENT_BUILD" ] && [ "$CURRENT_BUILD" -ge "$BUILD_VER" ]; then
    echo ">> System is on build $CURRENT_BUILD (Up to date). Update skipped." | tee -a "$LOG_FILE"
    echo ">> PRESS (A) OR (B) TO CLOSE."
    exit 187
fi

echo ">> Starting PLAY OS Update (Target Build $BUILD_VER)..." | tee -a "$LOG_FILE"

# ==========================================================
# 1. Update Core System Framework
# ==========================================================
echo ">> [1/5] Updating core framework..." | tee -a "$LOG_FILE"

sudo mkdir -p /opt/system
wget -q -t 3 -T 15 -O /tmp/framework.fim "$URL_BASE/framework.fim"
[ -f "/tmp/framework.fim" ] && sudo cp -f /tmp/framework.fim /opt/system/framework.fim

# ==========================================================
# 2. Setup PLAY OS Game Manager & Engine
# ==========================================================
echo ">> [2/5] Installing playOS engine & manager..." | tee -a "$LOG_FILE"

sudo mkdir -p /opt/playos

wget -q -t 3 -T 15 -O /tmp/game_manager.sh "$URL_BASE/game_manager.sh"
if [ -f "/tmp/game_manager.sh" ]; then
    sudo cp -f /tmp/game_manager.sh /opt/playos/game_manager.sh
    sudo chmod +x /opt/playos/game_manager.sh
fi

wget -q -t 3 -T 15 -O /tmp/playos-engine "$URL_BASE/playos-engine"
if [ -f "/tmp/playos-engine" ]; then
    sudo cp -f /tmp/playos-engine /opt/playos/playos-engine
    sudo chmod +x /opt/playos/playos-engine
fi

# ==========================================================
# 3. Update GameStore Market (Clean Install using ZIP)
# ==========================================================
echo ">> [3/5] Updating GameStore Market..." | tee -a "$LOG_FILE"

# ลบโฟลเดอร์เดิมทิ้งให้เกลี้ยง
sudo rm -rf /opt/gamestore

wget -q -t 3 -T 60 -O /tmp/gamestore.zip "$URL_BASE/gamestore.zip"
if [ -f "/tmp/gamestore.zip" ]; then
    # แตกไฟล์ zip ไปไว้ใน /opt/
    sudo unzip -q -o /tmp/gamestore.zip -d /opt/
fi

# ==========================================================
# 4. Update EmulationStation
# ==========================================================
echo ">> [4/5] Updating EmulationStation core..." | tee -a "$LOG_FILE"

wget -q -t 3 -T 60 -O /tmp/emulationstation "$URL_BASE/emulationstation"
if [ -f "/tmp/emulationstation" ]; then
    sudo cp -f /tmp/emulationstation /usr/bin/emulationstation/emulationstation
    sudo chmod +x /usr/bin/emulationstation/emulationstation
fi

# ==========================================================
# 5. Update Apps & YTC (Ports) using ZIP
# ==========================================================
echo ">> [5/5] Installing Apps and YTC..." | tee -a "$LOG_FILE"

sudo mkdir -p /roms
wget -q -t 3 -T 60 -O /tmp/apps.zip "$URL_BASE/apps.zip"
if [ -f "/tmp/apps.zip" ]; then
    sudo unzip -q -o /tmp/apps.zip -d /roms/
fi

sudo mkdir -p /roms/ports
wget -q -t 3 -T 60 -O /tmp/ytc.zip "$URL_BASE/ytc.zip"
if [ -f "/tmp/ytc.zip" ]; then
    sudo unzip -q -o /tmp/ytc.zip -d /roms/ports/
fi

# ==========================================================
# 6. Finalize Update (เขียนไฟล์ info สดๆ ลงเครื่อง)
# ==========================================================
echo ">> Writing system version info..." | tee -a "$LOG_FILE"

sudo bash -c 'cat > /opt/system/playos_info.cfg <<EOF
VERSION="2.5"
BUILD="26930"
EOF'

echo ">> ======================================="
echo ">> PLAY OS 2.5 (Build $BUILD_VER)"
echo ">> UPDATE COMPLETED SUCCESSFULLY!"
echo ">> PLEASE PRESS (A) OR (B) TO RESTART."
echo ">> ======================================="

sleep 2 

exit 187
