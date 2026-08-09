#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update Script (v2.0.1)
# Build: 26908
# ==========================================================

LOG_FILE="/home/ark/playos-update.log"
VERSION_FILE="/etc/playos_version"

# ==========================================================
# 0. Check Current Version (เช็กเวอร์ชันกันอัปเดตซ้ำ)
# ==========================================================
if grep -q "26908" "$VERSION_FILE" 2>/dev/null; then
    echo ">> System is already on build 26908. Update skipped." | tee -a "$LOG_FILE"
    
    # แจ้งเตือนผู้ใช้ว่าอัปเดตล่าสุดแล้ว
    if [ -x "$(command -v msgbox)" ]; then
        sudo msgbox "Already up to date!\n\nYour PLAY OS is already on the latest version."
    elif [ -x "$(command -v dialog)" ]; then
        dialog --infobox "Already up to date!\nYour PLAY OS is on the latest version." 8 40 > /dev/tty1
    fi
    
    exit 0
fi

echo ">> Starting PLAY OS v2.0.1 (26908) OTA Update..." | tee -a "$LOG_FILE"

# ==========================================================
# 1. Setup APPS Directory, Scripts & Core Apps (YouTube)
# ==========================================================
echo ">> [1/5] Installing APPS (YouTube Core & Kodi)..." | tee -a "$LOG_FILE"
sudo mkdir -p /roms/apps/images
sudo mkdir -p /roms/ports/Tubelite


wget -q -t 3 -T 15 -O /tmp/TubeLite.zip "https://github.com/Factzz/pLayOS/releases/download/v.2.0/TubeLite.zip"
if [ -f "/tmp/TubeLite.zip" ]; then
 
    sudo unzip -o /tmp/TubeLite.zip -d /roms/ports/Tubelite/
    sudo chmod -R +x /roms/ports/Tubelite/
fi

wget -q -t 3 -T 15 -O /tmp/YouTube.sh "https://raw.githubusercontent.com/Factzz/pLayOS/main/26908/YouTube.sh"
wget -q -t 3 -T 15 -O /tmp/kodi.sh "https://raw.githubusercontent.com/Factzz/pLayOS/main/26908/kodi.sh"
if [ -f "/tmp/YouTube.sh" ]; then sudo cp -f /tmp/YouTube.sh /roms/apps/YouTube.sh; fi
if [ -f "/tmp/kodi.sh" ]; then sudo cp -f /tmp/kodi.sh /roms/apps/kodi.sh; fi
sudo chmod +x /roms/apps/*.sh

# ==========================================================
# 2. Setup Gamelist and Images (แบบ Zip)
# ==========================================================
echo ">> [2/5] Downloading Gamelist and Images..." | tee -a "$LOG_FILE"

# โหลด Gamelist
wget -q -t 3 -T 15 -O /tmp/gamelist.xml "https://raw.githubusercontent.com/Factzz/pLayOS/main/26908/gamelist.xml"
if [ -f "/tmp/gamelist.xml" ]; then sudo cp -f /tmp/gamelist.xml /roms/apps/gamelist.xml; fi

# โหลดไฟล์ Zip รูปภาพปกทั้งหมดในครั้งเดียว
wget -q -t 3 -T 15 -O /tmp/apps-images.zip "https://raw.githubusercontent.com/Factzz/pLayOS/main/26908/apps-images.zip"
if [ -f "/tmp/apps-images.zip" ]; then
    # แตกไฟล์ zip ลงไปที่ /roms/apps/ (มันจะสร้างโฟลเดอร์ images ให้เองอัตโนมัติ)
    sudo unzip -o /tmp/apps-images.zip -d /roms/apps/
fi

# ==========================================================
# 3. Update es_systems.cfg (เพิ่มหมวด APPS)
# ==========================================================
echo ">> [3/5] Updating system structures (es_systems.cfg)..." | tee -a "$LOG_FILE"
wget -q -t 3 -T 15 -O /tmp/es_systems.cfg "https://raw.githubusercontent.com/Factzz/pLayOS/main/26908/es_systems.cfg"
if [ -f "/tmp/es_systems.cfg" ]; then
    sudo cp /etc/emulationstation/es_systems.cfg /etc/emulationstation/es_systems.cfg.bak
    sudo cp -f /tmp/es_systems.cfg /etc/emulationstation/es_systems.cfg
fi

# ==========================================================
# 4. Install New Theme (ครอบคลุม 1:1 Ratio และโลโก้ APPS)
# ==========================================================
echo ">> [4/5] Installing new PLAYOS-Theme (1:1 Ratio + APPS)..." | tee -a "$LOG_FILE"
wget -q -t 3 -T 15 -O /tmp/PLAYOS-Theme.zip "https://raw.githubusercontent.com/Factzz/pLayOS/main/26908/playos-theme.zip"

if [ -f "/tmp/PLAYOS-Theme.zip" ]; then
    # 1. แตกไฟล์ Zip ทับลงในโฟลเดอร์รากของระบบ
    sudo unzip -o /tmp/PLAYOS-Theme.zip -d /etc/emulationstation/themes/
    sudo mkdir -p /roms/themes/
    sudo unzip -o /tmp/PLAYOS-Theme.zip -d /roms/themes/
fi

# ==========================================================
# 5. Finalize and Restart
# ==========================================================
echo ">> [5/5] Finalizing update..." | tee -a "$LOG_FILE"

# บันทึกชื่อเวอร์ชันใหม่ลงในระบบ
echo "PLAY OS 2.0.1(26908)" | sudo tee "$VERSION_FILE" > /dev/null

echo ">> Update finished! Restarting..." | tee -a "$LOG_FILE"

# แจ้งเตือนหน้าจอผู้ใช้เมื่อทำเสร็จ
if [ -x "$(command -v msgbox)" ]; then
    sudo msgbox "PLAY OS 2.0.1 Update Success!\n\nThe system has been updated successfully.\nRestarting UI..."
elif [ -x "$(command -v dialog)" ]; then
    dialog --infobox "PLAY OS 2.0.1 Update Success!\nRestarting UI..." 10 40 > /dev/tty1
fi

# สั่งเริ่มระบบ EmulationStation ใหม่ให้โชว์ทุกอย่าง
sudo systemctl restart emulationstation

# ส่งรหัส 187 คืนสคริปต์แม่เพื่อยืนยันการติดตั้งสมบูรณ์
exit 187
