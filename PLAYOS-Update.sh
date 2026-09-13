
#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update Script
# Version: 2.8 | Build: 261011
# ==========================================================

BUILD_VER="261011"
INFO_FILE="/opt/system/playos_info.cfg"
LOG_FILE="/home/ark/playos-update.log"
URL_BASE="https://raw.githubusercontent.com/Factzz/pLayOS/main/$BUILD_VER"

# ==========================================================
# 0. Smart Version Check
# ==========================================================
CURRENT_BUILD=$(grep "^BUILD=" "$INFO_FILE" 2>/dev/null | cut -d'"' -f2)

if [ -n "$CURRENT_BUILD" ] && [ "$CURRENT_BUILD" -ge "$BUILD_VER" ]; then
    echo ">> System is on build $CURRENT_BUILD (Up to date). Update skipped." | tee -a "$LOG_FILE"
    echo ">> PRESS (A) OR (B) TO CLOSE."
    exit 187
fi

echo ">> Starting PLAY OS Update (Target Build $BUILD_VER)..." | tee -a "$LOG_FILE"

# ==========================================================
# 1. Update GameStore Market (Clean Install using ZIP)
# ==========================================================
echo ">> [1/5] Updating GameStore Market..." | tee -a "$LOG_FILE"

sudo rm -rf /opt/gamestore
wget -q -t 3 -T 60 -O /tmp/gamestore.zip "$URL_BASE/gamestore.zip"
if [ -f "/tmp/gamestore.zip" ]; then
    sudo unzip -q -o /tmp/gamestore.zip -d /opt/
    
    # ปลดแม่กุญแจให้ Store
    sudo chown -R ark:ark /opt/gamestore
    sudo chmod -R 755 /opt/gamestore
fi

# ==========================================================
# 2. Update YTC (Ports) using ZIP
# ==========================================================
echo ">> [2/5] Installing YTC Ports..." | tee -a "$LOG_FILE"

sudo mkdir -p /roms/ports
sudo rm -rf /roms/ports/ytc
wget -q -t 3 -T 60 -O /tmp/ytc.zip "$URL_BASE/ytc.zip"
if [ -f "/tmp/ytc.zip" ]; then
    sudo unzip -q -o /tmp/ytc.zip -d /roms/ports/
    
    # ปลดแม่กุญแจให้ YTC
    sudo chown -R ark:ark /roms/ports/ytc
    sudo chmod -R 755 /roms/ports/ytc
fi

# ==========================================================
# 3. Update EmulationStation (Clean Install using ZIP)
# ==========================================================
echo ">> [3/5] Updating EmulationStation core..." | tee -a "$LOG_FILE"

wget -q -t 3 -T 60 -O /tmp/es-update.zip "$URL_BASE/es-update.zip"
if [ -f "/tmp/es-update.zip" ]; then
    # ลบไฟล์เก่าทิ้งก่อน ป้องกันไฟล์รันค้าง (Text file busy)
    sudo rm -f /usr/bin/emulationstation/emulationstation
    sudo rm -f /usr/bin/emulationstation/emulationstation.sh
    
    sudo unzip -q -o /tmp/es-update.zip -d /usr/bin/emulationstation/
    
    # ปลดแม่กุญแจ! เปลี่ยนเจ้าของจาก root เป็น ark
    sudo chown ark:ark /usr/bin/emulationstation/emulationstation
    sudo chown ark:ark /usr/bin/emulationstation/emulationstation.sh
    
    # ตั้งค่า 755 ให้รันได้ปกติโดยไม่ต้องใช้สิทธิ์ root
    sudo chmod 755 /usr/bin/emulationstation/emulationstation
    sudo chmod 755 /usr/bin/emulationstation/emulationstation.sh
fi

# ==========================================================
# 4. Apply System Audio Patches (3.5mm & Type-C)
# ==========================================================
echo ">> [4/5] Applying System Audio Patches..." | tee -a "$LOG_FILE"

# --- Fix A: 3.5mm Mono to Stereo ---
sudo mkdir -p /var/lib/alsa/
sudo tee /var/lib/alsa/asound.state > /dev/null << 'EOF'
state.rockchiprk817co {
	control.1 {
		iface MIXER
		name 'Playback Path'
		value SPK_HP
		comment { access 'read write'; type ENUMERATED; count 1; item.0 OFF; item.1 SPK; item.2 HP; item.3 SPK_HP }
	}
	control.2 {
		iface MIXER
		name 'Capture MIC Path'
		value 'MIC OFF'
		comment { access 'read write'; type ENUMERATED; count 1; item.0 'MIC OFF'; item.1 'Main Mic' }
	}
	control.3 {
		iface MIXER
		name 'Playback Volume'
		value.0 142
		value.1 142
		comment { access 'read write'; type INTEGER; count 2; range '0 - 237'; dbmin -9500; dbmax -675; dbvalue.0 -4213; dbvalue.1 -4213 }
	}
	control.4 {
		iface MIXER
		name 'Record Volume'
		value.0 255
		value.1 255
		comment { access 'read write'; type INTEGER; count 2; range '0 - 255' }
	}
	control.5 {
		iface CARD
		name 'Headphone Jack'
		value false
		comment { access read; type BOOLEAN; count 1 }
	}
}
EOF
sudo alsactl restore 2>/dev/null

# --- Fix B: Type-C Audio Auto-Switch ---
sudo tee /usr/bin/usb-audio.sh > /dev/null << 'EOF'
#!/bin/bash
if [ "$1" == "add" ]; then
    echo -e "pcm.!default {\n    type hw\n    card 7\n}\nctl.!default {\n    type hw\n    card 7\n}" > /etc/asound.conf
elif [ "$1" == "remove" ]; then
    rm -f /etc/asound.conf
fi
EOF
sudo chmod +x /usr/bin/usb-audio.sh

sudo sed -i '/usb-audio.sh/d' /etc/udev/rules.d/99-es-icons.rules
echo 'KERNEL=="controlC[0-9]*", DRIVERS=="usb", ACTION=="add", SYMLINK+="snd/controlC7", RUN+="/bin/bash /usr/bin/usb-audio.sh add"' | sudo tee -a /etc/udev/rules.d/99-es-icons.rules > /dev/null
echo 'KERNEL=="controlC[0-9]*", DRIVERS=="usb", ACTION=="remove", RUN+="/bin/bash /usr/bin/usb-audio.sh remove"' | sudo tee -a /etc/udev/rules.d/99-es-icons.rules > /dev/null

# ==========================================================
# 5. Finalize Update
# ==========================================================
echo ">> [5/5] Writing system version info..." | tee -a "$LOG_FILE"

sudo bash -c 'cat > /opt/system/playos_info.cfg <<EOF
VERSION="2.8"
BUILD="261011"
EOF'

echo ">> ======================================="
echo ">> PLAY OS 2.8 (Build $BUILD_VER)"
echo ">> UPDATE COMPLETED SUCCESSFULLY!"
echo ">> PLEASE PRESS (A) OR (B) TO RESTART."
echo ">> ======================================="

sleep 2 

exit 187
