#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update v2.8.2
# Build: 261013
# ==========================================================

INFO_FILE="/opt/system/playos_info.cfg"
CURRENT_VERSION=$(grep "VERSION" "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)
CURRENT_BUILD=$(grep "BUILD" "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)

NEW_VERSION="2.8.2"
NEW_BUILD=261013
URL_BASE="https://raw.githubusercontent.com/Factzz/pLayOS/main/261013"

# ถ้าหาบิลด์ไม่เจอให้ตีเป็น 0 เพื่อบังคับให้ผ่านเงื่อนไขการอัปเดต
if [ -z "$CURRENT_BUILD" ]; then
    CURRENT_BUILD=0
fi

echo ">> PLAY OS OTA Updater Starting..."
echo ">> Your Current Version: $CURRENT_VERSION (Build $CURRENT_BUILD)"

# ==========================================
# 🛡️ ระบบล็อกเวอร์ชัน: ต่ำกว่าอัปเดตได้ / เท่ากันหรือสูงกว่าเตะออก
# ==========================================
if [ "$CURRENT_BUILD" -ge "$NEW_BUILD" ]; then
    echo ">> SYSTEM IS ALREADY UP TO DATE OR NEWER (Build $CURRENT_BUILD >= $NEW_BUILD)."
    echo ">> UPDATE CANCELED."
    sleep 3
    exit 0
fi

# ==========================================
# 1. อัปเดตแอปพลิเคชัน (GameStore, YTC, Apps)
# ==========================================
echo ">> [1/2] Updating GameStore, YTC, and Apps..."

# 1.1 อัปเดต GameStore
sudo rm -rf /opt/gamestore
wget -q -t 3 -T 60 -O /tmp/gamestore.zip "$URL_BASE/gamestore.zip"
if [ -f "/tmp/gamestore.zip" ]; then
    sudo unzip -q -o /tmp/gamestore.zip -d /opt/
    sudo chown -R ark:ark /opt/gamestore
    sudo chmod -R 755 /opt/gamestore
    rm -f /tmp/gamestore.zip
fi

# 1.2 อัปเดต YTC
sudo mkdir -p /roms/ports
sudo rm -rf /roms/ports/ytc
wget -q -t 3 -T 60 -O /tmp/ytc.zip "$URL_BASE/ytc.zip"
if [ -f "/tmp/ytc.zip" ]; then
    sudo unzip -q -o /tmp/ytc.zip -d /roms/ports/
    sudo chown -R ark:ark /roms/ports/ytc
    sudo chmod -R 755 /roms/ports/ytc
    rm -f /tmp/ytc.zip
fi

# 1.3 อัปเดต Apps
sudo mkdir -p /roms/apps
wget -q -t 3 -T 60 -O /tmp/apps.zip "$URL_BASE/apps.zip"
if [ -f "/tmp/apps.zip" ]; then
    sudo unzip -q -o /tmp/apps.zip -d /roms/apps/
    sudo chown -R ark:ark /roms/apps
    sudo chmod -R 755 /roms/apps
    rm -f /tmp/apps.zip
fi

# ==========================================
# 2. อัปเดตตัวเลขเวอร์ชันในระบบ
# ==========================================
echo ">> [2/2] Finalizing update to v$NEW_VERSION..."
sudo bash -c "cat > /opt/system/playos_info.cfg <<EOF
VERSION=\"$NEW_VERSION\"
BUILD=\"$NEW_BUILD\"
EOF"

echo ">> ======================================="
echo ">> PLAY OS v$NEW_VERSION UPDATE COMPLETED!"
echo ">> Restarting system to apply changes..."
echo ">> ======================================="
sleep 3
exit 187
