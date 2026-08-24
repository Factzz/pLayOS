#!/bin/bash
# ==========================================================
# PLAY OS - OTA Update Script
# Build: 26916
# ==========================================================

INFO_FILE="/opt/system/playos_info.cfg"
LOG_FILE="/home/ark/playos-update.log"
URL_BASE="https://raw.githubusercontent.com/Factzz/pLayOS/main/26916"

# ==========================================================
# 0. Check Current Version (เช็กจาก playos_info.cfg เป็นหลัก)
# ==========================================================
# ถ้ามีไฟล์นี้อยู่ และข้างในมีคำว่า 26916 ให้ข้ามการอัปเดต
if grep -q "26916" "$INFO_FILE" 2>/dev/null; then
    echo ">> System is already on build 26916. Update skipped." | tee -a "$LOG_FILE"
    echo ">> PRESS (A) OR (B) TO CLOSE."
    exit 187
fi

echo ">> Starting PLAY OS Update (Build 26916)..." | tee -a "$LOG_FILE"

# ==========================================================
# 1. Clean Up Old Scripts (ลบสคริปต์ Wi-Fi / BT / Auto 2Card)
# ==========================================================
echo ">> [1/5] Removing old system tools..." | tee -a "$LOG_FILE"
# ดักลบทั้งโฟลเดอร์หลักและ Advanced เผื่อไฟล์อยู่ผิดที่
sudo rm -f "/opt/system/Wi-Fi Manager 4.3.6.sh"
sudo rm -f "/opt/system/BT Manager 4.3.2.sh"
sudo rm -f "/opt/system/Advanced/Wi-Fi Manager 4.3.6.sh"
sudo rm -f "/opt/system/Advanced/BT Manager 4.3.2.sh"
sudo rm -f "/usr/local/bin/auto_2card.sh"

# ==========================================================
# 2. Update RetroArch Configs
# ==========================================================
echo ">> [2/5] Updating RetroArch configurations..." | tee -a "$LOG_FILE"

wget -q -t 3 -T 15 -O /tmp/retroarch.cfg "$URL_BASE/retroarch.cfg"
if [ -f "/tmp/retroarch.cfg" ]; then
    sudo cp -f /tmp/retroarch.cfg /home/ark/.config/retroarch/retroarch.cfg
    sudo cp -f /tmp/retroarch.cfg /home/ark/.config/retroarch32/retroarch.cfg
fi

wget -q -t 3 -T 15 -O /tmp/retroarch-core-options.cfg "$URL_BASE/retroarch-core-options.cfg"
if [ -f "/tmp/retroarch-core-options.cfg" ]; then
    sudo cp -f /tmp/retroarch-core-options.cfg /home/ark/.config/retroarch/retroarch-core-options.cfg
fi

# ==========================================================
# 3. Update System Files
# ==========================================================
echo ">> [3/5] Updating PLAY OS system files..." | tee -a "$LOG_FILE"

wget -q -t 3 -T 15 -O /tmp/LICENSE.txt "$URL_BASE/LICENSE.txt"
[ -f "/tmp/LICENSE.txt" ] && sudo cp -f /tmp/LICENSE.txt /opt/system/LICENSE.txt

wget -q -t 3 -T 15 -O /tmp/playos_logo.svg "$URL_BASE/playos_logo.svg"
[ -f "/tmp/playos_logo.svg" ] && sudo cp -f /tmp/playos_logo.svg /opt/system/playos_logo.svg

# โหลด Info ทับเป็นอันดับสุดท้าย เพื่อยืนยันว่าการตั้งค่าทุกอย่างผ่านหมด
wget -q -t 3 -T 15 -O /tmp/playos_info.cfg "$URL_BASE/playos_info.cfg"
[ -f "/tmp/playos_info.cfg" ] && sudo cp -f /tmp/playos_info.cfg /opt/system/playos_info.cfg

# ==========================================================
# 4. Update EmulationStation
# ==========================================================
echo ">> [4/5] Updating EmulationStation & Translations..." | tee -a "$LOG_FILE"

wget -q -t 3 -T 60 -O /tmp/emulationstation "$URL_BASE/emulationstation"
if [ -f "/tmp/emulationstation" ]; then
    sudo cp -f /tmp/emulationstation /usr/bin/emulationstation/emulationstation
    sudo chmod +x /usr/bin/emulationstation/emulationstation
fi

sudo mkdir -p /usr/bin/emulationstation/resources/locale/th/
wget -q -t 3 -T 15 -O /tmp/emulationstation2.po "$URL_BASE/emulationstation2.po"
if [ -f "/tmp/emulationstation2.po" ]; then
    sudo cp -f /tmp/emulationstation2.po /usr/bin/emulationstation/resources/locale/th/emulationstation2.po
fi

# ==========================================================
# 5. Finalize & Guide User
# ==========================================================
echo ">> [5/5] Finalizing update..." | tee -a "$LOG_FILE"

# ส่งข้อความพาดหัวตัวโตๆ วิ่งไปที่หน้าจอก่อนจบสคริปต์
echo ">> ======================================="
echo ">> UPDATE COMPLETED SUCCESSFULLY!"
echo ">> PLEASE PRESS (A) OR (B) TO RESTART."
echo ">> ======================================="

# หน่วงเวลา 2 วินาทีให้ผู้ใช้ทันอ่านข้อความ ก่อนที่หน้าต่าง C++ จะเด้งขึ้นมา
sleep 2 

exit 187
