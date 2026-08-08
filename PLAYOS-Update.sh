#!/bin/bash
LOG_FILE="/home/ark/playos-update.log"

echo ">> เริ่มกระบวนการอัปเดต PLAY OS ผ่านระบบ OTA..." | tee -a "$LOG_FILE"
# (เดี๋ยวเราค่อยมาเขียนคำสั่งอัปเดตอะไรเพิ่มทีหลังได้ครับ)

# แจ้งเตือนผู้ใช้เมื่อเสร็จสิ้น
if [ -x "$(command -v msgbox)" ]; then
    sudo msgbox "PLAY OS OTA Update\n\nการเชื่อมต่อระบบอัปเดตเสร็จสมบูรณ์แล้ว!"
fi

# กฎเหล็ก: ต้องส่งรหัส 187 เพื่อบอกตัวแม่ว่าไม่มี Error
exit 187