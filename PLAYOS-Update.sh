#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update Script (v2.0)
# Update Folder: 26908
# ==========================================================

LOG_FILE="/home/ark/playos-update.log"
echo ">> Starting PLAY OS v2.0 OTA Update..." | tee -a "$LOG_FILE"

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
# 2. Setup Gamelist and Images
# ==========================================================
echo ">> [2/5] Downloading Gamelist and Images..." | tee -a "$LOG_FILE"


wget -q -t 3 -T 15 -O /tmp/gamelist.xml "https://raw.githubusercontent.com/Factzz/pLayOS/main/26908/gamelist.xml"
if [ -f "/tmp/gamelist.xml" ]; then sudo cp -f /tmp/gamelist.xml /roms/apps/gamelist.xml; fi

IMAGES=("YouTube-image.png" "YouTube-marquee.png" "YouTube-thumb.png" "Kodi-image.png" "Kodi-marquee.png" "Kodi-thumb.png")
for img in "${IMAGES[@]}"; do
    wget -q -t 3 -T 15 -O "/roms/apps/images/$img" "https://raw.githubusercontent.com/Factzz/pLayOS/main/26908/images/$img"
done

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
wget -q -t 3 -T 15 -O /tmp/PLAYOS-Theme.zip "https://raw.githubusercontent.com/Factzz/pLayOS/main/26908/PLAYOS-Theme.zip"
if [ -f "/tmp/PLAYOS-Theme.zip" ]; then
    sudo unzip -o /tmp/PLAYOS-Theme.zip -d /etc/emulationstation/themes/
fi

# ==========================================================
# 5. Finalize and Restart
# ==========================================================
echo ">> [5/5] Finalizing update..." | tee -a "$LOG_FILE"
echo "PLAY OS 2.0" | sudo tee /etc/playos_version > /dev/null

echo ">> Update finished! Restarting..." | tee -a "$LOG_FILE"


if [ -x "$(command -v msgbox)" ]; then
    sudo msgbox "PLAY OS 2.0 Update Success!\n\nThe system has been updated successfully.\nRestarting UI..."
elif [ -x "$(command -v dialog)" ]; then
    dialog --infobox "PLAY OS 2.0 Update Success!\nRestarting UI..." 10 40 > /dev/tty1
fi


sudo systemctl restart emulationstation

exit 187
