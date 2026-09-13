#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update v2.8.1 (Emergency Edition)
# Build: 261012
# ==========================================================

INFO_FILE="/opt/system/playos_info.cfg"
CURRENT_VERSION=$(grep "VERSION" "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)

# ถ้าหาเวอร์ชันไม่เจอ ให้ตีความว่ามาจาก v2.5 หรือเก่ากว่า
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="2.5"
fi

# URL ดึงไฟล์ฟีเจอร์ใหม่จากอัปเดต 2.8 (Build 261011)
URL_BASE="https://raw.githubusercontent.com/Factzz/pLayOS/main/261011"

echo ">> PLAY OS v2.8.1 (Emergency Edition) Starting..."
echo ">> Your Current Version: $CURRENT_VERSION"

# ==========================================
# 1. อัปเดตแอปและระบบ (GameStore, YTC, ES) 
# ==========================================
echo ">> [1/3] Updating GameStore, YTC, and EmulationStation..."

# อัปเดต GameStore
sudo rm -rf /opt/gamestore
wget -q -t 3 -T 60 -O /tmp/gamestore.zip "$URL_BASE/gamestore.zip"
if [ -f "/tmp/gamestore.zip" ]; then
    sudo unzip -q -o /tmp/gamestore.zip -d /opt/
    sudo chown -R ark:ark /opt/gamestore
    sudo chmod -R 755 /opt/gamestore
fi

# อัปเดต YTC
sudo mkdir -p /roms/ports
sudo rm -rf /roms/ports/ytc
wget -q -t 3 -T 60 -O /tmp/ytc.zip "$URL_BASE/ytc.zip"
if [ -f "/tmp/ytc.zip" ]; then
    sudo unzip -q -o /tmp/ytc.zip -d /roms/ports/
    sudo chown -R ark:ark /roms/ports/ytc
    sudo chmod -R 755 /roms/ports/ytc
fi

# อัปเดต EmulationStation Core
wget -q -t 3 -T 60 -O /tmp/es-update.zip "$URL_BASE/es-update.zip"
if [ -f "/tmp/es-update.zip" ]; then
    sudo rm -f /usr/bin/emulationstation/emulationstation
    sudo rm -f /usr/bin/emulationstation/emulationstation.sh
    sudo unzip -q -o /tmp/es-update.zip -d /usr/bin/emulationstation/
    sudo chown ark:ark /usr/bin/emulationstation/emulationstation*
    sudo chmod 755 /usr/bin/emulationstation/emulationstation*
fi

# ==========================================
# 2. แก้ปัญหาเฉพาะกิจ (Type-C & ลำโพงเครื่องโคลน)
# ==========================================
echo ">> [2/3] Applying emergency fixes..."

# ลบระบบสลับหูฟัง Type-C ทิ้งไปเลย (ทำทุกเครื่อง)
sudo rm -f /usr/bin/usb-audio.sh
sudo sed -i '/usb-audio.sh/d' /etc/udev/rules.d/99-es-icons.rules

# เช็คเวอร์ชันเพื่อจัดการไฟล์เสียง
if [[ "$CURRENT_VERSION" == *"2.8"* ]]; then
    echo ">> Detected v2.8: Reverting Audio Settings for Clone Devices..."
    # ดึงไฟล์เสียงเก่ามาทับแก้บั๊ก
    wget -q -t 3 -T 30 -O /tmp/asound.state "https://raw.githubusercontent.com/Factzz/pLayOS/main/files/asound.state"
    if [ -f "/tmp/asound.state" ]; then
        sudo cp -f /tmp/asound.state /var/lib/alsa/asound.state
        sudo alsactl restore 2>/dev/null
    fi
else
    echo ">> Detected v2.5: Audio is safe. Skipping audio modifications!"
    # ไม่แตะไฟล์ asound.state เลย เสียงเดิมยังอยู่ครบ
fi

# ==========================================
# 3. อัปเดตตัวเลขเวอร์ชันเป็น 2.8.1
# ==========================================
echo ">> [3/3] Finalizing update to v2.8.1..."
sudo bash -c 'cat > /opt/system/playos_info.cfg <<EOF
VERSION="2.8.1"
BUILD="261012"
EOF'

echo ">> ======================================="
echo ">> PLAY OS v2.8.1 UPDATE COMPLETED!"
echo ">> Emergency Bugs Fixed! Restarting..."
echo ">> ======================================="
sleep 3
exit 187
