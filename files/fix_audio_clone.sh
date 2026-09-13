#!/bin/bash
# สคริปต์ล้างค่าเสียงสำหรับเครื่อง R36S Clone
echo ">> Reverting Audio Settings for Clone Devices..."

# ลบไฟล์ตั้งค่าเสียงที่เรายัดไปใน v2.8 ทิ้ง
sudo rm -f /var/lib/alsa/asound.state

# ลบสคริปต์สลับ Type-C (เครื่องโคลนบางตัวไม่รองรับ อาจทำให้รวน)
sudo rm -f /usr/bin/usb-audio.sh
sudo sed -i '/usb-audio.sh/d' /etc/udev/rules.d/99-es-icons.rules

# รีเซ็ตค่าชิปเสียงให้กลับเป็นค่าเริ่มต้นตามฮาร์ดแวร์ (DTB) ของเครื่องนั้นๆ
sudo alsactl init 2>/dev/null

echo ">> DONE! Please Restart your device."
sleep 3
