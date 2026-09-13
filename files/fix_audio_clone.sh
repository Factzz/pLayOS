#!/bin/bash
# ==========================================================
# PLAY OS - Hotfix: Restore v2.5 Original Audio (THE FIX)
# ==========================================================
# สคริปต์นี้จะดึงไฟล์ตั้งค่าเสียงเดิม (v2.5) มาทับเพื่อแก้เสียงบอดในเครื่องโคลน

echo ">> Starting Original Audio Recovery (Rollback)..."


wget -q -t 3 -T 30 -O /tmp/asound.state "https://raw.githubusercontent.com/Factzz/pLayOS/main/files/asound.state"

if [ -f "/tmp/asound.state" ]; then
    echo ">> Download successful. Reverting audio settings..."
    

    sudo cp -f /tmp/asound.state /var/lib/alsa/asound.state
 
    sudo rm -f /usr/bin/usb-audio.sh
    sudo sed -i '/usb-audio.sh/d' /etc/udev/rules.d/99-es-icons.rules


    sudo alsactl restore 2>/dev/null
    

    sudo alsactl init 2>/dev/null

    echo ">> ======================================="
    echo ">> AUDIO RESTORED SUCCESSFULLY!"
    echo ">> ======================================="
else
    echo ">> Error: Failed to download the original audio file."
    echo ">> Please check your internet connection and try again."
fi

echo ">> PLEASE RESTART YOUR DEVICE NOW."
sleep 3
