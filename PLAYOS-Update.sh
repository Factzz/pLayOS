#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update Script (v2.0.2)
# Build: 26909
# ==========================================================

LOG_FILE="/home/ark/playos-update.log"
VERSION_FILE="/etc/playos_version"

# ==========================================================
# 0. Check Current Version (เช็กเวอร์ชันกันอัปเดตซ้ำ)
# ==========================================================
if grep -q "26909" "$VERSION_FILE" 2>/dev/null; then
    echo ">> System is already on build 26909. Update skipped." | tee -a "$LOG_FILE"
    
    if [ -x "$(command -v msgbox)" ]; then
        sudo msgbox "Already up to date!\n\nYour PLAY OS is already on the latest version."
    elif [ -x "$(command -v dialog)" ]; then
        dialog --infobox "Already up to date!\nYour PLAY OS is on the latest version." 8 40 > /dev/tty1
    fi
    exit 0
fi

echo ">> Starting PLAY OS v2.0.2 (26909) OTA Update..." | tee -a "$LOG_FILE"

# ==========================================================
# 1. Clean Up Old Apps (ล้าง YouTube ออกจากระบบ)
# ==========================================================
echo ">> [1/5] Cleaning up old apps (Removing YouTube)..." | tee -a "$LOG_FILE"
sudo rm -rf /roms/ports/Tubelite
sudo rm -f /roms/apps/YouTube.sh

# ==========================================================
# 2. Setup APPS & Kodi (โหลด apps.zip และ kodi.sh)
# ==========================================================
echo ">> [2/5] Installing APPS and Kodi..." | tee -a "$LOG_FILE"
sudo mkdir -p /roms/apps/

wget -q -t 3 -T 15 -O /tmp/kodi.sh "https://raw.githubusercontent.com/Factzz/pLayOS/main/26909/kodi.sh"
if [ -f "/tmp/kodi.sh" ]; then 
    sudo cp -f /tmp/kodi.sh /roms/apps/kodi.sh
    sudo chmod +x /roms/apps/kodi.sh
fi

wget -q -t 3 -T 15 -O /tmp/apps.zip "https://raw.githubusercontent.com/Factzz/pLayOS/main/26909/apps.zip"
if [ -f "/tmp/apps.zip" ]; then
    sudo unzip -o /tmp/apps.zip -d /roms/apps/
fi

# ==========================================================
# 3. Setup RetroArch (โหลด retroarch.zip ลงพาทระบบ)
# ==========================================================
echo ">> [3/5] Installing RetroArch Assets..." | tee -a "$LOG_FILE"
sudo mkdir -p /opt/cmds/

wget -q -t 3 -T 15 -O /tmp/retroarch.zip "https://raw.githubusercontent.com/Factzz/pLayOS/main/26909/retroarch.zip"
if [ -f "/tmp/retroarch.zip" ]; then
    sudo unzip -o /tmp/retroarch.zip -d /opt/cmds/
fi

# ==========================================================
# 4. Update es_systems.cfg & Install Theme
# ==========================================================
echo ">> [4/5] Updating system structures and Theme..." | tee -a "$LOG_FILE"

wget -q -t 3 -T 15 -O /tmp/es_systems.cfg "https://raw.githubusercontent.com/Factzz/pLayOS/main/26909/es_systems.cfg"
if [ -f "/tmp/es_systems.cfg" ]; then
    sudo cp /etc/emulationstation/es_systems.cfg /etc/emulationstation/es_systems.cfg.bak
    sudo cp -f /tmp/es_systems.cfg /etc/emulationstation/es_systems.cfg
fi

wget -q -t 3 -T 15 -O /tmp/PLAYOS-Theme.zip "https://raw.githubusercontent.com/Factzz/pLayOS/main/26909/playos-theme.zip"
if [ -f "/tmp/PLAYOS-Theme.zip" ]; then
    sudo unzip -o /tmp/PLAYOS-Theme.zip -d /etc/emulationstation/themes/
    sudo mkdir -p /roms/themes/
    sudo unzip -o /tmp/PLAYOS-Theme.zip -d /roms/themes/
fi

# ==========================================================
# 5. Finalize and Restart
# ==========================================================
echo ">> [5/5] Finalizing update..." | tee -a "$LOG_FILE"

echo "PLAY OS 2.0.2(26909)" | sudo tee "$VERSION_FILE" > /dev/null

echo ">> Update finished! Restarting..." | tee -a "$LOG_FILE"

if [ -x "$(command -v msgbox)" ]; then
    sudo msgbox "PLAY OS 2.0.2 Update Success!\n\nThe system has been updated successfully.\nRestarting UI..."
elif [ -x "$(command -v dialog)" ]; then
    dialog --infobox "PLAY OS 2.0.2 Update Success!\nRestarting UI..." 10 40 > /dev/tty1
fi

sudo systemctl restart emulationstation

exit 187