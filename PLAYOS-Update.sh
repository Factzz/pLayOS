#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update Script (v2.0.3)
# Build: 26910
# ==========================================================

LOG_FILE="/home/ark/playos-update.log"
VERSION_FILE="/etc/playos_version"

# ==========================================================
# 0. Check Current Version (เช็กเวอร์ชันกันอัปเดตซ้ำ)
# ==========================================================
if grep -q "26910" "$VERSION_FILE" 2>/dev/null; then
    echo ">> System is already on build 26910. Update skipped." | tee -a "$LOG_FILE"
    
    if [ -x "$(command -v msgbox)" ]; then
        sudo msgbox "Already up to date!\n\nYour PLAY OS is already on the latest version."
    elif [ -x "$(command -v dialog)" ]; then
        dialog --infobox "Already up to date!\nYour PLAY OS is on the latest version." 8 40 > /dev/tty1
    fi
    exit 0
fi

echo ">> Starting PLAY OS v2.0.3 (26910) OTA Update..." | tee -a "$LOG_FILE"

# ==========================================================
# 1. Clean Up Old Apps (ล้าง YouTube ออกจากระบบ)
# ==========================================================
echo ">> [1/6] Cleaning up old apps (Removing YouTube)..." | tee -a "$LOG_FILE"
sudo rm -rf /roms/ports/Tubelite
sudo rm -f /roms/apps/YouTube.sh

# ==========================================================
# 2. Setup APPS (แตกไฟล์ apps.zip รวดเดียวจบ)
# ==========================================================
echo ">> [2/6] Installing APPS..." | tee -a "$LOG_FILE"
sudo mkdir -p /roms/apps/

# โหลด apps.zip ไปแตกไฟล์ที่ /roms/ (ระบบจะนำโฟลเดอร์ apps ไปทับของเดิมให้เอง)
wget -q -t 3 -T 15 -O /tmp/apps.zip "https://raw.githubusercontent.com/Factzz/pLayOS/main/26910/apps.zip"
if [ -f "/tmp/apps.zip" ]; then
    sudo unzip -o /tmp/apps.zip -d /roms/
    sudo chmod +x /roms/apps/*.sh
fi

# ==========================================================
# 3. Setup GameStore (ลงใน /opt/)
# ==========================================================
echo ">> [3/6] Installing GameStore to System..." | tee -a "$LOG_FILE"
sudo mkdir -p /opt/

# โหลด gamestore.zip ไปแตกที่ /opt/ (ระบบจะสร้างโฟลเดอร์ /opt/gamestore/ ให้เอง)
wget -q -t 3 -T 15 -O /tmp/gamestore.zip "https://raw.githubusercontent.com/Factzz/pLayOS/main/26910/gamestore.zip"
if [ -f "/tmp/gamestore.zip" ]; then
    sudo unzip -o /tmp/gamestore.zip -d /opt/
    sudo chmod +x /opt/gamestore/*.sh
fi

# ==========================================================
# 4. Setup RetroArch (โหลด retroarch.zip ลงพาทระบบ)
# ==========================================================
echo ">> [4/6] Installing RetroArch Assets..." | tee -a "$LOG_FILE"
sudo mkdir -p /opt/cmds/

wget -q -t 3 -T 15 -O /tmp/retroarch.zip "https://raw.githubusercontent.com/Factzz/pLayOS/main/26910/retroarch.zip"
if [ -f "/tmp/retroarch.zip" ]; then
    sudo unzip -o /tmp/retroarch.zip -d /opt/cmds/
fi

# ==========================================================
# 5. Update es_systems.cfg & Install Theme
# ==========================================================
echo ">> [5/6] Updating system structures and Theme..." | tee -a "$LOG_FILE"

wget -q -t 3 -T 15 -O /tmp/es_systems.cfg "https://raw.githubusercontent.com/Factzz/pLayOS/main/26910/es_systems.cfg"
if [ -f "/tmp/es_systems.cfg" ]; then
    sudo cp /etc/emulationstation/es_systems.cfg /etc/emulationstation/es_systems.cfg.bak
    sudo cp -f /tmp/es_systems.cfg /etc/emulationstation/es_systems.cfg
fi

wget -q -t 3 -T 15 -O /tmp/PLAYOS-Theme.zip "https://raw.githubusercontent.com/Factzz/pLayOS/main/26910/playos-theme.zip"
if [ -f "/tmp/PLAYOS-Theme.zip" ]; then
    sudo unzip -o /tmp/PLAYOS-Theme.zip -d /etc/emulationstation/themes/
    sudo mkdir -p /roms/themes/
    sudo unzip -o /tmp/PLAYOS-Theme.zip -d /roms/themes/
fi

# ==========================================================
# 6. Finalize and Restart
# ==========================================================
echo ">> [6/6] Finalizing update..." | tee -a "$LOG_FILE"

echo "PLAY OS 2.0.3(26910)" | sudo tee "$VERSION_FILE" > /dev/null

echo ">> Update finished! Restarting..." | tee -a "$LOG_FILE"

if [ -x "$(command -v msgbox)" ]; then
    sudo msgbox "PLAY OS 2.0.3 Update Success!\n\nGameStore has been installed successfully.\nRestarting UI..."
elif [ -x "$(command -v dialog)" ]; then
    dialog --infobox "PLAY OS 2.0.3 Update Success!\nRestarting UI..." 10 40 > /dev/tty1
fi

sudo systemctl restart emulationstation

exit 187
