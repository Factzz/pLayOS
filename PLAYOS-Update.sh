#!/bin/bash
LOG_FILE="/home/ark/playos-update.log"

echo ">> เริ่มกระบวนการอัปเดต PLAY OS ผ่านระบบ OTA..." | tee -a "$LOG_FILE"



if [ -x "$(command -v msgbox)" ]; then
    sudo msgbox "PLAY OS OTA Update\n\nการเชื่อมต่อระบบอัปเดตเสร็จสมบูรณ์แล้ว!"
fi


exit 187
