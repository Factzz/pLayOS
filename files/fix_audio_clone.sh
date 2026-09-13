#!/bin/bash
# ==========================================================
# PLAY OS - Hotfix: Restore v2.5 Original Audio (THE FIX)
# ==========================================================

echo ">> Starting Original Audio Recovery (Rollback)..."

# 1. โหลดไฟล์ 'asound.state' v2.5 ตัวดั้งเดิม
wget -q -t 3 -T 30 -O /tmp/asound.state "https://raw.githubusercontent.com/Factzz/pLayOS/main/files/asound.state"

if [ -f "/tmp/asound.state" ]; then
    echo ">> Download successful. Reverting audio settings..."
    
    # 2. ก๊อปปี้ไฟล์ดั้งเดิมไปวางทับ
    sudo cp -f /tmp/asound.state /var/lib/alsa/asound.state
    
    # 3. ลบสคริปต์สลับ Type-C ของ v2.8 ทิ้ง
    sudo rm -f /usr/bin/usb-audio.sh
    sudo sed -i '/usb-audio.sh/d' /etc/udev/rules.d/99-es-icons.rules

    # 4. บังคับให้ระบบเสียงใช้ค่าจากไฟล์ v2.5 ที่เพิ่งวางไปทันที
    sudo alsactl restore 2>/dev/null
    # (ตัดคำสั่ง init ออก เพื่อไม่ให้ระบบเดาค่าเองจนเพี้ยน)

    echo ">> ======================================="
    echo ">> AUDIO RESTORED SUCCESSFULLY!"
    echo ">> ======================================="
else
    echo ">> Error: Failed to download the original audio file."
    echo ">> Please check your internet connection and try again."
fi

echo ">> PLEASE RESTART YOUR DEVICE NOW."
sleep 3
